{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  xdg.configFile."xkb/symbols/us_qwerty-fr".source = "${inputs.qwerty-fr}/linux/us_qwerty-fr";

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;

    settings = {
      # ============================================
      # Démarrage automatique
      # ============================================
      exec-once = [
        "caelestia shell -d"
        "zen"
        "kitty"
      ];

      # ============================================
      # Variables d'environnement
      # ============================================
      env = [
        "QT_QPA_PLATFORMTHEME,qt6ct"
        "QT5_QPA_PLATFORMTHEME,qt5ct"
        "XCURSOR_THEME,capitaine-cursors"
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_THEME,capitaine-cursors"
        "HYPRCURSOR_SIZE,24"
        "MOZ_ENABLE_WAYLAND,1"
        "ELECTRON_OZONE_PLATFORM_HINT,auto"
      ];

      # ============================================
      # Clavier & Souris
      # ============================================
      input = {
        kb_layout = "us_qwerty-fr";
        kb_variant = "qwerty-fr";
        repeat_rate = 25;
        repeat_delay = 400;
        numlock_by_default = true;
        follow_mouse = 1;
        touchpad = {
          natural_scroll = false;
          tap-to-click = true;
          disable_while_typing = true;
        };
      };

      # ============================================
      # Apparence générale & Gaps
      # ============================================
      general = {
        gaps_in = 5;
        gaps_out = 5;
        border_size = 2;
        layout = "dwindle";
      };

      decoration = {
        rounding = 10;
        active_opacity = 1.0;
        inactive_opacity = 1.0;

        blur = {
          enabled = true;
          size = 2;
          passes = 3;
          new_optimizations = true;
        };

        shadow = {
          enabled = true;
          range = 15;
          render_power = 2;
        };
      };

      dwindle = {
        preserve_split = true;
      };

      # ============================================
      # Règles de fenêtres
      # ============================================
      windowrule = [
        # Zen -> Workspace 1
        "workspace 1, match:class ^(zen.*)$"
        "workspace 1, match:class ^(zen)$"
        "workspace 1, match:class ^(zen-beta)$"

        # Kitty -> Workspace 2
        "workspace 2, match:class ^(kitty)$"

        # Spotify -> Scratchpad spécial
        "workspace special:spotify, match:class ^(spotify)$"
        "workspace special:spotify, match:class ^(Spotify)$"
      ];

      # ============================================
      # Raccourcis Clavier
      # ============================================
      bind = [
        # Session & Gestion de fenêtres
        "SUPER SHIFT CTRL, Q, exit"
        "SUPER, Q, killactive"
        "SUPER, W, togglefloating"
        "SUPER, F, fullscreen, 0"

        # Applications
        "SUPER, T, exec, kitty"
        "SUPER, E, exec, kitty -e yazi"

        # Scratchpad Spotify
        "SUPER, S, togglespecialworkspace, spotify"

        # Focus des fenêtres
        "SUPER, left, movefocus, l"
        "SUPER, right, movefocus, r"
        "SUPER, up, movefocus, u"
        "SUPER, down, movefocus, d"

        # Workspaces (1 à 9)
        "SUPER, 1, workspace, 1"
        "SUPER, 2, workspace, 2"
        "SUPER, 3, workspace, 3"
        "SUPER, 4, workspace, 4"
        "SUPER, 5, workspace, 5"
        "SUPER, 6, workspace, 6"
        "SUPER, 7, workspace, 7"
        "SUPER, 8, workspace, 8"
        "SUPER, 9, workspace, 9"

        # Déplacer vers Workspace
        "SUPER SHIFT, 1, movetoworkspace, 1"
        "SUPER SHIFT, 2, movetoworkspace, 2"
        "SUPER SHIFT, 3, movetoworkspace, 3"
        "SUPER SHIFT, 4, movetoworkspace, 4"
        "SUPER SHIFT, 5, movetoworkspace, 5"
        "SUPER SHIFT, 6, movetoworkspace, 6"
        "SUPER SHIFT, 7, movetoworkspace, 7"
        "SUPER SHIFT, 8, movetoworkspace, 8"
        "SUPER SHIFT, 9, movetoworkspace, 9"

        # Raccourcis Système & Caelestia
        "SUPER, A, exec, caelestia"
        "SUPER, P, exec, hyprshot -m region"
        "SUPER, V, exec, clipse"

        # Contrôles Audio (Wireplumber / wpctl)
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

        # Contrôles Luminosité (brightnessctl)
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      # Souris
      bindm = [
        "SUPER, mouse:272, movewindow"
        "SUPER, mouse:273, resizewindow"
      ];
    };
  };
}
