let
  sddm-noctalia = pkgs.stdenv.mkDerivation {
    pname = "sddm-noctalia";
    version = "unstable-2026-04";
    src = pkgs.fetchFromGitHub {
      owner = "Vorxiu";
      repo = "sddm-noctalia";
      rev = "0e57100";
      hash = pkgs.lib.fakeHash; # remplace par le vrai hash donné à l'échec du build
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/sddm/themes/sddm-noctalia
      cp -r $src/* $out/share/sddm/themes/sddm-noctalia/
    '';
  };
in
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true; # nécessaire pour lancer mango en Wayland depuis SDDM
    theme = "sddm-noctalia";
    extraPackages = with pkgs.qt6Packages; [ qt5compat qtdeclarative ];
  };

  environment.systemPackages = [ sddm-noctalia ];
}
