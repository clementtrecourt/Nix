{
  appimageTools,
  fetchurl,
}: let
  pname = "t3code";
  version = "0.1.10-nightly.20261116.4774";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-Nightly-x86_64.AppImage";
    hash = "sha256-3xrshJYfoS3/x9TLcYhSxSCV5ODi6XMaLg3m0+OBkeU=";
  };
  contents = appimageTools.extract {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;
    extraInstallCommands = ''
      install -Dm444 ${contents}/*.desktop -t $out/share/applications || true
      substituteInPlace $out/share/applications/*.desktop --replace-quiet "Exec=AppRun" "Exec=${pname}" || true
      cp -r ${contents}/usr/share/icons $out/share/ 2>/dev/null || true
    '';
  }
