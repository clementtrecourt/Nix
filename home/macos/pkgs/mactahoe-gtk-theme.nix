# Thème GTK MacTahoe (vinceliuice) : GTK 2/3/4 (+ CSS libadwaita via gtk-4.0),
# variantes MacTahoe-Light / MacTahoe-Dark, accent bleu par défaut (façon Tahoe).
# Compilé depuis les sources (sassc) avec le script upstream, comme whitesur-gtk-theme.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  glib,
  gnome-themes-extra,
  jdupes,
  libxml2,
  sassc,
  util-linux,
  # light / dark
  colorVariants ? ["light" "dark"],
  # normal (translucide) / solid
  opacityVariants ? ["normal"],
  # default = accent bleu Tahoe ; blue, purple, pink, red, orange, yellow, green, grey, all
  themeVariants ? ["default"],
  roundedMaxWindow ? true,
}:
stdenvNoCC.mkDerivation {
  pname = "mactahoe-gtk-theme";
  version = "0-unstable-2026-09-28";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "MacTahoe-gtk-theme";
    rev = "1e45e19f510edb8cde18fa84d6cd5319f60b086b";
    hash = "sha256-6a42HU49N4ChSm4AyW7i6FYAIENZzDogpZzM51muCbg=";
  };

  nativeBuildInputs = [glib jdupes libxml2 sassc util-linux];
  buildInputs = [gnome-themes-extra]; # moteur adwaita pour GTK2

  postPatch = ''
    find -name "*.sh" -print0 | while IFS= read -r -d ''' file; do
      patchShebangs "$file"
    done
    # Pas de sudo ni de vrai $HOME dans le bac à sable
    substituteInPlace libs/lib-core.sh \
      --replace-fail 'MY_HOME=$(getent passwd "''${MY_USERNAME}" | cut -d: -f6)' 'MY_HOME=/tmp' \
      --replace-fail 'SUDO_BIN="$(command -v sudo)"' 'SUDO_BIN=""'
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    export HOME=$TMPDIR
    mkdir -p $out/share/themes
    ./install.sh \
      ${toString (map (x: "--color " + x) colorVariants)} \
      ${toString (map (x: "--opacity " + x) opacityVariants)} \
      ${toString (map (x: "--theme " + x) themeVariants)} \
      ${lib.optionalString roundedMaxWindow "--roundedmaxwindow"} \
      --dest $out/share/themes
    jdupes --quiet --link-soft --recurse $out/share
    runHook postInstall
  '';

  meta = {
    description = "Thème GTK façon macOS Tahoe";
    homepage = "https://github.com/vinceliuice/MacTahoe-gtk-theme";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
