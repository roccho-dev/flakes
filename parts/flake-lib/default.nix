{ ... }:
{
  flake.lib = {
    mkLazygitDelta = import ../lazygit-delta/module.nix;
    chromedevtoolprotocolService = import ../chrome/lib.nix;
  };
}