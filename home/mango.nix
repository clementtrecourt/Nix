{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  xdg.configFile."xkb/symbols/us_qwerty-fr".source = "${inputs.qwerty-fr}/linux/us_qwerty-fr";
  wayland.windowManager.mango = {
    enable = true;
    systemd.enable = true;

    autostart_sh = ''
                awww-daemon &
            qs -n &
            set-wallpaper --restore &
            zen &
            kitty &
            wl-paste --type text --watch cliphist store &
      wl-paste --type image --watch cliphist store &
    '';

    extraConfig = ''
      source_optional = ~/.config/mango/colors.conf
      source_optional = ~/.config/mango/monitors.conf
    '';
    bottomPrefixes = ["source"];

    settings = {
      # ============================================
      # Environment variables
      # ============================================
      env = [
        "QT_QPA_PLATFORMTHEME,qt6ct"
        "QT5_QPA_PLATFORMTHEME,qt5ct"
        "XCURSOR_THEME,macos-tahoe-cursor"
        "XCURSOR_SIZE,24"
        "XDG_CURRENT_DESKTOP,mango"
        "XDG_SESSION_TYPE,wayland"
        "MOZ_ENABLE_WAYLAND,1"
        "ELECTRON_OZONE_PLATFORM_HINT,auto"
        "XDG_DATA_DIRS,${config.home.homeDirectory}/.local/share:${config.home.homeDirectory}/.nix-profile/share:/etc/profiles/per-user/${config.home.username}/share:/run/current-system/sw/share"
      ];

      # ============================================
      # Visual Effects
      # ============================================
      blur = 1;
      blur_layer = 1;
      blur_optimized = 0;
      blur_params_num_passes = 3;
      blur_params_radius = 2;
      blur_params_noise = 0;
      blur_params_brightness = 1;
      blur_params_contrast = 1;
      blur_params_saturation = "1.2";

      shadows = 1;
      layer_shadows = 0;
      shadow_only_floating = 1;
      shadows_size = 10;
      shadows_blur = 15;
      shadows_position_x = 0;
      shadows_position_y = 0;

      border_radius = 10;
      no_radius_when_single = 0;
      focused_opacity = "1.0";
      unfocused_opacity = "0.95"; # Léger contraste pour identifier la fenêtre active
      # gappih = 6;
      # gappiv = 6;
      # gappoh = 6;
      # gappov = 6;

      # Règles layer-shell
      # layerrule = [
      #   "layer_name:.*noctalia-panel*,noblur:0,noanim:1"
      # ];

      # ============================================
      # Window Rules
      # ============================================
      # windowrule = [
      #   # Scratchpads dédiés
      #   "isnamedscratchpad:1,isfullscreen:1,appid:spotify"
      #   "isnamedscratchpad:1,isfullscreen:1,appid:Spotify"
      #   "isnamedscratchpad:1,appid:scratchpad-term"
      #
      #   # Applications fixes
      #   "tags:1,appid:zen.*"
      #   "tags:1,appid:zen"
      #   "tags:1,appid:zen-beta"
      #   "tags:2,appid:kitty"
      # ];

      # ============================================
      # Animations (fluides façon Niri)
      # ============================================
      animations = 1;
      layer_animations = 1;
      animation_type_open = "zoom";
      animation_type_close = "zoom";
      animation_fade_in = 1;
      animation_fade_out = 1;
      tag_animation_direction = 0;
      zoom_initial_ratio = "0.7";
      zoom_end_ratio = "0.85";

      animation_duration_move = 160;
      animation_duration_open = 160;
      animation_duration_tag = 160;
      animation_duration_close = 100;
      animation_duration_focus = 0;

      animation_curve_open = "0.15,1.0,0.2,1.0";
      animation_curve_move = "0.15,1.0,0.2,1.0";
      animation_curve_tag = "0.15,1.0,0.2,1.0";
      animation_curve_close = "0.1,1.0,0.1,1.0";
      animation_curve_focus = "0.15,1.0,0.2,1.0";

      # ============================================
      # Layouts & Scroller (Coeur du workflow Niri)
      # ============================================
      # On force 'scroller' par défaut sur tous les tags principaux
      # tagrule = [
      #   "id:1,layout_name:scroller"
      #   "id:2,layout_name:scroller"
      #   "id:3,layout_name:scroller"
      #   "id:4,layout_name:scroller"
      #   "id:5,layout_name:scroller"
      # ];
      #
      # scroller_focus_center = 1;
      # scroller_prefer_center = 1;

      # 2. Réactiver impérativement pour que le ruban défile vers les fenêtres hors-champ
      edge_scroller_pointer_focus = 1;

      # ============================================
      # Keyboard-Centric & Focus (CRITIQUE)
      # ============================================
      # 1 = Focus-follows-mouse (permet l'activation instantanée sans clic)
      # sloppyfocus = 1;

      # Téléporte instantanément la souris sur la fenêtre ciblée au clavier.
      # Combiné avec sloppyfocus = 1, la fenêtre est activée À LA FRACTION DE SECONDE
      # où vous appuyez sur Super+H/L, et se centre automatiquement sans toucher la souris.
      # warpcursor = 1;

      # Active immédiatement toute fenêtre nouvellement créée ou appelée
      focus_on_activate = 1;
      scroller_structs = 15;
      # Largeur par défaut d'une nouvelle colonne (50% de l'écran comme Niri)
      scroller_default_proportion = "0.9";
      # Centrage automatique de la colonne active
      scroller_ignore_proportion_single = 0;
      scroller_default_proportion_single = "1";
      # Cycle de dimensions type Niri : 1/3 -> 1/2 -> 2/3 -> Pleine largeur
      scroller_proportion_preset = "0.33,0.5,0.67,1.0";

      new_is_master = 0;
      # smartgaps = 0;
      scratchpad_width_ratio = "0.8";
      scratchpad_height_ratio = "0.85";
      axisbind = [
        # 1. SUPER + Molette : Scroll horizontal dans le ruban du workspace (workflow Niri)
        "SUPER,UP,focusdir,left"
        "SUPER,DOWN,focusdir,right"

        # 2. SUPER + SHIFT + Molette : Switch du focus d'écran (entre DP-3 et HDMI-A-3)
        "SUPER+SHIFT,UP,focusmon,left"
        "SUPER+SHIFT,DOWN,focusmon,right"
      ];

      # ============================================
      # Input & Devices
      # ============================================
      repeat_rate = 50; # Plus réactif pour naviguer vite au clavier
      repeat_delay = 250;
      # numlockon = 1;
      xkb_rules_layout = "us_qwerty-fr";
      xkb_rules_variant = "qwerty-fr";

      disable_trackpad = 0;
      tap_to_click = 1;
      tap_and_drag = 1;
      drag_lock = 1;
      trackpad_natural_scrolling = 1;
      trackpad_disable_while_typing = 1;
      swipe_min_threshold = 1;

      mouse_natural_scrolling = 0;
      cursor_size = 24;
      cursor_theme = "capitaine-cursors";

      # ============================================
      # Keyboard-Centric Ergonomics
      # ============================================
      focus_cross_monitor = 1;
      focus_cross_tag = 0;
      enable_floating_snap = 1;
      snap_distance = 20;
      layer_rule = [
        "layer_name:selection,no_blur:1,no_animation:1"
      ];

      # ============================================
      # Keybinds (Workflow Niri pur)
      # ============================================
      bind = [
        # --- Gestion Système & Session ---
        "SUPER+SHIFT+CTRL,q,quit"
        "SUPER,q,killclient"
        "SUPER,r,reload_config"

        # --- Applications & Scratchpads ---
        "SUPER,Return,spawn,kitty"
        "SUPER,T,spawn,kitty"
        "SUPER,E,spawn,kitty -e yazi"
        "SUPER,s,toggle_named_scratchpad,Spotify,none,spotify"
        "SUPER,u,toggle_named_scratchpad,scratchpad-term,none,kitty --class scratchpad-term"

        # --- Navigation dans le ruban horizontal (HJKL + Flèches) ---
        "SUPER,h,focusdir,left"
        "SUPER,l,focusdir,right"
        "SUPER,k,focusdir,up"
        "SUPER,j,focusdir,down"
        "SUPER,Left,focusdir,left"
        "SUPER,Right,focusdir,right"
        "SUPER,Up,focusdir,up"
        "SUPER,Down,focusdir,down"

        # Déplacement rapide bout-à-bout du ruban
        "SUPER,Home,focusstack,first"
        "SUPER,End,focusstack,last"

        # --- Déplacement / Échange de fenêtres et colonnes (Shift + HJKL) ---
        "SUPER+SHIFT,h,exchange_client,left"
        "SUPER+SHIFT,l,exchange_client,right"
        "SUPER+SHIFT,k,exchange_client,up"
        "SUPER+SHIFT,j,exchange_client,down"
        "SUPER+SHIFT,Left,exchange_client,left"
        "SUPER+SHIFT,Right,exchange_client,right"
        "SUPER+SHIFT,Up,exchange_client,up"
        "SUPER+SHIFT,Down,exchange_client,down"

        # --- Colonnes & Stacking (Empiler comme dans Niri) ---
        # Consomme / empile verticalement dans la colonne
        "SUPER,bracketleft,scroller_stack,left"
        "SUPER,bracketright,scroller_stack,right"
        "SUPER,c,scroller_stack,left"
        "SUPER+SHIFT,c,scroller_stack,right"

        # --- Dimensions de colonnes (Niri preset widths & expansion) ---
        # Fait défiler les presets : 33% -> 50% -> 67% -> 100%
        # Maximise la colonne en largeur (100% largeur écran sans être fullscreen)
        "SUPER,m,set_proportion,1.0"
        "SUPER+ALT,f,set_proportion,1.0"
        # Réinitialise la colonne à 50%
        "SUPER,comma,set_proportion,0.5"

        "ALT,Tab,spawn,noctalia msg window-switcher hold"
        "ALT+SHIFT,Tab,spawn,noctalia msg window-switcher hold"

        # Redimensionnement précis au clavier
        "SUPER+CTRL,h,resizewin,-50,0"
        "SUPER+CTRL,l,resizewin,50,0"
        "SUPER+CTRL,k,resizewin,0,-40"
        "SUPER+CTRL,j,resizewin,0,40"
        "SUPER+CTRL,minus,resizewin,-50,0"
        "SUPER+CTRL,equal,resizewin,50,0"

        # --- Fenêtres & États ---
        "SUPER,f,togglefullscreen"
        "SUPER+SHIFT,space,togglefloating"
        "SUPER,Tab,toggleoverview"

        # --- Écrans / Moniteurs ---
        "SUPER+ALT,h,focusmon,left"
        "SUPER+ALT,l,focusmon,right"
        "SUPER+SHIFT+ALT,h,tagmon,left"
        "SUPER+SHIFT+ALT,l,tagmon,right"

        # --- Workspaces / Tags ---
        "SUPER,1,view,1"
        "SUPER,2,view,2"
        "SUPER,3,view,3"
        "SUPER,4,view,4"
        "SUPER,5,view,5"
        "SUPER,6,view,6"
        "SUPER,7,view,7"
        "SUPER,8,view,8"
        "SUPER,9,view,9"

        "SUPER+SHIFT,1,tag,1"
        "SUPER+SHIFT,2,tag,2"
        "SUPER+SHIFT,3,tag,3"
        "SUPER+SHIFT,4,tag,4"
        "SUPER+SHIFT,5,tag,5"
        "SUPER+SHIFT,6,tag,6"
        "SUPER+SHIFT,7,tag,7"
        "SUPER+SHIFT,8,tag,8"
        "SUPER+SHIFT,9,tag,9"

        # Cycle rapide entre les tags occupés
        "SUPER,Page_Up,viewtoleft_have_client"
        "SUPER,Page_Down,viewtoright_have_client"

        "SUPER,Escape,spawn,qs ipc call power toggle"
        "SUPER+SHIFT,Escape,spawn,qs ipc call power lock"
        # --- Noctalia UI / Audio / Luminosité ---
        "SUPER,p,spawn,screenshot region"
        "SUPER+SHIFT,p,spawn,screenshot screen"
        "SUPER+CTRL,p,spawn,screenshot edit"
        "SUPER,A,spawn,qs ipc call launcher toggle"
        "SUPER,v,spawn,qs ipc call clipboard toggle"
        "SUPER+SHIFT,w,spawn,qs ipc call wallpaper toggle"
      ];

      # ============================================
      # Mouse (Fallback de secours uniquement)
      # ============================================
      mousebind = [
        "SUPER,btn_left,moveresize,curmove"
        "SUPER,btn_right,moveresize,curresize"
      ];
    };
  };

  home.activation.createEmptyMangoColors = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p $HOME/.config/mango
    touch $HOME/.config/mango/colors.conf
  '';
}
