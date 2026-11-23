# Shell macOS Tahoe (Quickshell) : installé dans ~/.config/quickshell/macos et lancé
# par le service systemd utilisateur « macos-shell » avec la session Hyprland.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  macosPkgs = import ./pkgs {inherit pkgs inputs;};

  # Outils appelés par le shell (Process / execDetached) et par les raccourcis
  runtimeDeps = with pkgs; [
    quickshell
    hyprland
    bash
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    procps
    util-linux
    systemd
    glib # gio (corbeille, ouverture)
    grim
    slurp
    wl-clipboard
    cliphist
    brightnessctl
    wireplumber
    pipewire
    playerctl
    fd
    libnotify
    xdg-utils
    jq
    networkmanager
    bluez
    power-profiles-daemon
    dconf
    wf-recorder # enregistrement d'écran (barre de capture Cmd+Maj+5)
    hyprsunset # Night Shift (Control Center > Écran)
    macosPkgs.macos-screenshot
    macosPkgs.macos-wm
    macosPkgs.macos-appearance
    # « Réglages… » du Control Center / « À propos de ce Mac » : gnome-control-center
    # lancé hors GNOME (et wdisplays pour les écrans)
    macosPkgs.macos-settings
  ];
  # Les apps lancées depuis le Dock/Spotlight héritent de ce PATH : on garde
  # ensuite les profils utilisateur et système.
  servicePath =
    lib.makeBinPath runtimeDeps
    + ":/run/wrappers/bin:/etc/profiles/per-user/${config.home.username}/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin";
in {
  # macos-settings : entrée « Réglages » dans Spotlight / Applications
  home.packages = [pkgs.quickshell macosPkgs.macos-settings pkgs.wf-recorder pkgs.hyprsunset];

  # Fichiers QML liés un à un (recursive) : le dossier reste inscriptible pour
  # settings.json et les fichiers d'état éventuels du shell.
  xdg.configFile."quickshell/macos" = {
    source = ./shell;
    recursive = true;
  };

  systemd.user.services.macos-shell = {
    Unit = {
      Description = "Shell macOS Tahoe (Quickshell)";
      Documentation = ["https://quickshell.org/docs/"];
      PartOf = ["hyprland-session.target"];
      After = ["hyprland-session.target"];
      # Redémarre le shell quand ses fichiers changent (home-manager switch)
      X-Restart-Triggers = ["${./shell}"];
    };
    Service = {
      Type = "exec";
      ExecStart = "${pkgs.quickshell}/bin/quickshell -c macos";
      Restart = "on-failure";
      RestartSec = 1;
      # Les apps lancées par le shell ne doivent pas mourir s'il redémarre
      KillMode = "process";
      Environment = [
        "PATH=${servicePath}"
        "QS_ICON_THEME=MacTahoe-Apple-dark"
        "QT_QPA_PLATFORM=wayland"
        "QT_QUICK_CONTROLS_STYLE=Basic"
        "QS_NO_RELOAD_POPUP=1"
      ];
    };
    Install.WantedBy = ["hyprland-session.target"];
  };
}
