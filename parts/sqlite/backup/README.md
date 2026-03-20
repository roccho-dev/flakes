# SQLite Backup (Home Manager)

This module creates SQLite-consistent snapshots (capture), validates them, and applies basic retention.

## Usage

```nix
{
  imports = [ ../sqlite/backup/hm.nix ];

  sqlite.backup.jobs.opencode = {
    enable = true;
    dbPath = "/home/nixos/.local/share/opencode/opencode.db";

    # Optional
    # destDir = "/home/nixos/.local/state/sqlite-backup/opencode";
    # schedule = "daily";
    # keep = 7;
    # method = "backup-api"; # or "vacuum-into"
    # validateMode = "quick"; # or "integrity"
  };
}
```

## Restore

Stop the writer, replace `opencode.db`, remove `-wal/-shm`, then start the writer again.
