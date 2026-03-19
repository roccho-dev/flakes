{ ... }:
{
  imports = [
    ./upstream.nix
    ./opencode/default.nix
    ./qjs.zig/default.nix
    ./chromedevtoolprotocol/default.nix
  ];
}
