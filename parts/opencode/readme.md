# flakes-local (wrapper)

This directory holds local-only flake-parts modules ("parts") that wrap `roccho-dev/flakes`.

## Install (WSL)

```bash
wsl bash -lc 'nix profile install --profile ~/.local/state/nix/profiles/roccho \
  path:/home/nixos/repos/flakes-local#git-tools \
  path:/home/nixos/repos/flakes-local#editor-tools \
  path:/home/nixos/repos/flakes-local#bun-tooling'
```

## Notes

- `editor-tools` includes `opencode`.
- `opencode` version is pinned by this wrapper's `flake.lock` (via `nixpkgs`).
