{
  description = "run-anywhere edit shell + SSOT helix languages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        ./parts/packages/default.nix
        ./parts/local/default.nix
        ./parts/repo-checks.nix
        ./parts/tests/apps.nix
        ./parts/tests/help-app.nix
        ./parts/tests/lazygit-delta-test.nix

        ./parts/opencode/checks.nix

        ./parts/helix/contract.nix
        ./parts/helix/gen.nix
        ./parts/helix/checks.nix

        ./parts/languages/python.nix
        ./parts/languages/bun.nix
        ./parts/languages/rust.nix
        ./parts/languages/go.nix
        ./parts/languages/zig.nix
        ./parts/languages/nix.nix
        ./parts/languages/cue.nix
        ./parts/languages/contract.nix
      ];
    };
}
