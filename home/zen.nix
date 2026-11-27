# Sine (moteur de mods Zen) + mods installés, déployés dans chaque profil Zen.
#
# Le bootloader Sine (config.js) est dans le paquet, cf. modules/zen-browser.nix ;
# le reste vit dans <profil>/chrome : moteur (JS/, utils/) et mods (sine-mods/).
# home/zen-chrome/ est un instantané de ce dossier (moteur 2.3.4.1c), copié
# sans jamais écraser : Sine doit pouvoir y écrire (mises à jour, mods ajoutés
# depuis son marketplace), donc pas de lien vers le store.
# chrome.css / content.css de Sine contiennent le chemin absolu du profil :
# @CHROME_URL@ y est remplacé par celui du profil cible.
{
  lib,
  pkgs,
  ...
}: let
  chrome = ./zen-chrome;
in {
  home.activation.zenSine = lib.hm.dag.entryAfter ["writeBoundary"] ''
    for root in "$HOME/.config/zen" "$HOME/.zen"; do
      ini="$root/profiles.ini"
      [ -f "$ini" ] || continue
      ${pkgs.gnugrep}/bin/grep '^Path=' "$ini" | ${pkgs.coreutils}/bin/cut -d= -f2- | while IFS= read -r rel; do
        prof="$root/$rel"
        case "$rel" in /*) prof="$rel" ;; esac
        [ -d "$prof" ] || continue
        dst="$prof/chrome"
        fresh=0
        [ -e "$dst/sine-mods/chrome.css" ] || fresh=1
        run ${pkgs.coreutils}/bin/mkdir -p "$dst"
        run ${pkgs.coreutils}/bin/cp -r --update=none --no-preserve=mode,ownership \
          ${chrome}/JS ${chrome}/utils ${chrome}/sine-mods "$dst/"
        if [ "$fresh" = 1 ]; then
          url="file://$(printf '%s' "$dst" | ${pkgs.gnused}/bin/sed 's/ /%20/g')"
          run ${pkgs.gnused}/bin/sed -i "s#@CHROME_URL@#$url#g" \
            "$dst/sine-mods/chrome.css" "$dst/sine-mods/content.css"
        fi
      done
    done
  '';
}
