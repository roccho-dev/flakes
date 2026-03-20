{ config, pkgs, lib, ... }:

let
  backupLib = import ./lib.nix { inherit lib pkgs; };
  systemdLib = import ./systemd-user.nix { inherit lib; };

  jobType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        enable = lib.mkEnableOption "sqlite backup job";

        dbPath = lib.mkOption {
          type = lib.types.str;
          description = "Path to the SQLite database file (runtime path, not a Nix store path).";
        };

        destDir = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Destination directory for snapshots.";
        };

        schedule = lib.mkOption {
          type = lib.types.str;
          default = "daily";
          description = "systemd OnCalendar value.";
        };

        persistent = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Run missed timers on next start.";
        };

        randomizedDelaySec = lib.mkOption {
          type = lib.types.str;
          default = "30m";
          description = "systemd RandomizedDelaySec.";
        };

        method = lib.mkOption {
          type = lib.types.enum [ "backup-api" "vacuum-into" ];
          default = "backup-api";
          description = "Capture method.";
        };

        validateMode = lib.mkOption {
          type = lib.types.enum [ "quick" "integrity" ];
          default = "quick";
          description = "Validation mode for the snapshot.";
        };

        keep = lib.mkOption {
          type = lib.types.ints.positive;
          default = 7;
          description = "Number of snapshots to keep.";
        };
      };
    }
  );

  jobsEnabled = lib.filterAttrs (_: v: v.enable) config.sqlite.backup.jobs;

  mkUnitName = name: "sqlite-backup-${name}";

  mkJob =
    name: job:
    let
      destDir =
        if job.destDir != null then
          job.destDir
        else
          "${config.home.homeDirectory}/.local/state/sqlite-backup/${name}";

      script = backupLib.mkBackupScript {
        inherit name;
        dbPath = job.dbPath;
        inherit destDir;
        method = job.method;
        keep = job.keep;
        validateMode = job.validateMode;
      };

      unitName = mkUnitName name;
    in
    {
      services.${unitName} = systemdLib.mkOneshotService {
        description = "SQLite backup: ${name}";
        script = script;
      };

      timers.${unitName} = systemdLib.mkTimer {
        description = "SQLite backup timer: ${name}";
        onCalendar = job.schedule;
        persistent = job.persistent;
        randomizedDelaySec = job.randomizedDelaySec;
      };
    };

  units = lib.foldl' lib.recursiveUpdate { services = { }; timers = { }; } (
    lib.mapAttrsToList mkJob jobsEnabled
  );

in
{
  options.sqlite.backup.jobs = lib.mkOption {
    type = lib.types.attrsOf jobType;
    default = { };
  };

  config = {
    systemd.user.services = units.services;
    systemd.user.timers = units.timers;
  };
}
