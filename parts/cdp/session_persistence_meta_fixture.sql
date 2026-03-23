PRAGMA foreign_keys = ON;

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

CREATE INDEX IF NOT EXISTS idx_cdp_messages_session_created
ON cdp_messages(session_id, created_at_ms);

INSERT OR REPLACE INTO cdp_sessions (
  id, url, title, last_seen_ws_url, msg_count, created_at_ms, updated_at_ms
) VALUES (
  'seed-cdp-001',
  'https://chatgpt.com/c/seed-cdp-001',
  'Seeded CDP Session',
  'ws://fixture.example/seed-cdp-001',
  2,
  1735689603000,
  1735689604000
);

DELETE FROM cdp_messages WHERE session_id = 'seed-cdp-001';
INSERT INTO cdp_messages (session_id, ordinal, role, content, created_at_ms) VALUES
('seed-cdp-001', 0, 'user', 'Seed fixture user message', 1735689603001),
('seed-cdp-001', 1, 'assistant', 'Seed fixture assistant message', 1735689603002);
