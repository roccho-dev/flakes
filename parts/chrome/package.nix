{ pkgs }:
let
  contract = import ./lib.nix;

  profileSync = pkgs.writeShellApplication {
    name = "chromedevtoolprotocol-service-profile-sync";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      util-linux
    ];
    text = builtins.readFile ./bin/chromedevtoolprotocol-service-profile-sync;
  };

  service = pkgs.writeShellApplication {
    name = contract.serviceName;
    runtimeInputs = with pkgs; [
      chromium
      coreutils
      profileSync
    ];
    text = builtins.readFile ./bin/chromedevtoolprotocol-service;
  };

  health = pkgs.writeShellApplication {
    name = "chromedevtoolprotocol-service-health";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
      procps
      util-linux
    ];
    text = builtins.readFile ./bin/chromedevtoolprotocol-service-health;
  };

  recover = pkgs.writeShellApplication {
    name = "chromedevtoolprotocol-service-recover";
    runtimeInputs = with pkgs; [
      coreutils
      health
      jq
    ];
    text = builtins.readFile ./bin/chromedevtoolprotocol-service-recover;
  };
in
rec {
  inherit health profileSync recover service;

  suite = pkgs.symlinkJoin {
    name = "${contract.serviceName}-suite";
    paths = [
      service
      health
      profileSync
      recover
    ];
  };
}
