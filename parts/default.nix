{ ... }:
{
  imports = [
    ./upstream.nix
    ./opencode/default.nix
    ./nemo/default.nix
    ./local/default.nix
  ];
}
