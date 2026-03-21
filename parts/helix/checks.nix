# Helix checks
{ lib, ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      cmds = config.helix.commandsList;

      cmdArgs = lib.concatStringsSep " " (map lib.escapeShellArg cmds);

      requiredCommandsFile = pkgs.writeText "helix-required-commands.txt" (
        (lib.concatStringsSep "\n" cmds) + "\n"
      );

      helixCommandsOnPath =
        pkgs.runCommand "helix-commands-on-path"
          {
            nativeBuildInputs = lib.unique (
              config.helix.requiredPkgs
              ++ [
                pkgs.bash
                pkgs.coreutils
              ]
            );
          }
          ''
            set -euo pipefail
            ${pkgs.bash}/bin/bash ${./tests/commands-on-path.sh} ${cmdArgs}
            touch "$out"
          '';

      hxHealthAnywhere =
        pkgs.runCommand "hx-health-anywhere"
          {
            nativeBuildInputs = lib.unique (
              config.helix.requiredPkgs
              ++ [
                config.packages.hx
                pkgs.bash
                pkgs.gnused
              ]
            );
          }
          ''
            set -euo pipefail

            export HELIX_REQUIRED_COMMANDS_FILE="${requiredCommandsFile}"

            # Source of truth for injection is the hx wrapper.
            TERM=dumb NO_COLOR=1 hx --health 2>&1 | ${pkgs.bash}/bin/bash ${./tests/hx-health-contract.sh}

            touch "$out"
          '';

      hxWrapperInjectsLanguages =
        pkgs.runCommand "hx-wrapper-injects-languages"
          {
            nativeBuildInputs = [
              config.packages.hx
              pkgs.coreutils
            ];
          }
          ''
            set -euo pipefail

            tmp="$TMPDIR/helix-wrapper"
            mkdir -p "$tmp"

            export TMPDIR="$tmp"

            # If the wrapper doesn't override HOME/XDG, Helix may touch this.
            export HOME="$PWD/trap-home"
            mkdir -p "$HOME"
            test ! -e "$HOME/.config"

            hx --version >/dev/null

            injected="$tmp/helix-home/.config/helix/languages.toml"
            test -L "$injected"

            target="$(${pkgs.coreutils}/bin/readlink "$injected")"
            test "$target" = "${config.helix.languagesToml}"

            test ! -e "$HOME/.config"

            touch "$out"
          '';
    in
    {
      checks.helix-commands-on-path = helixCommandsOnPath;
      checks.hx-health-anywhere = hxHealthAnywhere;
      checks.hx-wrapper-injects-languages = hxWrapperInjectsLanguages;

    };
}
