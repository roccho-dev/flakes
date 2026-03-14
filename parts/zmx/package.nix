{ lib
, stdenvNoCC
, fetchurl
, autoPatchelfHook
}:

stdenvNoCC.mkDerivation {
  pname = "zmx";
  version = "0.2.0";

  src = fetchurl {
    url = "https://zmx.sh/a/zmx-0.2.0-linux-x86_64.tar.gz";
    hash = "sha256-PaclWOgQYQmxz1tH+wUiVJr8DkvhyrUxhXqORZB97uo=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  unpackPhase = ''
    tar -xzf "$src"
  '';

  installPhase = ''
    mkdir -p "$out/bin"
    ZMX_BIN="$(find . -maxdepth 4 -type f -name zmx -perm -u+x | head -n1)"
    if [ -z "$ZMX_BIN" ]; then
      echo "zmx binary not found in tarball" >&2
      exit 1
    fi
    install -m755 "$ZMX_BIN" "$out/bin/zmx"
  '';

  meta = with lib; {
    description = "zmx (pinned upstream tarball)";
    platforms = [ "x86_64-linux" ];
  };
}
