{
  description = "Local wrapper for roccho-dev/flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Poetry 1.8.x is required for some repos (e.g. app_toyhobby).
    nixpkgs-poetry.url = "github:NixOS/nixpkgs/nixos-24.11";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    upstream = {
      url = "github:roccho-dev/flakes";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        ./parts/default.nix

        ./parts/packages.nix
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
