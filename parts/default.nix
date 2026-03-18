{ ... }:
{
  imports = [
    ./upstream.nix
    ./opencode/default.nix
    ./local/default.nix
    ./qjs.zig/default.nix
    ./os/default.nix
    ./chromedevtoolprotocol/default.nix
    ./user/default.nix
  ];
}
