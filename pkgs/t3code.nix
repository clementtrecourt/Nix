{
  appimageTools,
  fetchurl,
}: let
  pname = "t3code";
  version = "0.1.9";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
    hash = "sha256-0KtW3z4zjyQoSENWISl/2WOjNxWw2CCNvwg5lllXLYE=";
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
