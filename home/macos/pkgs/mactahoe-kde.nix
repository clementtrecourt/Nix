# Ressources Qt/KDE MacTahoe (vinceliuice/MacTahoe-kde) : thème Kvantum
# (MacTahoe clair, MacTahoeDark sombre), schémas de couleurs KDE et fonds d'écran Tahoe 4K.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "mactahoe-kde";
  version = "0-unstable-2026-08-16";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "MacTahoe-kde";
    rev = "cbf6a1f71b591d143184855d62f6272ce533e7c3";
    hash = "sha256-atdHgr9pCfg/VE8GGWF+4MZu6nRmVCz9TiylVATAwzs=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/Kvantum $out/share/color-schemes $out/share/wallpapers $out/share/backgrounds/MacTahoe
    cp -r Kvantum/MacTahoe $out/share/Kvantum/
    # Kvantum cherche <dossier>/<dossier>.kvconfig : on expose aussi la variante sombre seule
    mkdir -p $out/share/Kvantum/MacTahoeDark
    ln -s ../MacTahoe/MacTahoeDark.kvconfig $out/share/Kvantum/MacTahoeDark/MacTahoeDark.kvconfig
    ln -s ../MacTahoe/MacTahoeDark.svg $out/share/Kvantum/MacTahoeDark/MacTahoeDark.svg
    cp color-schemes/*.colors $out/share/color-schemes/
    cp -r wallpapers/* $out/share/wallpapers/
    # Fonds d'écran Tahoe à plat (jour / nuit) pour le shell
    ln -s $out/share/wallpapers/MacTahoe/contents/images/3840x2160.jpeg $out/share/backgrounds/MacTahoe/MacTahoe-day.jpeg
    ln -s $out/share/wallpapers/MacTahoe/contents/images_dark/3840x2160.jpeg $out/share/backgrounds/MacTahoe/MacTahoe-night.jpeg
    runHook postInstall
  '';

  meta = {
    description = "Thème Kvantum, schémas de couleurs et fonds d'écran MacTahoe";
    homepage = "https://github.com/vinceliuice/MacTahoe-kde";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
