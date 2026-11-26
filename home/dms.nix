# DMS (Dux/Dank Material Shell) en mode "dynamic island", d'après
# r/unixporn "[NiRi] Dank Material Shell | Dynamic island" (u/Lowpoly_AXL, DMS stock).
#
# - Le shell démarre via systemd (graphical-session.target, lancé par niri-session).
# - La config DMS est PARTAGÉE entre home et work : elle vit dans ce dépôt
#   (home/dms/) et ~/.config/dms/<fichier> est un lien vers ~/Nix/home/dms/<fichier>
#   (lien hors store, donc toujours modifiable depuis les Réglages DMS : DMS écrit
#   à travers le lien, directement dans le dépôt).
#   Un changement fait à la souris sur une machine -> `nrs` (commit + push) ;
#   sur l'autre machine -> `git pull` dans ~/Nix, puis DMS recharge tout seul.
# - Reste local à chaque machine (volontairement) : ~/.local/state/dms/session.json
#   (fond d'écran, positions des widgets par écran, historique du launcher).
{
  config,
  pkgs,
  inputs,
  ...
}: let
  # Dépôt Nix : même chemin sur les deux machines (cf. alias nrs / dmsu)
  repo = "${config.home.homeDirectory}/Nix";
  shared = path: config.lib.file.mkOutOfStoreSymlink "${repo}/home/dms/${path}";
in {
  programs.dank-material-shell = {
    enable = true;
    # Paquet construit par le flake DMS (son nixpkgs a le Go requis)
    package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell;
    systemd.enable = true;
    enableAudioWavelength = true; # cava : visualiseur audio (île média + widget bureau)
    enableDynamicTheming = true; # matugen : thèmes GTK/Qt/kitty générés depuis le thème DMS
    enableCalendarEvents = false;
  };

  xdg.configFile = {
    "dms/settings.json".source = shared "settings.json";
    "dms/plugin_settings.json".source = shared "plugin_settings.json";
    "dms/themes".source = shared "themes";
  };
}
