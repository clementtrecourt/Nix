{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.inir.homeModules.inir
  ];

  # iNiR
  programs.inir = {
    enable = true;
    service.compositor = "niri";
    configSymlink.enable = true;
    extraPackages = [pkgs.niri];
  };

  # Clavier us_qwerty-fr
  xdg.configFile."xkb/symbols/us_qwerty-fr".source = "${inputs.qwerty-fr}/linux/us_qwerty-fr";

  # Configuration déclarative de Niri
  xdg.configFile."niri/config.kdl".text = ''
      input {
        keyboard {
          xkb {
            layout "us_qwerty-fr"
            variant "qwerty-fr"
          }
          repeat-delay 400
          repeat-rate 25
        }

        touchpad {
          tap
        }
      }

      output "eDP-1" {
        scale 1.0
      }

      environment {
        ELECTRON_OZONE_PLATFORM_HINT "auto"
      }

      layout {
        gaps 5
        center-focused-column "never"
        default-column-width { proportion 0.5; }

        focus-ring {
          width 2
          active-color "#7aa2f7"
          inactive-color "#24283b"
        }
      }

      prefer-no-csd

      // ============================================================
      // Règles de fenêtres
      // ============================================================

      window-rule {
        match app-id=r#"^zen"#
        open-on-workspace "1"
      }

      window-rule {
        match app-id="kitty"
        open-on-workspace "2"
      }

      // ============================================================
      // Raccourcis
      // ============================================================

      binds {

        // ------------------------------------------------------------
        // iNiR Shell
        // ------------------------------------------------------------

        Mod+A {
          spawn "inir" "overview" "toggle";
        }

        Mod+V {
          spawn "inir" "clipboard" "toggle";
        }

        Mod+Comma {
          spawn "inir" "settings";
        }

        Mod+Slash {
          spawn "inir" "cheatsheet" "toggle";
        }

        Mod+Shift+W {
          spawn "inir" "panelFamily" "cycle";
        }

        Mod+Alt+L {
          spawn "inir" "lock" "activate";
        }

        // Session / Power dialog
        Mod+Shift+Q {
          spawn "inir" "session" "toggle";
        }

        // Wallpaper selector
         Ctrl+Alt+T { spawn "inir" "wallpaperSelector" "toggle"; }
    Ctrl+Alt+L { spawn "inir" "wallpaperSelector" "browse" "live" "-"; }
    Ctrl+Alt+A { spawn "inir" "wallpaperSelector" "openLauncher" "animated"; }

        // Floating tools
        Super+G {
          spawn "inir" "tools" "toggle";
        }

        // ------------------------------------------------------------
        // Niri overview / fenêtres récentes
        // ------------------------------------------------------------

        Mod+Tab {
          toggle-overview;
        }

        Alt+Tab {
          focus-recent-window;
        }

        Alt+Shift+Tab {
          focus-recent-window;
        }

        // ------------------------------------------------------------
        // Region tools iNiR
        // ------------------------------------------------------------

        Mod+Shift+S {
          spawn "inir" "region" "screenshot";
        }

        Mod+Shift+X {
          spawn "inir" "region" "ocr";
        }

        Mod+Shift+A {
          spawn "inir" "region" "image-search";
        }

        Mod+Shift+R {
          spawn "inir" "region" "record";
        }

        // ------------------------------------------------------------
        // Screenshots Niri
        // ------------------------------------------------------------

        Print {
          screenshot;
        }

        Ctrl+Print {
          screenshot-screen;
        }

        Alt+Print {
          screenshot-window;
        }

        // ------------------------------------------------------------
        // Applications & Terminal
        // ------------------------------------------------------------

        Mod+T {
          spawn "kitty";
        }

        Mod+Return {
          spawn "kitty";
        }

        Mod+E {
          spawn "kitty" "-e" "yazi";
        }

        Super+E {
          spawn "kitty" "-e" "yazi";
        }

        Mod+Q {
          close-window;
        }

        // ------------------------------------------------------------
        // Navigation fenêtres
        // ------------------------------------------------------------

        Mod+Left {
          focus-column-left;
        }

        Mod+H {
          focus-column-left;
        }

        Mod+Right {
          focus-column-right;
        }

        Mod+L {
          focus-column-right;
        }

        Mod+Up {
          focus-window-up;
        }

        Mod+K {
          focus-window-up;
        }

        Mod+Down {
          focus-window-down;
        }

        Mod+J {
          focus-window-down;
        }

        // Première / dernière colonne
        Mod+Home {
          focus-column-first;
        }

        Mod+End {
          focus-column-last;
        }

        // ------------------------------------------------------------
        // Déplacement des colonnes / fenêtres
        // ------------------------------------------------------------

        Mod+Shift+Left {
          move-column-left;
        }

        Mod+Shift+H {
          move-column-left;
        }

        Mod+Shift+Right {
          move-column-right;
        }

        Mod+Shift+L {
          move-column-right;
        }

        Mod+Shift+Up {
          move-window-up;
        }

        Mod+Shift+K {
          move-window-up;
        }

        Mod+Shift+Down {
          move-window-down;
        }

        Mod+Shift+J {
          move-window-down;
        }

        // Première / dernière colonne
        Mod+Ctrl+Home {
          move-column-to-first;
        }

        Mod+Ctrl+End {
          move-column-to-last;
        }

        // ------------------------------------------------------------
        // Gestion des fenêtres
        // ------------------------------------------------------------

        // Ton comportement existant conservé
        Mod+F {
          maximize-column;
        }

        Mod+Shift+F {
          fullscreen-window;
        }

        Mod+W {
          toggle-window-floating;
        }

        // Alternative iNiR : floating / tiling
        Mod+A {
          toggle-window-floating;
        }

        // Focus floating / tiling
        Mod+Shift+V {
          switch-focus-between-floating-and-tiling;
        }

        // ------------------------------------------------------------
        // Column layout
        // ------------------------------------------------------------

        // Cycle 1/3 -> 1/2 -> 2/3
        Mod+R {
          switch-preset-column-width;
        }

        // Reset hauteur
        Mod+Ctrl+R {
          reset-window-height;
        }

        // Centrer la colonne
        Mod+C {
          center-column;
        }

        // Largeur colonne
        Mod+Minus {
          set-column-width "-10%";
        }

        Mod+Equal {
          set-column-width "+10%";
        }

        // Hauteur fenêtre
        Mod+Shift+Minus {
          set-window-height "-10%";
        }

        Mod+Shift+Equal {
          set-window-height "+10%";
        }

        // Stack / unstack
        Mod+BracketLeft {
          consume-or-expel-window-left;
        }

        Mod+BracketRight {
          consume-or-expel-window-right;
        }

        // ------------------------------------------------------------
        // Workspaces
        // ------------------------------------------------------------

        Mod+1 {
          focus-workspace 1;
        }

        Mod+2 {
          focus-workspace 2;
        }

        Mod+3 {
          focus-workspace 3;
        }

        Mod+4 {
          focus-workspace 4;
        }

        Mod+5 {
          focus-workspace 5;
        }

        Mod+6 {
          focus-workspace 6;
        }

        Mod+7 {
          focus-workspace 7;
        }

        Mod+8 {
          focus-workspace 8;
        }

        Mod+9 {
          focus-workspace 9;
        }

        // Déplacer vers workspace
        Mod+Ctrl+1 {
          move-column-to-workspace 1;
        }

        Mod+Ctrl+2 {
          move-column-to-workspace 2;
        }

        Mod+Ctrl+3 {
          move-column-to-workspace 3;
        }

        Mod+Ctrl+4 {
          move-column-to-workspace 4;
        }

        Mod+Ctrl+5 {
          move-column-to-workspace 5;
        }

        Mod+Ctrl+6 {
          move-column-to-workspace 6;
        }

        Mod+Ctrl+7 {
          move-column-to-workspace 7;
        }

        Mod+Ctrl+8 {
          move-column-to-workspace 8;
        }

        Mod+Ctrl+9 {
          move-column-to-workspace 9;
        }

        // Navigation workspace
        Mod+Page_Down {
          focus-workspace-down;
        }

        Mod+Page_Up {
          focus-workspace-up;
        }

        Mod+Ctrl+Page_Down {
          move-column-to-workspace-down;
        }

        Mod+Ctrl+Page_Up {
          move-column-to-workspace-up;
        }

        // ------------------------------------------------------------
        // Multi-monitor
        // ------------------------------------------------------------

        Mod+Ctrl+Left {
          focus-monitor-left;
        }

        Mod+Ctrl+Right {
          focus-monitor-right;
        }

        Mod+Ctrl+Up {
          focus-monitor-up;
        }

        Mod+Ctrl+Down {
          focus-monitor-down;
        }

        Mod+Ctrl+Shift+Left {
          move-column-to-monitor-left;
        }

        Mod+Ctrl+Shift+Right {
          move-column-to-monitor-right;
        }

        Mod+Ctrl+Shift+Up {
          move-column-to-monitor-up;
        }

        Mod+Ctrl+Shift+Down {
          move-column-to-monitor-down;
        }

        // ------------------------------------------------------------
        // Session & système
        // ------------------------------------------------------------

        Mod+Shift+Ctrl+Q {
          quit;
        }

        Mod+Shift+E {
          quit;
        }

        Mod+Shift+O {
          power-off-monitors;
        }

        Mod+Escape {
          toggle-keyboard-shortcuts-inhibit;
        }

        // ------------------------------------------------------------
        // Audio
        // ------------------------------------------------------------

        XF86AudioRaiseVolume allow-when-locked=true {
          spawn "wpctl" "set-volume"
            "-l" "1.5"
            "@DEFAULT_AUDIO_SINK@"
            "5%+";
        }

        XF86AudioLowerVolume allow-when-locked=true {
          spawn "wpctl" "set-volume"
            "@DEFAULT_AUDIO_SINK@"
            "5%-";
        }

        XF86AudioMute allow-when-locked=true {
          spawn "wpctl" "set-mute"
            "@DEFAULT_AUDIO_SINK@"
            "toggle";
        }

        // Microphone
        XF86AudioMicMute allow-when-locked=true {
          spawn "wpctl" "set-mute"
            "@DEFAULT_AUDIO_SOURCE@"
            "toggle";
        }

        // ------------------------------------------------------------
        // Média
        // ------------------------------------------------------------

        XF86AudioPlay {
          spawn "playerctl" "play-pause";
        }

        XF86AudioPause {
          spawn "playerctl" "play-pause";
        }

        XF86AudioNext {
          spawn "playerctl" "next";
        }

        XF86AudioPrev {
          spawn "playerctl" "previous";
        }

        // Raccourcis clavier média
        Ctrl+Mod+Space {
          spawn "playerctl" "play-pause";
        }

        Mod+Shift+P {
          spawn "playerctl" "play-pause";
        }

        Mod+Alt+N {
          spawn "playerctl" "next";
        }

        Mod+Shift+N {
          spawn "playerctl" "next";
        }

        Mod+Alt+P {
          spawn "playerctl" "previous";
        }

        Mod+Shift+B {
          spawn "playerctl" "previous";
        }

        Mod+Shift+M {
          spawn "wpctl" "set-mute"
            "@DEFAULT_AUDIO_SINK@"
            "toggle";
        }

        // ------------------------------------------------------------
        // Luminosité
        // ------------------------------------------------------------

        XF86MonBrightnessUp allow-when-locked=true {
          spawn "brightnessctl" "set" "5%+";
        }

        XF86MonBrightnessDown allow-when-locked=true {
          spawn "brightnessctl" "set" "5%-";
        }
      }
  '';
}
