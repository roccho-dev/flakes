{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.chromedevtoolprotocol-service-contract = pkgs.runCommand "chromedevtoolprotocol-service-contract" {
        nativeBuildInputs = [ pkgs.jq ];
      } ''
        jq -e '.schema_version == 1' ${./config/health.json} > /dev/null
        jq -e '.probe_stratification.systemd_timer_scope == "core"' ${./config/health.json} > /dev/null
        jq -e '.cooldown.login_required_seconds == 300' ${./config/health.json} > /dev/null
        jq -e '.cooldown.challenge_blocked_seconds == 3600' ${./config/health.json} > /dev/null
        jq -e '.probe_failed_requires_reason_code == true' ${./config/health.json} > /dev/null
        jq -e '.systemd_green_source == "core.status"' ${./config/health.json} > /dev/null

        jq -e '.source_profile_kind == "snapshot"' ${./config/profile.json} > /dev/null
        jq -e '.seed_profile_kind == "automation-headful-seed"' ${./config/profile.json} > /dev/null
        jq -e '.published_snapshot_kind == "published-auth-snapshot"' ${./config/profile.json} > /dev/null
        jq -e '.runtime_profile_kind == "service-runtime-copy"' ${./config/profile.json} > /dev/null
        jq -e '.direct_reuse == "forbidden"' ${./config/profile.json} > /dev/null
        jq -e '.sync_mode == "fresh-copy"' ${./config/profile.json} > /dev/null
        jq -e '.bootstrap_mode == "manual-login-in-browser"' ${./config/profile.json} > /dev/null
        jq -e '.runtime_promote_to_snapshot == false' ${./config/profile.json} > /dev/null

        jq -e '.headless_baseline == true' ${./config/launch.json} > /dev/null
        jq -e '.remote_debugging_address == "127.0.0.1"' ${./config/launch.json} > /dev/null
        jq -e '.password_store == "basic"' ${./config/launch.json} > /dev/null
        jq -e '.disable_automation_controlled == true' ${./config/launch.json} > /dev/null
        jq -e '.spoof_user_agent == true' ${./config/launch.json} > /dev/null

        jq -e '.automatic == false' ${./config/recovery.json} > /dev/null
        jq -e '.requires_opt_in == true' ${./config/recovery.json} > /dev/null

        touch "$out"
      '';
    };
}
