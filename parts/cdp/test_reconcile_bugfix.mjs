import * as std from 'qjs:std';
import * as os from 'qjs:os';
import {
  initDb,
  initSession,
  createCorrelation,
  saveCheckpoint,
  reconcile,
  computeStateHash,
  queryJson,
  execSql,
} from './orchestrator.mjs';

const baseDir = '/tmp';
const localDbPath = `${baseDir}/test_local.sqlite`;
const cdpDbPath = `${baseDir}/test_cdp.sqlite`;
const orchDbPath = `${baseDir}/test_orch.sqlite`;

const LOCAL_SESSION_ID = 'local_test_001';
const CDP_SESSION_ID = 'cdp_test_001';
const ORCH_SESSION_ID = 'orch_test_001';

const localSchema = `
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS local_agent_sessions (
  id TEXT PRIMARY KEY,
  url TEXT NOT NULL,
  title TEXT DEFAULT '',
  observed_rev TEXT NOT NULL,
  message_count INTEGER DEFAULT 0,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS local_agent_messages (
  session_id TEXT NOT NULL,
  ordinal INTEGER NOT NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at_ms INTEGER,
  PRIMARY KEY (session_id, ordinal)
);`;

const cdpSchema = `
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS cdp_sessions (
  id TEXT PRIMARY KEY,
  url TEXT NOT NULL,
  title TEXT DEFAULT '',
  last_seen_ws_url TEXT,
  msg_count INTEGER DEFAULT 0,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS cdp_messages (
  session_id TEXT NOT NULL,
  ordinal INTEGER NOT NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at_ms INTEGER,
  PRIMARY KEY (session_id, ordinal)
);`;

std.out.puts('=== Initialize databases ===\n');

execSql(localDbPath, localSchema);
execSql(cdpDbPath, cdpSchema);
initDb(orchDbPath);

std.out.puts('Local DB: ' + localDbPath + '\n');
std.out.puts('CDP DB: ' + cdpDbPath + '\n');
std.out.puts('Orch DB: ' + orchDbPath + '\n');

std.out.puts('\n=== Insert test data ===\n');

const now = Date.now();

execSql(localDbPath, `
INSERT INTO local_agent_sessions (id, url, title, observed_rev, message_count, created_at_ms, updated_at_ms)
VALUES ('${LOCAL_SESSION_ID}', 'https://chatgpt.com/c/${LOCAL_SESSION_ID}', 'Local Test', 'local:v1', 2, ${now}, ${now});
INSERT INTO local_agent_messages (session_id, ordinal, role, content, created_at_ms)
VALUES
  ('${LOCAL_SESSION_ID}', 0, 'user', 'Hello local', ${now}),
  ('${LOCAL_SESSION_ID}', 1, 'assistant', 'Hello back local', ${now});
`);

execSql(cdpDbPath, `
INSERT INTO cdp_sessions (id, url, title, last_seen_ws_url, msg_count, created_at_ms, updated_at_ms)
VALUES ('${CDP_SESSION_ID}', 'https://chatgpt.com/c/${CDP_SESSION_ID}', 'CDP Test', 'ws://test/123', 3, ${now}, ${now});
INSERT INTO cdp_messages (session_id, ordinal, role, content, created_at_ms)
VALUES
  ('${CDP_SESSION_ID}', 0, 'user', 'Hello CDP', ${now}),
  ('${CDP_SESSION_ID}', 1, 'assistant', 'Hello back CDP', ${now}),
  ('${CDP_SESSION_ID}', 2, 'user', 'Another message', ${now});
`);

std.out.puts('Data inserted\n');

std.out.puts('\n=== Create orchestrator session ===\n');
const sessResult = initSession(orchDbPath, {
  orchestratorSessionId: ORCH_SESSION_ID,
  canonicalStore: 'cdp_agent_session_sqlite',
  status: 'open',
  reconcileState: 'dirty',
});
std.out.puts('Session init: ' + JSON.stringify(sessResult) + '\n');

std.out.puts('\n=== Create correlations ===\n');
const corr1 = createCorrelation(orchDbPath, {
  orchestratorSessionId: ORCH_SESSION_ID,
  storeName: 'cdp_agent_session_sqlite',
  storeSessionId: CDP_SESSION_ID,
  relationKind: 'primary',
  observedRev: `${now}:3`,
});
std.out.puts('CDP correlation: ' + JSON.stringify(corr1) + '\n');

const corr2 = createCorrelation(orchDbPath, {
  orchestratorSessionId: ORCH_SESSION_ID,
  storeName: 'local_agent_session_sqlite',
  storeSessionId: LOCAL_SESSION_ID,
  relationKind: 'mirror',
  observedRev: 'local:v1',
});
std.out.puts('Local correlation: ' + JSON.stringify(corr2) + '\n');

std.out.puts('\n=== Initial checkpoint ===\n');
const checkpoint1 = saveCheckpoint(orchDbPath, {
  orchestratorSessionId: ORCH_SESSION_ID,
  checkpointKind: 'bootstrap',
  localObservedRev: 'local:v1',
  cdpObservedRev: `${now}:3`,
  state: { source: 'bootstrap', local: LOCAL_SESSION_ID, cdp: CDP_SESSION_ID },
  reconcileState: 'clean',
});
std.out.puts('Checkpoint 1: ' + JSON.stringify(checkpoint1) + '\n');

std.out.puts('\n=== Update CDP data (simulate new messages) ===\n');
execSql(cdpDbPath, `
UPDATE cdp_sessions SET msg_count = 5, updated_at_ms = ${now + 1000} WHERE id = '${CDP_SESSION_ID}';
INSERT INTO cdp_messages (session_id, ordinal, role, content, created_at_ms)
VALUES ('${CDP_SESSION_ID}', 3, 'assistant', 'New CDP message', ${now + 1000});
INSERT INTO cdp_messages (session_id, ordinal, role, content, created_at_ms)
VALUES ('${CDP_SESSION_ID}', 4, 'user', 'Yet another', ${now + 1000});
`);

std.out.puts('\n=== Run reconcile ===\n');
const reconResult = reconcile(orchDbPath, {
  orchestratorSessionId: ORCH_SESSION_ID,
  localDbPath: localDbPath,
  cdpDbPath: cdpDbPath,
  triggerKind: 'manual',
});
std.out.puts('Reconcile result: ' + JSON.stringify(reconResult, null, 2) + '\n');

std.out.puts('\n=== Verify results ===\n');
const orchSessions = queryJson(orchDbPath, `SELECT * FROM orchestrator_sessions WHERE orchestrator_session_id = '${ORCH_SESSION_ID}'`);
const correlations = queryJson(orchDbPath, `SELECT * FROM session_correlations WHERE orchestrator_session_id = '${ORCH_SESSION_ID}'`);
const checkpoints = queryJson(orchDbPath, `SELECT * FROM session_checkpoints WHERE orchestrator_session_id = '${ORCH_SESSION_ID}'`);
const runs = queryJson(orchDbPath, `SELECT * FROM reconcile_runs WHERE orchestrator_session_id = '${ORCH_SESSION_ID}'`);

std.out.puts('Orch sessions: ' + JSON.stringify(orchSessions) + '\n');
std.out.puts('Correlations: ' + JSON.stringify(correlations) + '\n');
std.out.puts('Checkpoints: ' + JSON.stringify(checkpoints) + '\n');
std.out.puts('Reconcile runs: ' + JSON.stringify(runs) + '\n');

const finalResult = {
  ok: true,
  reconcileResult,
  orchSessions,
  correlations,
  checkpoints,
  reconcileRuns: runs,
};

std.out.puts('\n=== FINAL RESULT ===\n');
std.out.puts(JSON.stringify(finalResult, null, 2) + '\n');

std.writeFile('/tmp/orchestrator_test_result.json', JSON.stringify(finalResult, null, 2));
std.out.puts('\nResult written to /tmp/orchestrator_test_result.json\n');
