# flakes

Layered Nix repo for machine substrate, persistent user state, and reusable tool primitives.

## Layers

- `parts/os/`: machine substrate
- `parts/user/`: persistent user layer
- `parts/opencode/`, `parts/helix/`, `parts/languages/`: primitive and domain contracts
- `parts/packages.nix`: assembles end-user entrypoints such as `editor-tools` and `git-tools`

See `docs/architecture/layers.md` for the intended boundaries.

## Entrypoints

### CI / DoD

```bash
nix flake check
nix run .#test-integration
nix run .#test-e2e
```

### Human (interactive)

```bash
# Show quick help
nix run .#help

# Editor tools (hx, opencode)
nix shell .#editor-tools

# Git tools
nix shell .#git-tools

# Editor + language tooling (example: Go)
nix shell .#editor-tools .#go-tooling
```

## Usage

```bash
# Example: show help
nix run .#help

# Example: run opencode with repo config
nix shell .#editor-tools -c opencode

# Example: authenticate (requires network and user interaction)
nix shell .#editor-tools -c opencode auth login

# Example: smoke
nix shell .#editor-tools -c opencode --version
```

## Files

- `opencode.json`: Minimal vanilla config (schema only)
- `flake.nix`: flake-parts setup (no devShells)
- `parts/packages.nix`: assembles end-user package entrypoints
- `parts/opencode/package.nix`: shared wrapped `opencode` package used by shell and Home Manager
- `parts/languages/*.nix`: Language tooling parts (v1 contract)

## DoD

- [ ] `~/.config/opencode/opencode.json` is symlinked
- [ ] `~/.local/share/opencode/auth.json` exists (authenticated)
- [ ] `opencode run "hello" --model=openai/gpt-5.1-codex-low` returns response
