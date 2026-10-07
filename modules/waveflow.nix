{
  pkgs,
  lib,
  ...
}: let
  pname = "waveflow";
  version = "1.8.3";

  src = pkgs.fetchurl {
    url = "https://github.com/InstaZDLL/WaveFlow/releases/download/v${version}/WaveFlow-${version}-x86_64.AppImage";
    hash = "sha256-rOpIPiIpYUt+JbLRzOiHD2gc8ZrLP0B/by3RDLIlP1g=";
  };

  appimageContents = pkgs.appimageTools.extractType2 {
    inherit pname version src;
  };
in
  pkgs.appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      install -Dm644 \
        ${appimageContents}/usr/share/applications/*.desktop \
        $out/share/applications/waveflow.desktop
    '';

    meta = {
      description = "Local-first music player";
      homepage = "https://github.com/InstaZDLL/WaveFlow";
      license = lib.licenses.gpl3Only;
      platforms = ["x86_64-linux"];
      mainProgram = "waveflow";
    };
  }
