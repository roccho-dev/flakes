{
  description = "Local wrapper for roccho-dev/flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Poetry 1.8.x is required for some repos (e.g. app_toyhobby).
    nixpkgs-poetry.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        ./parts/upstream.nix
        ./parts/packages.nix
        ./parts/home-manager.nix
        ./parts/opencode/default.nix
        ./parts/helix/default.nix
        ./parts/lazygit-delta/default.nix
        ./parts/chrome/default.nix
        ./parts/cdp/default.nix
        ./parts/chromedevtoolprotocol.zig/default.nix
        ./parts/hq.zig/default.nix
        ./parts/qjs.zig/default.nix
        ./parts/languages/default.nix
        ./parts/repo-checks.nix
        ./parts/tests/apps.nix
        ./parts/tests/help-app.nix
        ./parts/tests/lazygit-delta-test.nix
        ./parts/tests/chrome-service-e2e.nix
        ./parts/tests/sqlite-backup-backup-api.nix
        ./parts/tests/sqlite-backup-vacuum-into.nix
        ./parts/tests/sqlite-backup-restore.nix
      ];
    };
}
