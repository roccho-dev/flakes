{
  lib,
  buildNpmPackage,
  fetchurl,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  ripgrep,
  runCommand,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;

  srcWithLock = runCommand "amp-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@sourcegraph/amp/-/amp-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage rec {
  inherit npmConfigHook;
  pname = "amp";
  inherit version;

  src = srcWithLock;

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "${pname}-${version}-npm-deps";
    hash = versionData.npmDepsHash;
    fetcherVersion = 2;
  };

  makeCacheWritable = true;
  dontNpmBuild = true;

  postInstall = ''
    wrapProgram $out/bin/amp       --prefix PATH : ${lib.makeBinPath [ ripgrep ]}       --set AMP_SKIP_UPDATE_CHECK 1
  '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "CLI for Amp, an agentic coding tool in research preview from Sourcegraph";
    homepage = "https://ampcode.com/";
    changelog = "https://ampcode.com/changelog";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = [ ];
    platforms = platforms.all;
    mainProgram = "amp";
  };
}
