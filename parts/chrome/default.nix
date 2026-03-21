{ ... }:
{
  imports = [
    ./checks.nix
  ];

  perSystem =
    { pkgs, config, ... }:
    let
      mod = import ./package.nix {
        inherit pkgs;
        cdpBridge = config.packages.cdp-bridge;
      };
    in
    {
      packages.chromedevtoolprotocol-service = mod.service;
      packages.chromedevtoolprotocol-service-health = mod.health;
      packages.chromedevtoolprotocol-service-profile-bootstrap = mod.profileBootstrap;
      packages.chromedevtoolprotocol-service-profile-publish = mod.profilePublish;
      packages.chromedevtoolprotocol-service-profile-status = mod.profileStatus;
      packages.chromedevtoolprotocol-service-profile-sync = mod.profileSync;
      packages.chromedevtoolprotocol-service-recover = mod.recover;
      packages.chromedevtoolprotocol-service-suite = mod.suite;

      apps.chromedevtoolprotocol-service = {
        type = "app";
        program = "${mod.service}/bin/chromedevtoolprotocol-service";
      };
      apps.chromedevtoolprotocol-service-health = {
        type = "app";
        program = "${mod.health}/bin/chromedevtoolprotocol-service-health";
      };
      apps.chromedevtoolprotocol-service-profile-bootstrap = {
        type = "app";
        program = "${mod.profileBootstrap}/bin/chromedevtoolprotocol-service-profile-bootstrap";
      };
      apps.chromedevtoolprotocol-service-profile-publish = {
        type = "app";
        program = "${mod.profilePublish}/bin/chromedevtoolprotocol-service-profile-publish";
      };
      apps.chromedevtoolprotocol-service-profile-status = {
        type = "app";
        program = "${mod.profileStatus}/bin/chromedevtoolprotocol-service-profile-status";
      };
      apps.chromedevtoolprotocol-service-profile-sync = {
        type = "app";
        program = "${mod.profileSync}/bin/chromedevtoolprotocol-service-profile-sync";
      };
      apps.chromedevtoolprotocol-service-recover = {
        type = "app";
        program = "${mod.recover}/bin/chromedevtoolprotocol-service-recover";
      };
    };

  flake.lib.chromedevtoolprotocolService = import ./lib.nix;
}
