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
        "noctalia"
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
      # Nouvelles Règles Hyprland (v0.53+)
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

      layerrule = [
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

        # Intégration Noctalia
        "SUPER, A, exec, noctalia msg panel-toggle launcher"
        "SUPER, L, exec, noctalia msg session lock"
        "SUPER, comma, exec, noctalia msg settings-toggle"
        "SUPER, Escape, exec, noctalia msg panel-toggle session"
        "SUPER, V, exec, noctalia msg panel-toggle clipboard"
        "SUPER, P, exec, noctalia msg screenshot-region"
        "SUPER SHIFT, W, exec, noctalia msg panel-toggle wallpaper"
        ", XF86AudioRaiseVolume, exec, noctalia msg volume-up"
        ", XF86AudioLowerVolume, exec, noctalia msg volume-down"
        ", XF86AudioMute, exec, noctalia msg volume-mute"
        ", XF86MonBrightnessUp, exec, noctalia msg brightness-up"
        ", XF86MonBrightnessDown, exec, noctalia msg brightness-down"
      ];

      # Souris
      bindm = [
        "SUPER, mouse:272, movewindow"
        "SUPER, mouse:273, resizewindow"
      ];
    };

    extraConfig = ''
      source = ~/.config/hypr/noctalia.conf
    '';
  };

  home.activation.createEmptyHyprlandNoctaliaConf = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p $HOME/.config/hypr
    touch $HOME/.config/hypr/noctalia.conf
  '';
}
