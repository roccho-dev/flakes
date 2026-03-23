{ callPackage, ... }:
let
  npmPackumentSupport = callPackage ../../lib/fetch-npm-deps.nix { };
in
callPackage ./package.nix {
  inherit (npmPackumentSupport) fetchNpmDepsWithPackuments npmConfigHook;
}
