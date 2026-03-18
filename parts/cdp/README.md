# cdp

Repo-local CDP helpers, QJS scripts, and Nix glue.

This directory is not the `chromedevtoolprotocol.zig` dependency itself.
`parts/hq.zig` consumes the Zig module from `chromedevtoolprotocol.zig/`, while
`parts/cdp` contains the local operational tooling around it.
