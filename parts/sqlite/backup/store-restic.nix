{ pkgs, lib }:

# Optional off-host storage layer (not wired by default).
# Intentionally minimal until a repo/password policy is fixed.
{
  mkSnippet =
    { repo
    , passwordFile
    , snapshotPath
    , tags ? [ ]
    }:
    let
      tagArgs = lib.concatMapStringsSep " " (t: "--tag ${lib.escapeShellArg t}") tags;
    in
    ''
      "${pkgs.restic}/bin/restic" -r ${lib.escapeShellArg repo} --password-file ${lib.escapeShellArg passwordFile} \
        backup ${lib.escapeShellArg snapshotPath} ${tagArgs}
    '';
}
