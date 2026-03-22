# amp flake

Self-contained flake that exposes the official `amp` package.

## Goals

- public package name: `amp`
- entrypoint: `nix shell .#amp -c amp --help`
- no `ampcode` alias
- self-contained under this directory

## Usage inside this flake

```bash
nix build .#amp
nix run .#amp -- --help
nix shell .#amp -c amp --help
```

## Integrating into another flake

### Option A: input reference

Add an input that points to this directory.

```nix
inputs.amp.url = "/home/nixos/repos/flakes/amp";
```

Then import the helper part:

```nix
./parts/amp/default.nix
```

A ready-to-copy helper part is included here:

```text
integration/parts/amp/default.nix
```

Copy that file into your main repo as:

```text
/home/nixos/repos/parts/amp/default.nix
```

After that, your main flake only needs this one additional import line.

## Notes

- `mainProgram = "amp"`
- package source is the official npm tarball for `@sourcegraph/amp`
- CI workflow is included at `.github/workflows/ci.yml`
