#!/bin/bash
function build_home_by_nix() {
  nix build .#homeConfigurations.rocchoHome.activationPackage
}
