export const STORAGE_URN_PREFIX = 'urn:storage:';

export const STORAGE_REGISTRY = {
  local_agent_session_sqlite: {
    urn: 'urn:storage:local_agent_session_sqlite',
    description: 'Local agent session store managed by opencode',
    defaultPath: 'local_agent_session.sqlite',
    schema: 'local',
  },
  cdp_agent_session_sqlite: {
    urn: 'urn:storage:cdp_agent_session_sqlite',
    description: 'CDP agent session store (ChatGPT sessions via CDP)',
    defaultPath: 'session_persistence_meta.sqlite',
    schema: 'cdp',
  },
  orchestrator_meta_sqlite: {
    urn: 'urn:storage:orchestrator_meta_sqlite',
    description: 'Orchestrator metadata store (correlation, checkpoints, reconcile)',
    defaultPath: 'orchestrator_meta.sqlite',
    schema: 'orchestrator',
  },
};

export function resolveUrn(urn) {
  const key = urn.replace(STORAGE_URN_PREFIX, '');
  return STORAGE_REGISTRY[key] || null;
}

export function getDefaultPath(urn) {
  const entry = resolveUrn(urn);
  return entry ? entry.defaultPath : null;
}

export function listUrns() {
  return Object.values(STORAGE_REGISTRY).map(e => e.urn);
}

export function validateUrn(urn) {
  if (!urn.startsWith(STORAGE_URN_PREFIX)) {
    return { valid: false, error: 'URN must start with ' + STORAGE_URN_PREFIX };
  }
  const entry = resolveUrn(urn);
  if (!entry) {
    return { valid: false, error: 'Unknown storage URN: ' + urn };
  }
  return { valid: true, entry };
}
