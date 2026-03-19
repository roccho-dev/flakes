{ ... }:
{
  imports = [
    ./upstream.nix
    ./opencode/default.nix
    ./qjs.zig/default.nix
    ./chromedevtoolprotocol.zig/default.nix
    ./hq.zig/default.nix
    ./os/default.nix
    ./cdp/default.nix
    ./user/default.nix
  ];
}
