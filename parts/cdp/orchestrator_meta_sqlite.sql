-- orchestrator_meta_sqlite schema
-- 3-store architecture: orchestrator sole writer
-- checkpoint / correlation / reconcile の3責務
-- v2: updated_at_ms追加, correlation_token策略明確化, blob size CHECK

CREATE TABLE IF NOT EXISTS orchestrator_sessions (
  id TEXT PRIMARY KEY,
  status TEXT NOT NULL DEFAULT 'running',
  started_at_ms INTEGER NOT NULL,
  completed_at_ms INTEGER,
  error_message TEXT
);

CREATE TABLE IF NOT EXISTS session_correlations (
  id TEXT PRIMARY KEY,
  local_agent_session_id TEXT,
  cdp_agent_session_id TEXT,
  orchestrator_session_id TEXT,
  correlation_token TEXT NOT NULL UNIQUE,
  created_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS session_checkpoints (
  id TEXT PRIMARY KEY,
  store_type TEXT NOT NULL,
  store_path TEXT NOT NULL,
  checkpoint_data TEXT NOT NULL CHECK (length(checkpoint_data) <= 1048576),
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS session_reconcile_detail (
  id TEXT PRIMARY KEY,
  source_store TEXT NOT NULL,
  target_store TEXT NOT NULL,
  reconcile_type TEXT NOT NULL,
  status TEXT NOT NULL,
  details TEXT,
  created_at_ms INTEGER NOT NULL,
  completed_at_ms INTEGER
);
