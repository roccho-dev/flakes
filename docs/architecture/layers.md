# Layers

This repo has four roles.

- `parts/os/`: machine substrate for NixOS hosts
- `parts/user/`: persistent Home Manager layer for the user profile
- `parts/opencode/`, `parts/helix/`, `parts/languages/`: reusable primitives and domain contracts
- `parts/packages.nix`: thin root assembler for cross-domain public bundles such as `editor-tools` and `git-tools`

## Opencode

`opencode` has two routes and one implementation.

- Interactive route: `nix shell .#editor-tools`
- Persistent route: `parts/user/home.nix` imports `parts/opencode/hm.nix`

Both routes now share the same wrapped package from `parts/opencode/package.nix`.

That keeps these concerns aligned:

- repo-pinned `opencode.json`
- default `OPENCODE_DISABLE_LSP_DOWNLOAD=true`
- default `OPENCODE_DISABLE_AUTOUPDATE=true`

## Reading The Tree

When deciding where a change belongs:

- if it changes machine state, put it in `parts/os/`
- if it changes long-lived user state, put it in `parts/user/`
- if it changes a single-domain tool contract or package, put it next to that domain (`parts/opencode/`, `parts/helix/`, `parts/cdp/`, `parts/chromedevtoolprotocol.zig/`, ...)
- if it changes only a cross-domain public bundle such as `editor-tools` or `git-tools`, put it in `parts/packages.nix`
