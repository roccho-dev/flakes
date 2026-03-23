import * as std from 'qjs:std';
import * as os from 'qjs:os';

export const DEFAULT_DB_PATH = 'session_persistence_meta.sqlite';

const SCHEMA_BODY_SQL = String.raw`CREATE TABLE IF NOT EXISTS cdp_sessions (
  id TEXT PRIMARY KEY,
  url TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL DEFAULT '',
  last_seen_ws_url TEXT,
  msg_count INTEGER NOT NULL DEFAULT 0 CHECK (msg_count >= 0),
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS cdp_messages (
  session_id TEXT NOT NULL
    REFERENCES cdp_sessions(id) ON DELETE CASCADE,
  ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
  role TEXT NOT NULL
    CHECK (role IN ('user', 'assistant', 'system', 'tool', 'unknown')),
  content TEXT NOT NULL,
  created_at_ms INTEGER,
  PRIMARY KEY (session_id, ordinal)
);`;

function execSql(dbPath, sql) {
  const proc = os.spawn('sqlite3', [dbPath], { block: true, pipes: ['stdin', 'stdout', 'stderr'] });
  proc.stdin.write(sql);
  proc.stdin.close();
  const rc = proc.wait();
  if (rc !== 0) {
    const err = proc.stderr.read();
    throw new Error('sqlite3 error rc=' + rc + ' err=' + err);
  }
  return proc.stdout.read();
}

function initDb(dbPath) {
  return execSql(dbPath, SCHEMA_BODY_SQL);
}

function saveCdpResultsTo(dbPath, results) {
  const now = Date.now();
  const sessionId = results.sessionId || results.url;
  const title = (results.title || '').replace(/'/g, "''");
  const wsUrl = results.last_seen_ws_url || results.ws_url || '';
  
  const upsertSession = [
    "PRAGMA foreign_keys = ON;",
    "INSERT INTO cdp_sessions (id, url, title, last_seen_ws_url, msg_count, created_at_ms, updated_at_ms)",
    "VALUES ('" + sessionId + "', '" + results.url + "', '" + title + "', '" + wsUrl + "', " + (results.messages ? results.messages.length : 0) + ", " + now + ", " + now + ")",
    "ON CONFLICT(id) DO UPDATE SET",
    "  url=excluded.url,",
    "  title=excluded.title,",
    "  last_seen_ws_url=excluded.last_seen_ws_url,",
    "  msg_count=excluded.msg_count,",
    "  updated_at_ms=excluded.updated_at_ms;"
  ].join('\n');
  
  execSql(dbPath, upsertSession);
  
  if (results.messages && results.messages.length > 0) {
    let ordinal = 1;
    for (const msg of results.messages) {
      const role = (msg.role || 'unknown').replace(/'/g, "''");
      const content = (msg.content || '').replace(/'/g, "''");
      const upsertMsg = [
        "INSERT INTO cdp_messages (session_id, ordinal, role, content, created_at_ms)",
        "VALUES ('" + sessionId + "', " + ordinal + ", '" + role + "', '" + content + "', " + now + ")",
        "ON CONFLICT(session_id, ordinal) DO UPDATE SET",
        "  role=excluded.role,",
        "  content=excluded.content,",
        "  created_at_ms=excluded.created_at_ms;"
      ].join('\n');
      execSql(dbPath, upsertMsg);
      ordinal++;
    }
  }
  
  return { ok: true, sessionId, msgCount: results.messages ? results.messages.length : 0 };
}

function saveCdpResults(results, dbPath = DEFAULT_DB_PATH) {
  return saveCdpResultsTo(dbPath, results);
}

function parseArgs() {
  const args = { _: [] };
  for (const arg of scriptArgs.slice(1)) {
    if (arg.startsWith('--')) {
      const [k, v] = arg.slice(2).split('=');
      args[k] = v || true;
    } else {
      args._.push(arg);
    }
  }
  return args;
}

const isMain = scriptArgs[0] === import.meta.url || scriptArgs[0] === import.meta.filename;

if (isMain) {
  const args = parseArgs();
  const dbPath = args.db || DEFAULT_DB_PATH;
  
  if (args.init) {
    initDb(dbPath);
    std.out.puts('Initialized: ' + dbPath);
  } else if (args.url) {
    const results = {
      url: args.url,
      title: args.title || '',
      last_seen_ws_url: args.ws_url || '',
      messages: args.messages ? JSON.parse(args.messages) : []
    };
    const ret = saveCdpResultsTo(dbPath, results);
    std.out.puts(JSON.stringify(ret));
  } else {
    std.out.puts('Usage:');
    std.out.puts('  qjs --std -m cdp-results-to-sqlite.mjs --init [--db=<path>]');
    std.out.puts('  qjs --std -m cdp-results-to-sqlite.mjs --url=<url> [--db=<path>] [--title=<title>] [--ws_url=<url>] [--messages=<json>]');
  }
}

export { initDb, saveCdpResultsTo, saveCdpResults, parseArgs };
