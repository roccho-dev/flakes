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
            pkgs.xdpyinfo
          ];
          text = ''
            export CHROME_SERVICE_TEST_DIR=${testDir}
            exec ${pkgs.bash}/bin/bash "$CHROME_SERVICE_TEST_DIR/${scriptName}" "$@"
          '';
        };

      profileSync = mkTest "test-chrome-service-profile-sync-e2e" "profile-sync-e2e.sh";
      profileBootstrap = mkTest "test-chrome-service-profile-bootstrap-smoke-e2e" "profile-bootstrap-smoke-e2e.sh";
      profilePublish = mkTest "test-chrome-service-profile-publish-e2e" "profile-publish-e2e.sh";
      profileStatus = mkTest "test-chrome-service-profile-status-e2e" "profile-status-e2e.sh";
      profileStatusRepeat = mkTest "test-chrome-service-profile-status-repeat-e2e" "profile-status-repeat-e2e.sh";
      probePolicy = mkTest "test-chrome-service-probe-policy-e2e" "probe-policy-e2e.sh";
      runtime = mkTest "test-chrome-service-runtime-e2e" "runtime-e2e.sh";
      authState = mkTest "test-chrome-service-auth-state-e2e" "auth-state-e2e.sh";
      recoverGate = mkTest "test-chrome-service-recover-gate-e2e" "recover-gate-e2e.sh";
      singleSessionGuard = mkTest "test-chrome-service-single-session-guard-e2e" "single-session-guard-e2e.sh";
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

      apps.test-chrome-service-profile-publish-e2e = {
        type = "app";
        program = "${profilePublish}/bin/test-chrome-service-profile-publish-e2e";
        meta.description = "E2E coverage for seed-to-snapshot publish";
      };

      apps.test-chrome-service-profile-bootstrap-smoke-e2e = {
        type = "app";
        program = "${profileBootstrap}/bin/test-chrome-service-profile-bootstrap-smoke-e2e";
        meta.description = "Smoke coverage for transient headful bootstrap";
      };

      apps.test-chrome-service-profile-status-e2e = {
        type = "app";
        program = "${profileStatus}/bin/test-chrome-service-profile-status-e2e";
        meta.description = "E2E coverage for published snapshot status";
      };

      apps.test-chrome-service-profile-status-repeat-e2e = {
        type = "app";
        program = "${profileStatusRepeat}/bin/test-chrome-service-profile-status-repeat-e2e";
        meta.description = "E2E coverage for repeated published snapshot reuse";
      };

      apps.test-chrome-service-probe-policy-e2e = {
        type = "app";
        program = "${probePolicy}/bin/test-chrome-service-probe-policy-e2e";
        meta.description = "E2E coverage for probe stratification and cooldown";
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

      apps.test-chrome-service-single-session-guard-e2e = {
        type = "app";
        program = "${singleSessionGuard}/bin/test-chrome-service-single-session-guard-e2e";
        meta.description = "E2E coverage for single-session automation guard";
      };

      packages.test-chrome-service-profile-sync-e2e = profileSync;
      packages.test-chrome-service-profile-bootstrap-smoke-e2e = profileBootstrap;
      packages.test-chrome-service-profile-publish-e2e = profilePublish;
      packages.test-chrome-service-profile-status-e2e = profileStatus;
      packages.test-chrome-service-profile-status-repeat-e2e = profileStatusRepeat;
      packages.test-chrome-service-probe-policy-e2e = probePolicy;
      packages.test-chrome-service-runtime-e2e = runtime;
      packages.test-chrome-service-auth-state-e2e = authState;
      packages.test-chrome-service-recover-gate-e2e = recoverGate;
      packages.test-chrome-service-single-session-guard-e2e = singleSessionGuard;
      packages.test-chrome-service-systemd-user-e2e = systemdUser;
    };
}
