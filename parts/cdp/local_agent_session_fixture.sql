PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS local_agent_sessions (
  id TEXT PRIMARY KEY,
  url TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL DEFAULT '',
  observed_rev TEXT NOT NULL,
  message_count INTEGER NOT NULL DEFAULT 0 CHECK (message_count >= 0),
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS local_agent_messages (
  session_id TEXT NOT NULL
    REFERENCES local_agent_sessions(id) ON DELETE CASCADE,
  ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system', 'tool', 'unknown')),
  content TEXT NOT NULL,
  created_at_ms INTEGER,
  PRIMARY KEY (session_id, ordinal)
);

INSERT OR REPLACE INTO local_agent_sessions (
  id, url, title, observed_rev, message_count, created_at_ms, updated_at_ms
) VALUES (
  'abc123',
  'https://chatgpt.com/c/abc123',
  'Fixture Thread',
  'local:r1',
  2,
  1735689600000,
  1735689602000
);

DELETE FROM local_agent_messages WHERE session_id = 'abc123';
INSERT INTO local_agent_messages (session_id, ordinal, role, content, created_at_ms) VALUES
('abc123', 0, 'user', 'Hello from local fixture', 1735689600001),
('abc123', 1, 'assistant', 'Hello back from local fixture', 1735689600002);
