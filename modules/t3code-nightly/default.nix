# T3 Code, canal Nightly (AppImage officielle de pingdotgg/t3code).
# Version épinglée dans source.json, mise à jour par update.sh (lancé par nrs) :
# chaque rebuild récupère la dernière nightly publiée.
{
  pkgs,
  lib,
  ...
}: let
  source = lib.importJSON ./source.json;
  pname = "t3code-nightly";
  inherit (source) version;

  src = pkgs.fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-Nightly-x86_64.AppImage";
    inherit (source) hash;
  };

  contents = pkgs.appimageTools.extract {inherit pname version src;};
in
  pkgs.appimageTools.wrapType2 {
    inherit pname version src;

    # Pas d'auto-mise à jour interne (APPIMAGE n'est pas défini une fois extraite) :
    # la nightly suit source.json.
    extraInstallCommands = ''
      ln -s $out/bin/${pname} $out/bin/t3code
      install -Dm444 ${contents}/t3code.desktop $out/share/applications/t3code.desktop
      substituteInPlace $out/share/applications/t3code.desktop \
        --replace-fail "Exec=AppRun" "Exec=${pname}"
      cp -r ${contents}/usr/share/icons $out/share/icons
      chmod -R u+w $out/share/icons
    '';

    meta = {
      description = "T3 Code (Nightly) : interface graphique pour agents de code";
      homepage = "https://t3.codes";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux"];
      mainProgram = "t3code";
    };
  }
