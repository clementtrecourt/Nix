# Réglages Système façon macOS Tahoe : dessinés par le shell Quickshell
# (shell/settings), ouverts par l'IPC « settings » ou `macos-settings [panneau]`
# (paquet macos-settings, installé par shell.nix). Ce module fournit les outils
# que l'app appelle.
{pkgs, ...}: {
  home.packages = with pkgs; [
    zenity # sélecteurs de fichiers : Wallpaper > Add Photo…, photo du compte
    sound-theme-freedesktop # sons d'alerte (Sound > Alert sound)
    xdg-utils # navigateur web par défaut (Desktop & Dock)
  ];
}
