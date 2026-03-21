{ pkgs, ... }:
let
  mod = import ./package.nix { inherit pkgs; };

  commonEnvironment = [
    "HOME=/home/nixos"
    "XDG_CONFIG_HOME=/home/nixos/.config"
    "XDG_CACHE_HOME=/home/nixos/.cache"
    "XDG_DATA_HOME=/home/nixos/.local/share"
    "XDG_STATE_HOME=/home/nixos/.local/state"
    "CHROME_SERVICE_ADDR=127.0.0.1"
    "CHROME_SERVICE_PORT=9222"
    "CHROME_SERVICE_SEED_PROFILE=/home/nixos/.secret/hq/chromium-cdp-profile-140"
    "CHROME_SERVICE_PUBLISHED_SNAPSHOT=/home/nixos/.secret/hq/chromium-cdp-profile.snapshot"
    "CHROME_SERVICE_SOURCE_PROFILE=/home/nixos/.secret/hq/chromium-cdp-profile.snapshot"
    "CHROME_SERVICE_APP_MATCH=https://chatgpt.com"
    "CHROME_SERVICE_START_URL=about:blank"
    "CHROME_SERVICE_BOOTSTRAP_URL=https://chatgpt.com"
    "CHROME_SERVICE_BOOTSTRAP_PORT=9226"
    "CHROME_SERVICE_BOOTSTRAP_VNC_PORT=5902"
    "CHROME_SERVICE_BOOTSTRAP_DISPLAY=:98"
    "CHROME_SERVICE_HEADLESS=1"
    "CHROME_SERVICE_ALLOW_RECOVER=0"
    "CHROME_SERVICE_PASSWORD_STORE=basic"
    "CHROME_SERVICE_DISABLE_AUTOMATION=1"
    "CHROME_SERVICE_SPOOF_USER_AGENT=1"
    "CHROME_SERVICE_HEALTH_SCOPE=app"
    "CHROME_SERVICE_APP_LOGIN_COOLDOWN_SEC=300"
    "CHROME_SERVICE_APP_CHALLENGE_COOLDOWN_SEC=3600"
  ];

  coreHealthEnvironment = commonEnvironment ++ [ "CHROME_SERVICE_HEALTH_SCOPE=core" ];

  cleanupPid = pkgs.writeShellScript "chromedevtoolprotocol-service-cleanup-pid" ''
    set -euo pipefail
    : "''${XDG_STATE_HOME:=$HOME/.local/state}"
    rm -f "$XDG_STATE_HOME/chromedevtoolprotocol-service/service.pid"
  '';
in
{
  xdg.configFile."chromedevtoolprotocol-service/health.json".source = ./config/health.json;
  xdg.configFile."chromedevtoolprotocol-service/profile.json".source = ./config/profile.json;
  xdg.configFile."chromedevtoolprotocol-service/launch.json".source = ./config/launch.json;
  xdg.configFile."chromedevtoolprotocol-service/recovery.json".source = ./config/recovery.json;

  systemd.user.services.chromedevtoolprotocol-service = {
    Unit = {
      Description = "Chrome CDP runtime service";
      After = [ "default.target" ];
      StartLimitIntervalSec = 60;
      StartLimitBurst = 5;
    };

    Service = {
      Type = "simple";
      WorkingDirectory = "/home/nixos";
      ExecStartPre = "${mod.profileSync}/bin/chromedevtoolprotocol-service-profile-sync";
      ExecStart = "${mod.service}/bin/chromedevtoolprotocol-service";
      ExecStopPost = "${cleanupPid}";
      Restart = "on-failure";
      RestartSec = 2;
      KillMode = "control-group";
      Environment = commonEnvironment;
    };

    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.chromedevtoolprotocol-service-profile-sync = {
    Unit.Description = "Prepare copied Chrome runtime profile";

    Service = {
      Type = "oneshot";
      WorkingDirectory = "/home/nixos";
      ExecStart = "${mod.profileSync}/bin/chromedevtoolprotocol-service-profile-sync";
      Environment = commonEnvironment;
    };
  };

  systemd.user.services.chromedevtoolprotocol-service-health = {
    Unit.Description = "Probe Chrome CDP runtime health";

    Service = {
      Type = "oneshot";
      WorkingDirectory = "/home/nixos";
      ExecStart = "${mod.health}/bin/chromedevtoolprotocol-service-health";
      Environment = coreHealthEnvironment;
    };
  };

  systemd.user.services.chromedevtoolprotocol-service-app-health = {
    Unit.Description = "Probe ChatGPT app readiness on the Chrome runtime";

    Service = {
      Type = "oneshot";
      WorkingDirectory = "/home/nixos";
      ExecStart = "${mod.health}/bin/chromedevtoolprotocol-service-health";
      Environment = commonEnvironment;
    };
  };

  systemd.user.services.chromedevtoolprotocol-service-recover = {
    Unit.Description = "Attempt Chrome CDP runtime recovery";

    Service = {
      Type = "oneshot";
      WorkingDirectory = "/home/nixos";
      ExecStart = "${mod.recover}/bin/chromedevtoolprotocol-service-recover";
      Environment = commonEnvironment;
    };
  };

  systemd.user.timers.chromedevtoolprotocol-service-health = {
    Unit.Description = "Periodic Chrome CDP runtime health probe";

    Timer = {
      OnBootSec = "30s";
      OnUnitActiveSec = "60s";
      Unit = "chromedevtoolprotocol-service-health.service";
    };

    Install.WantedBy = [ "timers.target" ];
  };
}
