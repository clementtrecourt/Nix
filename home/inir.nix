# iNiR (https://github.com/snowarch/iNiR) : barre, launcher, notifications,
# fonds d'écran, thème Material généré depuis le fond d'écran.
# - Démarre via le service utilisateur inir.service (avec niri.service).
# - Config niri : home/niri.nix. Partie système (groupes, ydotool...) : modules/inir.nix.
# - Au premier démarrage, iNiR lance son installateur, qui écrit dans ~/.config
#   (gtk, kdeglobals, Kvantum, qt5ct, starship, foot...) et sauvegarde ce qu'il
#   remplace dans ~/inir-backup. Il ne touche pas aux fichiers gérés par Home Manager.
# - Réglages iNiR : ~/.config/inir (local à chaque machine, non versionné).
_: {
  programs.inir.enable = true;
}
