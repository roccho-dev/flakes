PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS orchestrator_sessions (
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

INSERT OR REPLACE INTO orchestrator_sessions (
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
  'seed-orch-001',
  'cdp_agent_session_sqlite',
  'open',
  'clean',
  1,
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  1735689605000,
  1735689605000,
  NULL
);

INSERT OR REPLACE INTO session_correlations (
  store_name,
  store_session_id,
  orchestrator_session_id,
  relation_kind,
  observed_rev,
  observed_at_ms,
  created_at_ms
) VALUES (
  'cdp_agent_session_sqlite',
  'seed-cdp-001',
  'seed-orch-001',
  'primary',
  '1735689604000:2',
  1735689605000,
  1735689605000
);

INSERT OR REPLACE INTO session_checkpoints (
  orchestrator_session_id,
  checkpoint_seq,
  checkpoint_kind,
  local_observed_rev,
  cdp_observed_rev,
  state_json,
  state_hash,
  created_at_ms
) VALUES (
  'seed-orch-001',
  1,
  'bootstrap',
  NULL,
  '1735689604000:2',
  '{"seed":true}',
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  1735689605000
);
