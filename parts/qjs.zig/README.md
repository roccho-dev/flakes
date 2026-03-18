# qjs.zig

This part packages `mitchellh/zig-quickjs-ng` (which vendors `quickjs-ng/quickjs`) in a way that keeps Zig's `build.zig.zon` as the contract for Zig users, while still allowing fully offline `nix build`/`nix flake check`.

## Outputs

- `.#zig-quickjs-ng`: installs `lib/libquickjs-ng.a` and `include/quickjs.h`
- `.#zig-quickjs-ng-src`: pinned `mitchellh/zig-quickjs-ng` source
- `.#zig-quickjs-ng-tarball`: pinned GitHub source tarball for `zig-quickjs-ng` (matches example `.url`)
- `.#quickjs-ng-tarball`: pinned QuickJS tarball URL from `build.zig.zon`
- `.#zig-quickjs-ng-pkgdir`: internal `zig --system` package dir for building `zig-quickjs-ng` (contains only its QuickJS dependency)
- `.#zig-quickjs-ng-system-pkgdir`: `zig --system` package dir for host apps (contains `zig-quickjs-ng` + transitive deps)
- `.#zig-quickjs-ng-host-example`: builds `bin/qjs-host-example` from `examples/zig-quickjs-ng-host`

## How it works

- `build.zig.zon` remains unchanged upstream: we do not switch dependencies to `.path`.
- Nix fetches dependency tarballs and runs `zig fetch` to materialize `--system` package dirs.
- Builds/tests run with `zig build --system <pkgdir>` so Zig never needs network access.

## Useful commands

```bash
# Build the packaged static lib + header
nix build .#zig-quickjs-ng

# Run all invariants (zon unchanged, hash match, offline build/test, host smoke)
nix flake check
```

## Checks

- `zig-quickjs-ng-zon-unchanged`: asserts upstream `.url`/`.hash` remain the dependency contract
- `zig-quickjs-ng-deps-hash-match`: asserts `zig fetch` matches the declared Zig hash
- `zig-quickjs-ng-offline-build` / `zig-quickjs-ng-offline-test`: verifies offline build/test via `--system`
- `zig-quickjs-ng-host-smoke`: compiles and runs a tiny Zig program that `@cImport`s `quickjs.h` and links `libquickjs-ng.a`
- `zig-quickjs-ng-host-example-zon-unchanged`: asserts `examples/zig-quickjs-ng-host/build.zig.zon` stays `.url`/`.hash`
- `zig-quickjs-ng-host-example-offline-build`: builds the Zig host example offline via `--system`
- `zig-quickjs-ng-host-example-run`: runs the host example binary
