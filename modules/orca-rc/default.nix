# Orca (stablyai/orca), canal RC = bêta : AppImage officielle.
# Version épinglée dans source.json, mise à jour par update.sh (lancé par nrs) :
# chaque rebuild récupère la plus récente version publiée, RC ou stable.
# Commande : orca-ide (le nom "orca" est celui du lecteur d'écran GNOME).
{
  pkgs,
  lib,
  ...
}: let
  source = lib.importJSON ./source.json;
  pname = "orca-ide";
  inherit (source) version;

  src = pkgs.fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    inherit (source) hash;
  };

  contents = pkgs.appimageTools.extract {inherit pname version src;};
in
  pkgs.appimageTools.wrapType2 {
    inherit pname version src;

    # Pas d'auto-mise à jour interne (APPIMAGE n'est pas défini une fois extraite) :
    # la version suit source.json.
    extraInstallCommands = ''
      install -Dm444 ${contents}/orca-ide.desktop $out/share/applications/orca-ide.desktop
      substituteInPlace $out/share/applications/orca-ide.desktop \
        --replace-fail "Exec=AppRun" "Exec=${pname}"
      cp -r ${contents}/usr/share/icons $out/share/icons
      chmod -R u+w $out/share/icons
    '';

    meta = {
      description = "Orca (canal RC) : orchestrateur d'agents de code en parallèle";
      homepage = "https://orca.dev";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux"];
      mainProgram = "orca-ide";
    };
  }
