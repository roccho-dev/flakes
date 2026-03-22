-- session_persistence_meta.sqlite schema
-- CDP results persistence for 3-store architecture

CREATE TABLE IF NOT EXISTS cdp_sessions (
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
);
