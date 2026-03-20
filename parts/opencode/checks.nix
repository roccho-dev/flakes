{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      wrappedOpencode = import ./package.nix { inherit pkgs; };
      opencodeConfig = ../../opencode.json;

      configVanilla =
        pkgs.runCommand "opencode-config-vanilla"
          {
            nativeBuildInputs = [
              pkgs.jq
              pkgs.coreutils
            ];
          }
          ''
            set -euo pipefail

            ${pkgs.jq}/bin/jq -e 'keys == ["$schema"]' "${opencodeConfig}" >/dev/null

            touch "$out"
          '';

      opencodeSmoke =
        pkgs.runCommand "opencode-smoke"
          {
            nativeBuildInputs = [
              wrappedOpencode
              pkgs.coreutils
            ];
          }
          ''
            set -euo pipefail

            export HOME="$TMPDIR/home"
            export XDG_CONFIG_HOME="$HOME/.config"
            export XDG_CACHE_HOME="$HOME/.cache"
            export XDG_STATE_HOME="$HOME/.local/state"
            mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

            # Wrapper pins repo config and offline-safe defaults.
            cd "$TMPDIR"

            opencode --version >/dev/null
            opencode --help >/dev/null

            touch "$out"
          '';

      debugLspEntryExists =
        pkgs.runCommand "opencode-debug-lsp-entry-exists"
          {
            nativeBuildInputs = [
              wrappedOpencode
              pkgs.coreutils
            ];
          }
          ''
            set -euo pipefail

            export HOME="$TMPDIR/home"
            export XDG_CONFIG_HOME="$HOME/.config"
            export XDG_CACHE_HOME="$HOME/.cache"
            export XDG_STATE_HOME="$HOME/.local/state"
            mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

            opencode debug lsp --help >/dev/null

            touch "$out"
          '';

      wrapperEnvContract =
        pkgs.runCommand "opencode-wrapper-env-contract"
          {
            nativeBuildInputs = [
              config.packages.opencode
              pkgs.bash
              pkgs.coreutils
              pkgs.gnugrep
            ];
          }
          ''
            set -euo pipefail

            export HOME="$TMPDIR/home"
            export XDG_CONFIG_HOME="$HOME/.config"
            export XDG_CACHE_HOME="$HOME/.cache"
            export XDG_STATE_HOME="$HOME/.local/state"
            mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

            unset OPENCODE_DISABLE_LSP_DOWNLOAD OPENCODE_DISABLE_AUTOUPDATE

            # Start a long-running subcommand so we can inspect /proc/<pid>/environ.
            opencode serve --hostname 127.0.0.1 --port 0 --log-level ERROR --print-logs >/dev/null 2>&1 &
            pid=$!

            # Give it a moment to start.
            ${pkgs.coreutils}/bin/sleep 0.5

            envfile="/proc/$pid/environ"
            test -r "$envfile"

            ${pkgs.coreutils}/bin/tr '\000' '\n' < "$envfile" > "$TMPDIR/environ.txt"

            ${pkgs.gnugrep}/bin/grep -Fxq "OPENCODE_DISABLE_LSP_DOWNLOAD=true" "$TMPDIR/environ.txt"
            ${pkgs.gnugrep}/bin/grep -Fxq "OPENCODE_DISABLE_AUTOUPDATE=true" "$TMPDIR/environ.txt"

            kill "$pid" >/dev/null 2>&1 || true
            wait "$pid" >/dev/null 2>&1 || true

            touch "$out"
          '';

      goDiagnostics =
        pkgs.runCommand "opencode-lsp-go-diagnostics"
          {
            nativeBuildInputs = [
              wrappedOpencode
              pkgs.jq
              pkgs.coreutils
              pkgs.bash
              pkgs.go
              pkgs.gopls
            ];
          }
          ''
            set -euo pipefail

            export HOME="$TMPDIR/home"
            export XDG_CONFIG_HOME="$HOME/.config"
            export XDG_CACHE_HOME="$HOME/.cache"
            export XDG_STATE_HOME="$HOME/.local/state"
            mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

            mkdir -p "$TMPDIR/clean" "$TMPDIR/err"

            cat >"$TMPDIR/clean/go.mod" <<'EOF'
            module example.com/test

            go 1.22
            EOF
            cat >"$TMPDIR/clean/main.go" <<'EOF'
            package main

            func main() {
            	println("ok")
            }
            EOF

            cat >"$TMPDIR/err/go.mod" <<'EOF'
            module example.com/test

            go 1.22
            EOF
            cat >"$TMPDIR/err/main.go" <<'EOF'
            package main

            func main() {
            	println(unknownVar)
            }
            EOF

            clean_out="$TMPDIR/clean.json"
            err_out="$TMPDIR/err.json"

            (cd "$TMPDIR/clean" && opencode debug lsp diagnostics "$TMPDIR/clean/main.go") >"$clean_out"
            (cd "$TMPDIR/err" && opencode debug lsp diagnostics "$TMPDIR/err/main.go") >"$err_out"

            # clean should have zero diagnostics
            ${pkgs.jq}/bin/jq -e '.[keys[0]] | length == 0' "$clean_out" >/dev/null

            # err should have at least one diagnostic
            ${pkgs.jq}/bin/jq -e '.[keys[0]] | length > 0' "$err_out" >/dev/null

            touch "$out"
          '';

    in
    {
      checks.opencode-config-vanilla = configVanilla;
      checks.opencode-smoke = opencodeSmoke;
      checks.opencode-debug-lsp-entry-exists = debugLspEntryExists;
      checks.opencode-wrapper-env-contract = wrapperEnvContract;
      checks.opencode-lsp-go-diagnostics = goDiagnostics;
    };
}
