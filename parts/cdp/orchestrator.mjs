import * as std from 'qjs:std';
import * as os from 'qjs:os';

export const DEFAULT_DB_PATH = 'orchestrator_meta.sqlite';

const SCHEMA_BODY_SQL = String.raw`CREATE TABLE IF NOT EXISTS orchestrator_sessions (
  orchestrator_session_id TEXT PRIMARY KEY,
  canonical_store TEXT NOT NULL
    CHECK (canonical_store IN ('local_agent_session_sqlite', 'cdp_agent_session_sqlite')),
  status TEXT NOT NULL
    CHECK (status IN ('open', 'closed', 'conflict', 'orphaned')),
  reconcile_state TEXT NOT NULL DEFAULT 'clean'
    CHECK (reconcile_state IN ('clean', 'dirty', 'reconciling', 'error')),
  canonical_checkpoint_seq INTEGER NOT NULL DEFAULT 0,
  latest_checkpoint_hash TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  closed_at_ms INTEGER
);

CREATE TABLE IF NOT EXISTS session_correlations (
  store_name TEXT NOT NULL
    CHECK (store_name IN ('local_agent_session_sqlite', 'cdp_agent_session_sqlite')),
  store_session_id TEXT NOT NULL,
  orchestrator_session_id TEXT NOT NULL
    REFERENCES orchestrator_sessions(orchestrator_session_id) ON DELETE CASCADE,
  relation_kind TEXT NOT NULL DEFAULT 'primary'
    CHECK (relation_kind IN ('primary', 'mirror', 'derived')),
  observed_rev TEXT,
  observed_at_ms INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY (store_name, store_session_id),
  UNIQUE (orchestrator_session_id, store_name)
);

CREATE TABLE IF NOT EXISTS session_checkpoints (
  orchestrator_session_id TEXT NOT NULL
    REFERENCES orchestrator_sessions(orchestrator_session_id) ON DELETE CASCADE,
  checkpoint_seq INTEGER NOT NULL,
  checkpoint_kind TEXT NOT NULL
    CHECK (checkpoint_kind IN ('bootstrap', 'write_through', 'reconcile', 'manual')),
  local_observed_rev TEXT,
  cdp_observed_rev TEXT,
  state_json TEXT NOT NULL,
  state_hash TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY (orchestrator_session_id, checkpoint_seq)
);

CREATE TABLE IF NOT EXISTS reconcile_runs (
  reconcile_run_id TEXT PRIMARY KEY,
  orchestrator_session_id TEXT NOT NULL
    REFERENCES orchestrator_sessions(orchestrator_session_id) ON DELETE CASCADE,
  trigger_kind TEXT NOT NULL
    CHECK (trigger_kind IN ('startup', 'periodic', 'manual', 'write_through')),
  status TEXT NOT NULL
    CHECK (status IN ('running', 'ok', 'conflict', 'failed')),
  base_checkpoint_seq INTEGER NOT NULL,
  observed_local_rev TEXT,
  observed_cdp_rev TEXT,
  diff_json TEXT,
  resolution_json TEXT,
  error_message TEXT,
  started_at_ms INTEGER NOT NULL,
  finished_at_ms INTEGER
);

CREATE INDEX IF NOT EXISTS idx_orchestrator_sessions_dirty
ON orchestrator_sessions(updated_at_ms DESC)
WHERE reconcile_state <> 'clean';

CREATE INDEX IF NOT EXISTS idx_session_checkpoints_latest
ON session_checkpoints(orchestrator_session_id, checkpoint_seq DESC);

CREATE INDEX IF NOT EXISTS idx_reconcile_runs_open
ON reconcile_runs(started_at_ms DESC)
WHERE status IN ('running', 'conflict');
`;

export const SCHEMA_SQL = 'PRAGMA foreign_keys = ON;\n\n' + SCHEMA_BODY_SQL;

function fail(message) {
  throw new Error(message);
}

function sqlQuote(value) {
  if (value === null || value === undefined) return 'NULL';
  return `'${String(value).replace(/'/g, "''")}'`;
}

function sqlIntegerOrNull(value) {
  if (value === null || value === undefined) return 'NULL';
  if (!Number.isFinite(value)) fail(`invalid integer value: ${value}`);
  return String(Math.trunc(value));
}

function uniqueTempSqlPath(prefix = '.orchestrator_sql') {
  const [cwd] = os.getcwd();
  const base = cwd || '.';
  const rand = Math.random().toString(16).slice(2);
  return `${base}/${prefix}_${Date.now()}_${rand}.sql`;
}

function readAllFromFd(fd) {
  const file = std.fdopen(fd, 'r');
  if (file === null) {
    os.close(fd);
    fail('std.fdopen() failed');
  }
  const text = file.readAsString();
  file.close();
  return text;
}

export function execSql(dbPath, sql, extraArgs = []) {
  const sqlPath = uniqueTempSqlPath();
  std.writeFile(sqlPath, sql);

  const inFd = os.open(sqlPath, os.O_RDONLY, 0);
  if (inFd < 0) {
    try { os.remove(sqlPath); } catch (_) {}
    fail(`failed to open temp sql file: ${sqlPath}`);
  }

  const stdoutPipe = os.pipe();
  const stderrPipe = os.pipe();
  if (stdoutPipe === null || stderrPipe === null) {
    os.close(inFd);
    try { os.remove(sqlPath); } catch (_) {}
    fail('os.pipe() failed');
  }

  const [stdoutReadFd, stdoutWriteFd] = stdoutPipe;
  const [stderrReadFd, stderrWriteFd] = stderrPipe;

  try {
    const rc = os.exec(['sqlite3', ...extraArgs, dbPath], {
      block: true,
      usePath: true,
      stdin: inFd,
      stdout: stdoutWriteFd,
      stderr: stderrWriteFd,
    });

    os.close(inFd);
    os.close(stdoutWriteFd);
    os.close(stderrWriteFd);

    const stdoutText = readAllFromFd(stdoutReadFd);
    const stderrText = readAllFromFd(stderrReadFd);

    if (rc !== 0) {
      const detail = (stderrText || stdoutText || `sqlite3 exit=${rc}`).trim();
      fail(detail);
    }
    return { stdoutText, stderrText };
  } finally {
    try { os.remove(sqlPath); } catch (_) {}
  }
}

export function queryJson(dbPath, sql) {
  const { stdoutText } = execSql(dbPath, sql, ['-json']);
  try {
    return JSON.parse(stdoutText || '[]');
  } catch (err) {
    fail(`invalid JSON from sqlite3: ${stdoutText}`);
  }
}

function stableStringify(value) {
  if (value === null) return 'null';
  if (typeof value === 'number' || typeof value === 'boolean') return JSON.stringify(value);
  if (typeof value === 'string') return JSON.stringify(value);
  if (Array.isArray(value)) return '[' + value.map(stableStringify).join(',') + ']';
  if (typeof value === 'object') {
    const keys = Object.keys(value).sort();
    return '{' + keys.map((k) => JSON.stringify(k) + ':' + stableStringify(value[k])).join(',') + '}';
  }
  return JSON.stringify(String(value));
}

function fnv1a64(text) {
  let hash = 0xcbf29ce484222325n;
  const prime = 0x100000001b3n;
  for (let i = 0; i < text.length; i++) {
    hash ^= BigInt(text.charCodeAt(i));
    hash = (hash * prime) & 0xffffffffffffffffn;
  }
  return hash.toString(16).padStart(16, '0');
}

export function computeStateHash(value) {
  const text = stableStringify(value);
  return [
    fnv1a64('a|' + text),
    fnv1a64('b|' + text),
    fnv1a64('c|' + text),
    fnv1a64('d|' + text),
  ].join('');
}

function uniqueId(prefix) {
  return `${prefix}_${Date.now()}_${Math.random().toString(16).slice(2)}`;
}

function nowMs() {
  return Date.now();
}

export function initDb(dbPath = DEFAULT_DB_PATH) {
  execSql(dbPath, SCHEMA_SQL + '\n');
  return { ok: true, dbPath };
}

export function initSession(dbPath, input) {
  const ts = Math.trunc(input.createdAtMs ?? nowMs());
  const updatedAt = Math.trunc(input.updatedAtMs ?? ts);
  const sql = `
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
${SCHEMA_BODY_SQL}
INSERT INTO orchestrator_sessions (
  orchestrator_session_id,
  canonical_store,
  status,
  reconcile_state,
  canonical_checkpoint_seq,
  latest_checkpoint_hash,
  created_at_ms,
  updated_at_ms,
  closed_at_ms
) VALUES (
  ${sqlQuote(input.orchestratorSessionId)},
  ${sqlQuote(input.canonicalStore ?? 'cdp_agent_session_sqlite')},
  ${sqlQuote(input.status ?? 'open')},
  ${sqlQuote(input.reconcileState ?? 'clean')},
  ${sqlIntegerOrNull(input.canonicalCheckpointSeq ?? 0)},
  ${sqlQuote(input.latestCheckpointHash ?? null)},
  ${sqlIntegerOrNull(ts)},
  ${sqlIntegerOrNull(updatedAt)},
  ${sqlIntegerOrNull(input.closedAtMs ?? null)}
)
ON CONFLICT(orchestrator_session_id) DO UPDATE SET
  canonical_store = excluded.canonical_store,
  status = excluded.status,
  reconcile_state = excluded.reconcile_state,
  updated_at_ms = excluded.updated_at_ms,
  closed_at_ms = excluded.closed_at_ms;
COMMIT;
`;
  execSql(dbPath, sql);
  return { ok: true, orchestratorSessionId: input.orchestratorSessionId };
}

export function createCorrelation(dbPath, input) {
  const observedAt = Math.trunc(input.observedAtMs ?? nowMs());
  const createdAt = Math.trunc(input.createdAtMs ?? observedAt);
  const sql = `
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
INSERT INTO session_correlations (
  store_name,
  store_session_id,
  orchestrator_session_id,
  relation_kind,
  observed_rev,
  observed_at_ms,
  created_at_ms
) VALUES (
  ${sqlQuote(input.storeName)},
  ${sqlQuote(input.storeSessionId)},
  ${sqlQuote(input.orchestratorSessionId)},
  ${sqlQuote(input.relationKind ?? 'primary')},
  ${sqlQuote(input.observedRev ?? null)},
  ${sqlIntegerOrNull(observedAt)},
  ${sqlIntegerOrNull(createdAt)}
)
ON CONFLICT(store_name, store_session_id) DO UPDATE SET
  orchestrator_session_id = excluded.orchestrator_session_id,
  relation_kind = excluded.relation_kind,
  observed_rev = excluded.observed_rev,
  observed_at_ms = excluded.observed_at_ms;
UPDATE orchestrator_sessions
SET reconcile_state = 'dirty',
    updated_at_ms = ${sqlIntegerOrNull(observedAt)}
WHERE orchestrator_session_id = ${sqlQuote(input.orchestratorSessionId)};
COMMIT;
`;
  execSql(dbPath, sql);
  return { ok: true, storeName: input.storeName, storeSessionId: input.storeSessionId };
}

export function saveCheckpoint(dbPath, input) {
  const stateJson = typeof input.state === 'string' ? input.state : stableStringify(input.state);
  const stateHash = input.stateHash ?? computeStateHash(typeof input.state === 'string' ? JSON.parse(input.state) : input.state);
  const createdAt = Math.trunc(input.createdAtMs ?? nowMs());
  const rows = queryJson(dbPath, `
SELECT COALESCE(MAX(checkpoint_seq), 0) + 1 AS next_seq
FROM session_checkpoints
WHERE orchestrator_session_id = ${sqlQuote(input.orchestratorSessionId)};
`);
  const nextSeq = Number((rows[0] && rows[0].next_seq) || 1);

  const sql = `
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
INSERT INTO session_checkpoints (
  orchestrator_session_id,
  checkpoint_seq,
  checkpoint_kind,
  local_observed_rev,
  cdp_observed_rev,
  state_json,
  state_hash,
  created_at_ms
) VALUES (
  ${sqlQuote(input.orchestratorSessionId)},
  ${sqlIntegerOrNull(nextSeq)},
  ${sqlQuote(input.checkpointKind ?? 'manual')},
  ${sqlQuote(input.localObservedRev ?? null)},
  ${sqlQuote(input.cdpObservedRev ?? null)},
  ${sqlQuote(stateJson)},
  ${sqlQuote(stateHash)},
  ${sqlIntegerOrNull(createdAt)}
);
UPDATE orchestrator_sessions
SET canonical_checkpoint_seq = ${sqlIntegerOrNull(nextSeq)},
    latest_checkpoint_hash = ${sqlQuote(stateHash)},
    reconcile_state = ${sqlQuote(input.reconcileState ?? 'clean')},
    updated_at_ms = ${sqlIntegerOrNull(createdAt)}
WHERE orchestrator_session_id = ${sqlQuote(input.orchestratorSessionId)};
COMMIT;
`;
  execSql(dbPath, sql);
  return { ok: true, orchestratorSessionId: input.orchestratorSessionId, checkpointSeq: nextSeq, stateHash };
}

function fetchLocalSession(localDbPath, sessionId) {
  const rows = queryJson(localDbPath, `
SELECT id, url, title, observed_rev, message_count, updated_at_ms
FROM local_agent_sessions
WHERE id = ${sqlQuote(sessionId)};
`);
  return rows[0] ?? null;
}

function fetchCdpSession(cdpDbPath, sessionId) {
  const rows = queryJson(cdpDbPath, `
SELECT id, url, title, last_seen_ws_url, msg_count, updated_at_ms
FROM cdp_sessions
WHERE id = ${sqlQuote(sessionId)};
`);
  const session = rows[0] ?? null;
  if (!session) return null;
  const messages = queryJson(cdpDbPath, `
SELECT ordinal, role, content, created_at_ms
FROM cdp_messages
WHERE session_id = ${sqlQuote(sessionId)}
ORDER BY ordinal;
`);
  return { ...session, messages };
}

function currentObservedRevFromCdp(session) {
  if (!session) return null;
  return `${session.updated_at_ms}:${session.msg_count}`;
}

export function reconcile(dbPath, input) {
  const sessionId = input.orchestratorSessionId;
  const startedAt = Math.trunc(input.startedAtMs ?? nowMs());
  const runId = input.reconcileRunId ?? uniqueId('reconcile');

  const sessionRows = queryJson(dbPath, `
SELECT orchestrator_session_id, canonical_checkpoint_seq
FROM orchestrator_sessions
WHERE orchestrator_session_id = ${sqlQuote(sessionId)};
`);
  if (sessionRows.length === 0) fail(`unknown orchestrator_session_id: ${sessionId}`);

  const checkpointRows = queryJson(dbPath, `
SELECT checkpoint_seq, local_observed_rev, cdp_observed_rev, state_json, state_hash
FROM session_checkpoints
WHERE orchestrator_session_id = ${sqlQuote(sessionId)}
ORDER BY checkpoint_seq DESC
LIMIT 1;
`);
  const latestCheckpoint = checkpointRows[0] ?? null;

  const correlationRows = queryJson(dbPath, `
SELECT store_name, store_session_id, observed_rev
FROM session_correlations
WHERE orchestrator_session_id = ${sqlQuote(sessionId)};
`);

  let localStoreSessionId = null;
  let cdpStoreSessionId = null;
  for (const row of correlationRows) {
    if (row.store_name === 'local_agent_session_sqlite') localStoreSessionId = row.store_session_id;
    if (row.store_name === 'cdp_agent_session_sqlite') cdpStoreSessionId = row.store_session_id;
  }

  const localSession = localStoreSessionId ? fetchLocalSession(input.localDbPath, localStoreSessionId) : null;
  const cdpSession = cdpStoreSessionId ? fetchCdpSession(input.cdpDbPath, cdpStoreSessionId) : null;
  const observedLocalRev = localSession ? String(localSession.observed_rev) : null;
  const observedCdpRev = currentObservedRevFromCdp(cdpSession);

  execSql(dbPath, `
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
INSERT INTO reconcile_runs (
  reconcile_run_id,
  orchestrator_session_id,
  trigger_kind,
  status,
  base_checkpoint_seq,
  observed_local_rev,
  observed_cdp_rev,
  diff_json,
  resolution_json,
  error_message,
  started_at_ms,
  finished_at_ms
) VALUES (
  ${sqlQuote(runId)},
  ${sqlQuote(sessionId)},
  ${sqlQuote(input.triggerKind ?? 'manual')},
  'running',
  ${sqlIntegerOrNull((latestCheckpoint && latestCheckpoint.checkpoint_seq) || 0)},
  ${sqlQuote(observedLocalRev)},
  ${sqlQuote(observedCdpRev)},
  NULL,
  NULL,
  NULL,
  ${sqlIntegerOrNull(startedAt)},
  NULL
);
UPDATE orchestrator_sessions
SET reconcile_state = 'reconciling',
    updated_at_ms = ${sqlIntegerOrNull(startedAt)}
WHERE orchestrator_session_id = ${sqlQuote(sessionId)};
COMMIT;
`);

  let status = 'ok';
  let diff = { localObservedRev: observedLocalRev, cdpObservedRev: observedCdpRev, changed: false };
  let resolution = { action: 'noop' };

  const baseLocalRev = latestCheckpoint ? latestCheckpoint.local_observed_rev : null;
  const baseCdpRev = latestCheckpoint ? latestCheckpoint.cdp_observed_rev : null;
  const changed = baseLocalRev !== observedLocalRev || baseCdpRev !== observedCdpRev;

  if (changed) {
    diff.changed = true;
    const state = {
      source: 'reconcile',
      local: localSession,
      cdp: cdpSession,
    };
    const checkpoint = saveCheckpoint(dbPath, {
      orchestratorSessionId: sessionId,
      checkpointKind: 'reconcile',
      localObservedRev,
      cdpObservedRev,
      state,
      createdAtMs: startedAt,
      reconcileState: 'clean',
    });
    resolution = { action: 'checkpoint-appended', checkpointSeq: checkpoint.checkpointSeq, stateHash: checkpoint.stateHash };
  }

  const finishedAt = Math.trunc(input.finishedAtMs ?? nowMs());
  execSql(dbPath, `
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
UPDATE reconcile_runs
SET status = ${sqlQuote(status)},
    diff_json = ${sqlQuote(stableStringify(diff))},
    resolution_json = ${sqlQuote(stableStringify(resolution))},
    finished_at_ms = ${sqlIntegerOrNull(finishedAt)}
WHERE reconcile_run_id = ${sqlQuote(runId)};
UPDATE orchestrator_sessions
SET reconcile_state = 'clean',
    updated_at_ms = ${sqlIntegerOrNull(finishedAt)}
WHERE orchestrator_session_id = ${sqlQuote(sessionId)};
COMMIT;
`);

  return {
    ok: true,
    reconcileRunId: runId,
    orchestratorSessionId: sessionId,
    status,
    observedLocalRev,
    observedCdpRev,
    changed,
  };
}

export function parseArgs(args) {
  const parsed = {
    dbPath: DEFAULT_DB_PATH,
    action: null,
    orchestratorSessionId: null,
    canonicalStore: 'cdp_agent_session_sqlite',
    status: 'open',
    storeName: null,
    storeSessionId: null,
    relationKind: 'primary',
    observedRev: null,
    checkpointKind: 'manual',
    stateJsonFile: null,
    localObservedRev: null,
    cdpObservedRev: null,
    localDbPath: 'local_agent_session.sqlite',
    cdpDbPath: 'session_persistence_meta.sqlite',
    triggerKind: 'manual',
    printSchema: false,
  };

  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    switch (a) {
      case '--db': parsed.dbPath = args[++i] ?? fail('--db requires a value'); break;
      case '--action': parsed.action = args[++i] ?? fail('--action requires a value'); break;
      case '--orchestrator-session-id': parsed.orchestratorSessionId = args[++i] ?? fail('--orchestrator-session-id requires a value'); break;
      case '--canonical-store': parsed.canonicalStore = args[++i] ?? fail('--canonical-store requires a value'); break;
      case '--status': parsed.status = args[++i] ?? fail('--status requires a value'); break;
      case '--store-name': parsed.storeName = args[++i] ?? fail('--store-name requires a value'); break;
      case '--store-session-id': parsed.storeSessionId = args[++i] ?? fail('--store-session-id requires a value'); break;
      case '--relation-kind': parsed.relationKind = args[++i] ?? fail('--relation-kind requires a value'); break;
      case '--observed-rev': parsed.observedRev = args[++i] ?? fail('--observed-rev requires a value'); break;
      case '--checkpoint-kind': parsed.checkpointKind = args[++i] ?? fail('--checkpoint-kind requires a value'); break;
      case '--state-json-file': parsed.stateJsonFile = args[++i] ?? fail('--state-json-file requires a value'); break;
      case '--local-observed-rev': parsed.localObservedRev = args[++i] ?? fail('--local-observed-rev requires a value'); break;
      case '--cdp-observed-rev': parsed.cdpObservedRev = args[++i] ?? fail('--cdp-observed-rev requires a value'); break;
      case '--local-db': parsed.localDbPath = args[++i] ?? fail('--local-db requires a value'); break;
      case '--cdp-db': parsed.cdpDbPath = args[++i] ?? fail('--cdp-db requires a value'); break;
      case '--trigger-kind': parsed.triggerKind = args[++i] ?? fail('--trigger-kind requires a value'); break;
      case '--print-schema': parsed.printSchema = true; break;
      default: fail(`unknown arg: ${a}`);
    }
  }

  return parsed;
}

export function main(argv = scriptArgs.slice(1)) {
  try {
    const parsed = parseArgs(argv);
    if (parsed.printSchema) {
      std.out.puts(SCHEMA_SQL);
      return 0;
    }

    let result;
    switch (parsed.action) {
      case 'init-db':
        result = initDb(parsed.dbPath);
        break;
      case 'init-session':
        result = initSession(parsed.dbPath, {
          orchestratorSessionId: parsed.orchestratorSessionId ?? fail('--orchestrator-session-id is required'),
          canonicalStore: parsed.canonicalStore,
          status: parsed.status,
        });
        break;
      case 'create-correlation':
        result = createCorrelation(parsed.dbPath, {
          orchestratorSessionId: parsed.orchestratorSessionId ?? fail('--orchestrator-session-id is required'),
          storeName: parsed.storeName ?? fail('--store-name is required'),
          storeSessionId: parsed.storeSessionId ?? fail('--store-session-id is required'),
          relationKind: parsed.relationKind,
          observedRev: parsed.observedRev,
        });
        break;
      case 'save-checkpoint': {
        const stateText = parsed.stateJsonFile ? std.loadFile(parsed.stateJsonFile) : null;
        if (stateText === null) fail('--state-json-file is required');
        const state = JSON.parse(stateText);
        result = saveCheckpoint(parsed.dbPath, {
          orchestratorSessionId: parsed.orchestratorSessionId ?? fail('--orchestrator-session-id is required'),
          checkpointKind: parsed.checkpointKind,
          localObservedRev: parsed.localObservedRev,
          cdpObservedRev: parsed.cdpObservedRev,
          state,
        });
        break;
      }
      case 'reconcile':
        result = reconcile(parsed.dbPath, {
          orchestratorSessionId: parsed.orchestratorSessionId ?? fail('--orchestrator-session-id is required'),
          localDbPath: parsed.localDbPath,
          cdpDbPath: parsed.cdpDbPath,
          triggerKind: parsed.triggerKind,
        });
        break;
      default:
        fail('unknown or missing --action');
    }

    std.out.puts(JSON.stringify(result, null, 2) + '\n');
    return 0;
  } catch (err) {
    const message = err && err.message ? err.message : String(err);
    std.out.puts(JSON.stringify({ ok: false, error: message }) + '\n');
    return 1;
  }
}

if (import.meta.main) {
  std.exit(main(scriptArgs.slice(1)));
}
