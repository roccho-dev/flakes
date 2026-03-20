# OpenCode Version Matrix

This matrix records only versions observed during the incident.

| Version | Observed role | Observed DB path behavior |
|---|---|---|
| `1.2.13` | `github:roccho-dev/flakes#opencode` and `#editor-tools` at the time of inspection | not the active server path for this incident |
| `1.2.20` | older local and remote CLI flows | operated on `opencode.db` during recovery work |
| `1.2.27` | `nixpkgs` unstable client and `opencode-home.service` server | read `opencode-stable.db` during recovery work |

## Rule

When debugging attach or session visibility, verify all of the following:

- client version
- server version
- DB path opened by that version

Do not assume matching session behavior across versions, even when the DB schema
looks compatible.
