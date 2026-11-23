# Thème d'icônes MacTahoe (vinceliuice) : icônes d'applications "squircle" façon
# macOS Tahoe 26, pictos symboliques, variantes MacTahoe / MacTahoe-light / MacTahoe-dark.
# Le script upstream installe aussi le curseur MacTahoe dans chaque variante.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  gtk3,
  hicolor-icon-theme,
  jdupes,
  # Couleurs de dossiers : default (bleu Tahoe), purple, green, red, orange, yellow, grey, nord, all
  themeVariants ? ["default"],
  boldPanelIcons ? false,
}:
stdenvNoCC.mkDerivation {
  pname = "mactahoe-icon-theme";
  version = "0-unstable-2026-09-10";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "MacTahoe-icon-theme";
    rev = "839848b9a8a38a92a6936e30c4abe35cc6f2546d";
    hash = "sha256-NAahlBOYub0QlqkYStamoCbyWh+H5JG/iFm4Ws9EU3A=";
  };

  nativeBuildInputs = [gtk3 jdupes];
  propagatedBuildInputs = [hicolor-icon-theme];

  # Étapes de fixup lentes et inutiles pour un thème d'icônes
  dontPatchELF = true;
  dontRewriteSymlinks = true;
  dontDropIconThemeCache = true;

  postPatch = ''
    patchShebangs install.sh
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/icons
    ./install.sh --dest $out/share/icons --name MacTahoe \
      ${lib.optionalString boldPanelIcons "--bold"} \
      --theme ${toString themeVariants}
    jdupes --quiet --link-soft --recurse $out/share
    runHook postInstall
  '';

  # Supprime les liens symboliques orphelins du jeu d'icônes upstream
  postFixup = ''
    find $out/share/icons -xtype l -delete
  '';

  meta = {
    description = "Thème d'icônes façon macOS Tahoe pour Linux";
    homepage = "https://github.com/vinceliuice/MacTahoe-icon-theme";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
