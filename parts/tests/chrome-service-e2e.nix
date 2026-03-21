{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      testDir = ../chrome/test;

      mkTest =
        name: scriptName:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = [
            config.packages.chromedevtoolprotocol-service-suite
            pkgs.coreutils
            pkgs.curl
            pkgs.jq
            pkgs.python3
            pkgs.procps
            pkgs.systemd
            pkgs.util-linux
          ];
          text = ''
            export CHROME_SERVICE_TEST_DIR=${testDir}
            exec ${pkgs.bash}/bin/bash "$CHROME_SERVICE_TEST_DIR/${scriptName}" "$@"
          '';
        };

      profileSync = mkTest "test-chrome-service-profile-sync-e2e" "profile-sync-e2e.sh";
      runtime = mkTest "test-chrome-service-runtime-e2e" "runtime-e2e.sh";
      authState = mkTest "test-chrome-service-auth-state-e2e" "auth-state-e2e.sh";
      recoverGate = mkTest "test-chrome-service-recover-gate-e2e" "recover-gate-e2e.sh";
      systemdUser = mkTest "test-chrome-service-systemd-user-e2e" "systemd-user-e2e.sh";
    in
    {
      apps.test-chrome-service-profile-sync-e2e = {
        type = "app";
        program = "${profileSync}/bin/test-chrome-service-profile-sync-e2e";
        meta.description = "E2E coverage for profile sync policy";
      };

      apps.test-chrome-service-runtime-e2e = {
        type = "app";
        program = "${runtime}/bin/test-chrome-service-runtime-e2e";
        meta.description = "E2E coverage for copied-profile launch and health";
      };

      apps.test-chrome-service-auth-state-e2e = {
        type = "app";
        program = "${authState}/bin/test-chrome-service-auth-state-e2e";
        meta.description = "E2E coverage for app auth-state probing";
      };

      apps.test-chrome-service-recover-gate-e2e = {
        type = "app";
        program = "${recoverGate}/bin/test-chrome-service-recover-gate-e2e";
        meta.description = "E2E coverage for recovery gating";
      };

      apps.test-chrome-service-systemd-user-e2e = {
        type = "app";
        program = "${systemdUser}/bin/test-chrome-service-systemd-user-e2e";
        meta.description = "E2E coverage for systemd user service supervision";
      };

      packages.test-chrome-service-profile-sync-e2e = profileSync;
      packages.test-chrome-service-runtime-e2e = runtime;
      packages.test-chrome-service-auth-state-e2e = authState;
      packages.test-chrome-service-recover-gate-e2e = recoverGate;
      packages.test-chrome-service-systemd-user-e2e = systemdUser;
    };
}
