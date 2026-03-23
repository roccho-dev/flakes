import * as std from 'qjs:std';
import * as os from 'qjs:os';
import {
  initDb as initOrchestratorDb,
  initSession,
  createCorrelation,
  saveCheckpoint,
  reconcile,
  computeStateHash,
  queryJson,
  execSql,
} from './orchestrator.mjs';

function fail(message) {
  throw new Error(message);
}

function dirname(path) {
  const i = path.lastIndexOf('/');
  return i <= 0 ? '/' : path.slice(0, i);
}

function fileUrlToPath(url) {
  if (!url.startsWith('file://')) fail(`unsupported import.meta.url: ${url}`);
  return url.slice('file://'.length);
}

function joinPath(a, b) {
  return a.endsWith('/') ? a + b : a + '/' + b;
}

function readText(path) {
  const text = std.loadFile(path);
  if (text === null) fail(`failed to read file: ${path}`);
  return text;
}

function writeText(path, text) {
  std.writeFile(path, text);
}

function uniquePath(baseDir, prefix, ext) {
  return joinPath(baseDir, `${prefix}_${Date.now()}_${Math.random().toString(16).slice(2)}${ext}`);
}

function applySqlFile(dbPath, sqlPath) {
  execSql(dbPath, readText(sqlPath));
}

function spawnQjs(scriptPath, args) {
  const stdoutPipe = os.pipe();
  const stderrPipe = os.pipe();
  if (stdoutPipe === null || stderrPipe === null) fail('os.pipe() failed');
  const [stdoutReadFd, stdoutWriteFd] = stdoutPipe;
  const [stderrReadFd, stderrWriteFd] = stderrPipe;

  const rc = os.exec(['qjs', '--std', '-m', scriptPath, ...args], {
    block: true,
    usePath: true,
    stdout: stdoutWriteFd,
    stderr: stderrWriteFd,
  });

  os.close(stdoutWriteFd);
  os.close(stderrWriteFd);

  const outFile = std.fdopen(stdoutReadFd, 'r');
  const errFile = std.fdopen(stderrReadFd, 'r');
  if (outFile === null || errFile === null) fail('std.fdopen() failed');
  const stdoutText = outFile.readAsString();
  const stderrText = errFile.readAsString();
  outFile.close();
  errFile.close();

  if (rc !== 0) {
    fail(`qjs child failed rc=${rc} stdout=${stdoutText} stderr=${stderrText}`);
  }
  return { stdoutText, stderrText };
}

function parseJson(text) {
  try {
    return JSON.parse(text);
  } catch (_) {
    fail(`invalid JSON: ${text}`);
  }
}

function assert(cond, message) {
  if (!cond) fail(message);
}

export function main() {
  const baseDir = dirname(fileUrlToPath(import.meta.url));
  const localDbPath = uniquePath(baseDir, 'local_agent_session', '.sqlite');
  const cdpDbPath = uniquePath(baseDir, 'session_persistence_meta', '.sqlite');
  const orchestratorDbPath = uniquePath(baseDir, 'orchestrator_meta', '.sqlite');
  const cdpResultsPath = uniquePath(baseDir, 'cdp_fixture', '.json');

  const cdpResults = {
    session_id: 'abc123',
    url: 'https://chatgpt.com/c/abc123',
    ws_url: 'ws://fixture.example/abc123',
    title: 'Fixture Thread',
    created_at_ms: 1735689600000,
    updated_at_ms: 1735689607000,
    messages: [
      { role: 'user', content: 'Hello from CDP fixture', created_at_ms: 1735689600001 },
      { role: 'assistant', content: 'Hello from assistant fixture', created_at_ms: 1735689600002 },
      { role: 'user', content: 'Need 3-store verification', created_at_ms: 1735689600003 },
      { role: 'assistant', content: '3-store verification acknowledged', created_at_ms: 1735689600004 },
    ],
  };
  writeText(cdpResultsPath, JSON.stringify(cdpResults, null, 2));

  applySqlFile(localDbPath, joinPath(baseDir, 'local_agent_session_fixture.sql'));
  applySqlFile(cdpDbPath, joinPath(baseDir, 'session_persistence_meta_fixture.sql'));
  initOrchestratorDb(orchestratorDbPath);
  applySqlFile(orchestratorDbPath, joinPath(baseDir, 'orchestrator_meta_fixture.sql'));

  const cdpSave = parseJson(spawnQjs(joinPath(baseDir, 'cdp-results-to-sqlite.mjs'), [
    '--db', cdpDbPath,
    '--json-file', cdpResultsPath,
  ]).stdoutText);
  assert(cdpSave.ok === true, 'cdp save failed');
  assert(cdpSave.sessionId === 'abc123', 'unexpected cdp session id');

  const orchestratorSessionId = 'orch_abc123';
  initSession(orchestratorDbPath, {
    orchestratorSessionId,
    canonicalStore: 'cdp_agent_session_sqlite',
    status: 'open',
    reconcileState: 'dirty',
  });

  createCorrelation(orchestratorDbPath, {
    orchestratorSessionId,
    storeName: 'cdp_agent_session_sqlite',
    storeSessionId: 'abc123',
    relationKind: 'primary',
    observedRev: '1735689607000:4',
  });

  createCorrelation(orchestratorDbPath, {
    orchestratorSessionId,
    storeName: 'local_agent_session_sqlite',
    storeSessionId: 'abc123',
    relationKind: 'mirror',
    observedRev: 'local:r1',
  });

  const checkpointState = {
    source: 'e2e-bootstrap',
    cdp: cdpResults,
    local: {
      id: 'abc123',
      observed_rev: 'local:r1',
    },
  };

  const checkpoint = saveCheckpoint(orchestratorDbPath, {
    orchestratorSessionId,
    checkpointKind: 'write_through',
    localObservedRev: 'local:r1',
    cdpObservedRev: '1735689607000:4',
    state: checkpointState,
    stateHash: computeStateHash(checkpointState),
  });
  assert(checkpoint.ok === true, 'checkpoint failed');

  const reconciled = reconcile(orchestratorDbPath, {
    orchestratorSessionId,
    localDbPath,
    cdpDbPath,
    triggerKind: 'write_through',
  });
  assert(reconciled.ok === true, 'reconcile failed');

  const cdpSessions = queryJson(cdpDbPath, `
SELECT id, url, title, last_seen_ws_url, msg_count, updated_at_ms
FROM cdp_sessions
WHERE id = 'abc123';
`);
  const cdpMessages = queryJson(cdpDbPath, `
SELECT ordinal, role, content
FROM cdp_messages
WHERE session_id = 'abc123'
ORDER BY ordinal;
`);
  const localSessions = queryJson(localDbPath, `
SELECT id, url, title, observed_rev, message_count
FROM local_agent_sessions
WHERE id = 'abc123';
`);
  const orchSessions = queryJson(orchestratorDbPath, `
SELECT orchestrator_session_id, canonical_store, status, reconcile_state, canonical_checkpoint_seq
FROM orchestrator_sessions
WHERE orchestrator_session_id = ${"'" + orchestratorSessionId + "'"};
`);
  const correlations = queryJson(orchestratorDbPath, `
SELECT store_name, store_session_id, relation_kind, observed_rev
FROM session_correlations
WHERE orchestrator_session_id = ${"'" + orchestratorSessionId + "'"}
ORDER BY store_name;
`);
  const checkpoints = queryJson(orchestratorDbPath, `
SELECT checkpoint_seq, checkpoint_kind, local_observed_rev, cdp_observed_rev, state_hash
FROM session_checkpoints
WHERE orchestrator_session_id = ${"'" + orchestratorSessionId + "'"}
ORDER BY checkpoint_seq;
`);
  const reconcileRuns = queryJson(orchestratorDbPath, `
SELECT trigger_kind, status, observed_local_rev, observed_cdp_rev
FROM reconcile_runs
WHERE orchestrator_session_id = ${"'" + orchestratorSessionId + "'"}
ORDER BY started_at_ms;
`);

  assert(cdpSessions.length === 1, 'cdp session missing');
  assert(cdpMessages.length === 4, 'cdp messages count mismatch');
  assert(localSessions.length === 1, 'local session missing');
  assert(orchSessions.length === 1, 'orchestrator session missing');
  assert(correlations.length === 2, 'correlations count mismatch');
  assert(checkpoints.length >= 1, 'checkpoint missing');
  assert(reconcileRuns.length >= 1, 'reconcile run missing');

  const result = {
    ok: true,
    cdpSave,
    checkpoint,
    reconciled,
    assertions: {
      cdpSessionId: cdpSessions[0].id,
      cdpMsgCount: cdpSessions[0].msg_count,
      localObservedRev: localSessions[0].observed_rev,
      orchestratorSessionId: orchSessions[0].orchestrator_session_id,
      correlationCount: correlations.length,
      latestCheckpointSeq: checkpoints[checkpoints.length - 1].checkpoint_seq,
      reconcileRunCount: reconcileRuns.length,
    },
    stores: {
      local: { dbPath: localDbPath, sessions: localSessions },
      cdp: { dbPath: cdpDbPath, sessions: cdpSessions, messages: cdpMessages },
      orchestrator: {
        dbPath: orchestratorDbPath,
        sessions: orchSessions,
        correlations,
        checkpoints,
        reconcileRuns,
      },
    },
  };

  std.out.puts(JSON.stringify(result, null, 2) + '\n');
  return 0;
}

if (import.meta.main) {
  try {
    std.exit(main());
  } catch (err) {
    const message = err && err.message ? err.message : String(err);
    std.out.puts(JSON.stringify({ ok: false, error: message }) + '\n');
    std.exit(1);
  }
}
