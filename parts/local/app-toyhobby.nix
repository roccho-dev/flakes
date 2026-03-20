{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      pkgsPoetry = inputs.nixpkgs-poetry.legacyPackages.${pkgs.system};

      runtimeLibs = with pkgs; [
        stdenv.cc.cc.lib
        zlib
      ];
      ldLibraryPath = pkgs.lib.makeLibraryPath runtimeLibs;

      poetryWrapped = pkgs.writeShellScriptBin "poetry" ''
        export LD_LIBRARY_PATH="${ldLibraryPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        exec ${pkgsPoetry.poetry}/bin/poetry "$@"
      '';

      # app_toyhobby (staging) expects Poetry + Node/npm/yarn + Docker(Compose) + gcloud.
      tools = [
        pkgs.git
        pkgs.gnumake
        pkgs.openssl

        pkgs.python312
        poetryWrapped

        # Web (yarn.lock exists; npm ships with node)
        pkgs.nodejs_22
        pkgs.yarn

        # Docker CLI (includes `docker compose` plugin)
        pkgs.docker

        # GCP CLI
        pkgs.google-cloud-sdk
      ] ++ runtimeLibs;

      appToyhobbyShell = pkgs.buildEnv {
        name = "app-toyhobby-shell";
        paths = tools;
      };
    in
    {
      packages.app-toyhobby = appToyhobbyShell;
      packages.app_toyhobby = appToyhobbyShell;

      devShells.app-toyhobby = pkgs.mkShell {
        packages = tools;
        shellHook = ''
          export POETRY_VIRTUALENVS_IN_PROJECT=true

          # Keep gcloud/ADC configs repo-scoped.
          export CLOUDSDK_CONFIG="$HOME/.secret/app_toyhobby/gcloud"
          mkdir -p "$CLOUDSDK_CONFIG" 2>/dev/null || true
          chmod 700 "$CLOUDSDK_CONFIG" 2>/dev/null || true

          # Avoid leaking explicit service account keys into this shell.
          unset GOOGLE_APPLICATION_CREDENTIALS
        '';
      };
    };
}
