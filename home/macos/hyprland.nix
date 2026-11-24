# Hyprland façon macOS Tahoe : fenêtres flottantes centrées, barres de titre à
# feux tricolores (hyprbars), coins arrondis continus, grande ombre douce,
# flou des surfaces du shell (macos-*), animations et gestes du Mac, raccourcis Cmd.
#
# Format : hyprlang (hyprland.conf). Le format Lua de Hyprland 0.56 change la syntaxe
# de `hyprctl dispatch` (attend du Lua : hl.dsp…) ; or Quickshell 0.3.1
# (Hyprland.dispatch), le shell (services/Windows.qml) et les boutons hyprbars
# envoient des dispatchers classiques. À migrer quand Quickshell suivra.
#
# Le bloc « look » (entre les marqueurs) est recopié tel quel dans
# home/macos/dev/hyprland-dev.conf pour que le banc de test imbriqué soit fidèle.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  macosPkgs = import ./pkgs {inherit pkgs inputs;};
  hyprbars = pkgs.hyprlandPlugins.hyprbars;
  wm = "${macosPkgs.macos-wm}/bin/macos-wm";
  shot = "${macosPkgs.macos-screenshot}/bin/macos-screenshot";
  appearance = "${macosPkgs.macos-appearance}/bin/macos-appearance";
  qs = "${pkgs.quickshell}/bin/quickshell -c macos ipc call";
  # Apps à décorations client sans identifiant « reverse-DNS » (navigateurs, Electron,
  # GTK à barre d'en-tête…) : pas de barre hyprbars, coins « barre d'outils » de Tahoe
  csdApps = lib.concatStringsSep "|" [
    "zen.*"
    "firefox.*"
    "librewolf"
    "brave-browser.*"
    "chromium.*"
    "google-chrome.*"
    "helium.*"
    "zed"
    "Zed"
    "code"
    "Code"
    "code-oss"
    "cursor"
    "obsidian"
    "discord"
    "vesktop"
    "teams-for-linux"
    "steam"
    "spotify"
    "Spotify"
    "motrix.*"
    "WaveFlow"
    "waveflow"
    "gtk3-.*"
    "gtk4-.*"
    "gnome-.*"
    "nautilus"
    "file-roller"
    "evince"
    "eog"
    "totem"
    "baobab"
    "seahorse"
    "pavucontrol"
    "nwg-look"
    "blueman-manager"
    "easyeffects"
    "heroic"
    "freetube"
    "FreeTube"
  ];
  # Apps à identifiant « reverse-DNS » qui ne dessinent PAS leurs décorations :
  # GTK3 sans barre d'en-tête, Qt (QT_WAYLAND_DISABLE_WINDOWDECORATION=1)… -> barre hyprbars
  ssdApps = lib.concatStringsSep "|" [
    "org\\.kde\\..*"
    "org\\.qt-project\\..*"
    "io\\.mpv\\.Mpv"
    "org\\.pwmt\\.zathura"
    "org\\.qbittorrent\\..*"
    "org\\.keepassxc\\..*"
    "com\\.obsproject\\..*"
    "org\\.prismlauncher\\..*"
    "org\\.strawberrymusicplayer\\..*"
    "org\\.musicbrainz\\..*"
    "org\\.inkscape\\..*"
    "org\\.gimp\\..*"
    "org\\.shotcut\\..*"
    "org\\.audacityteam\\..*"
    "org\\.kicad\\..*"
    "org\\.wezfurlong\\.wezterm"
    "org\\.remmina\\..*"
    "com\\.github\\.xournalpp\\..*"
    "net\\.sourceforge\\..*"
    "io\\.github\\.quodlibet\\..*"
    "org\\.fcitx\\..*"
    "org\\.flameshot\\..*"
  ];
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  playerctl = "${pkgs.playerctl}/bin/playerctl";

  # ---------------------------------------------------------------------------
  # Rendu (partagé avec le banc de test) : uniquement des réglages visuels et
  # des règles, aucun chemin du store.
  # ---------------------------------------------------------------------------
  look = ''
    # >>> look macOS Tahoe (généré depuis home/macos/hyprland.nix)
    general {
      gaps_in = 0
      gaps_out = 0
      # Liseré d'un pixel (le « hairline » clair des fenêtres sombres de Tahoe)
      border_size = 1
      col.active_border = rgba(ffffff24)
      col.inactive_border = rgba(ffffff14)
      # Redimensionnement depuis les bords, comme sur Mac
      resize_on_border = true
      extend_border_grab_area = 10
      hover_icon_on_border = true
      layout = dwindle
      # Aimantation des fenêtres entre elles et aux bords (macOS 15+)
      snap {
        enabled = true
        window_gap = 8
        monitor_gap = 8
        border_overlap = false
      }
    }

    decoration {
      # Coins « continus » (superellipse) : fenêtres à barre de titre de Tahoe
      rounding = 16
      rounding_power = 2.6
      active_opacity = 1.0
      inactive_opacity = 1.0
      dim_inactive = false
      # Ombre macOS : large et diffuse (~ 0 22 70 pt) sur la fenêtre active, pour
      # détacher nettement les fenêtres empilées ; plus courte sur les inactives
      shadow {
        enabled = true
        range = 80
        render_power = 1
        offset = 0 22
        scale = 1.0
        color = rgba(000000b3)
        color_inactive = rgba(00000066)
      }
      # Flou des matériaux (surfaces macos-* du shell)
      blur {
        enabled = true
        size = 12
        passes = 4
        noise = 0.02
        contrast = 1.0
        brightness = 1.0
        vibrancy = 0.25
        vibrancy_darkness = 0.2
        popups = true
        new_optimizations = true
        xray = false
      }
    }

    animations {
      enabled = true
      # Courbes Apple : ressort amorti critique (ouverture, espaces), sortie rapide
      bezier = tahoe, 0.22, 1, 0.36, 1
      bezier = tahoeSpring, 0.25, 1.05, 0.4, 1
      bezier = tahoeOut, 0.4, 0, 0.9, 0.6
      bezier = tahoeSpace, 0.2, 0.9, 0.25, 1
      # Fenêtres : zoom léger + fondu à l'ouverture, fermeture brève
      animation = windowsIn, 1, 3.2, tahoeSpring, popin 90%
      animation = windowsOut, 1, 1.8, tahoeOut, popin 94%
      animation = windowsMove, 1, 3.5, tahoe
      animation = fadeIn, 1, 2.4, tahoe
      animation = fadeOut, 1, 1.6, tahoeOut
      animation = fadeSwitch, 1, 3, tahoe
      animation = fadeShadow, 1, 3, tahoe
      animation = fadeDim, 1, 3, tahoe
      animation = border, 1, 3, tahoe
      animation = borderangle, 0
      # Espaces : glissement horizontal plein écran (≈ 0,45 s, ressort)
      animation = workspaces, 1, 4.5, tahoeSpace, slide
      animation = specialWorkspace, 1, 3, tahoe, fade
      # Couches : le shell anime lui-même ses panneaux (QML) ; fondu pour les autres
      animation = layers, 1, 2.5, tahoe, fade
      animation = fadeLayers, 1, 2.5, tahoe
      animation = zoomFactor, 1, 4, tahoe
    }

    # --- Surfaces du shell (Quickshell, namespaces macos-*) ---------------------
    layerrule = blur on, match:namespace ^(macos-.*)$
    layerrule = ignore_alpha 0.05, match:namespace ^(macos-.*)$
    # Verres Liquid Glass qui réfractent eux-mêmes leur fond (common/GlassBackdrop) :
    # pas de flou du compositeur (il se verrait en double)
    layerrule = blur off, match:namespace ^(macos-lg-.*)$
    layerrule = no_anim on, match:namespace ^(macos-.*)$
    # Sélecteur de captures (slurp) : pas de fondu, apparition immédiate
    layerrule = no_anim on, match:namespace ^(selection)$

    # --- Fenêtres : comportement Mac -------------------------------------------
    # Toutes flottantes et centrées à l'ouverture
    windowrule = float on, match:class .*
    windowrule = center on, match:class .*
    # Grandes apps (navigateurs, éditeurs, Finder) : fenêtre confortable
    windowrule = size (monitor_w*0.74) (monitor_h*0.8), match:class ^(zen.*|firefox.*|librewolf|brave-browser.*|chromium.*|google-chrome.*|helium.*|dev\.zed\.Zed.*|code|Code|code-oss|cursor|nemo|org\.gnome\.Nautilus|spotify|Spotify)$
    # Spotify vit dans l'espace spécial « spotify » (Super+S l'affiche / le cache)
    windowrule = workspace special:spotify silent, match:class ^([Ss]potify)$
    # Apps à décorations client (GTK4/libadwaita, navigateurs, Electron…) : elles
    # dessinent déjà leurs boutons -> pas de barre hyprbars, coins Tahoe « barre
    # d'outils » (~26 pt). Identifiant reverse-DNS = presque toujours GTK4/libadwaita,
    # sauf la liste ssdApps (GTK3 sans barre d'en-tête, Qt…) qui garde la barre.
    # (GTK3 sans identifiant reverse-DNS, ex. nemo : décorations serveur -> barre hyprbars)
    windowrule = hyprbars:no_bar on, match:class ^(.*\..*)$
    windowrule = hyprbars:no_bar off, match:class ^(${ssdApps})$
    windowrule = hyprbars:no_bar on, match:class ^(${csdApps})$
    windowrule = rounding 26, match:class ^(.*\..*|${csdApps})$
    windowrule = rounding 16, match:class ^(${ssdApps})$
    # Fenêtre inactive : barre au fond « backdrop » du thème (comme la barre d'outils
    # GTK juste dessous), titre en tertiaryLabel ; les feux passent au gris (plugin)
    windowrule = hyprbars:bar_color rgb(242424), match:focus false
    windowrule = hyprbars:title_color rgba(ffffff4d), match:focus false
    # Terminal : barre de titre de la couleur du fond, comme Terminal.app
    windowrule = hyprbars:bar_color rgb(1e1e1e), match:class ^(kitty|foot|footclient|Alacritty)$
    # Plein écran : ni coins ni ombre ni liseré
    windowrule = rounding 0, match:fullscreen true
    windowrule = no_shadow on, match:fullscreen true
    windowrule = border_size 0, match:fullscreen true
    # Dialogues GTK/portails : au-dessus de leur parent
    windowrule = center on, match:modal true
    # Incrustation vidéo (Picture in Picture) : épinglée en coin, sans barre
    windowrule = pin on, match:title ^(Picture-in-Picture|Picture in picture|Incrustation vidéo)$
    windowrule = hyprbars:no_bar on, match:title ^(Picture-in-Picture|Picture in picture|Incrustation vidéo)$
    windowrule = keep_aspect_ratio on, match:title ^(Picture-in-Picture|Picture in picture|Incrustation vidéo)$
    windowrule = move (monitor_w-window_w-24) (monitor_h-window_h-96), match:title ^(Picture-in-Picture|Picture in picture|Incrustation vidéo)$
    # Finder du shell (shell/finder, fenêtres Quickshell « org.quickshell ») : il
    # dessine ses feux tricolores dans sa barre latérale -> pas de barre hyprbars,
    # coins « barre d'outils » de Tahoe ; « Get Info » : petite fenêtre à barre de
    # titre seule, coins plus serrés
    windowrule = hyprbars:no_bar on, match:class ^(org\.quickshell)$
    windowrule = rounding 26, match:class ^(org\.quickshell)$
    windowrule = rounding 16, match:class ^(org\.quickshell)$, match:title ^(.* Info)$

    # --- Barres de titre Tahoe (plugin hyprbars) --------------------------------
    plugin {
      hyprbars {
        enabled = true
        # Barre de titre simple de Tahoe : 32 pt, couleur = barre d'en-tête MacTahoe-Dark
        # (#333333, continue avec la barre de menus / d'outils GTK juste dessous).
        # Mode clair : couleurs réappliquées par macos-appearance (hyprctl keyword).
        bar_height = 32
        bar_color = rgb(333333)
        col.text = rgba(ffffffd9)
        bar_title_enabled = true
        bar_text_font = Inter
        bar_text_size = 13
        bar_text_weight = semibold
        bar_text_align = center
        bar_part_of_window = true
        bar_precedence_over_border = true
        bar_blur = false
        # Feux tricolores à gauche : Ø 14 pt, 9 pt d'écart, alignés sur l'arrondi
        bar_buttons_alignment = left
        bar_padding = 10
        bar_button_padding = 9
        # Symboles × − ⤢ visibles au survol du groupe, gris quand la fenêtre est inactive
        icon_on_hover = true
        inactive_button_color = rgb(4f4f52)
        # Double-clic sur la barre : « Zoom » (remplit l'écran hors barre des menus/Dock)
        on_double_click = hyprctl dispatch fullscreen 1
        # hyprbars-button = fond, diamètre, symbole, action, couleur du symbole (de gauche à droite)
        # Jaune : effet « génie » vers le Dock (macos-wm minimize -> global macos:minimize)
        # Vert : plein écran dans un nouvel espace (macos-wm fullscreen)
        hyprbars-button = rgb(ff5f57), 14, ×, hyprctl dispatch killactive, rgb(4d0000)
        hyprbars-button = rgb(febc2e), 14, −, macos-wm minimize, rgb(995700)
        hyprbars-button = rgb(28c840), 14, ⤢, macos-wm fullscreen, rgb(006500)
      }
    }

    # --- Saisie et gestes -------------------------------------------------------
    input {
      kb_layout = us_qwerty-fr
      kb_variant = qwerty-fr
      repeat_rate = 25
      repeat_delay = 400
      numlock_by_default = true
      # Clic pour donner le focus clavier, défilement sous le pointeur (comme macOS)
      follow_mouse = 2
      float_switch_override_focus = 0
      accel_profile = adaptive
      touchpad {
        natural_scroll = true
        tap-to-click = true
        tap-and-drag = true
        drag_lock = false
        disable_while_typing = true
        # Clic secondaire à deux doigts, comme sur un MacBook
        clickfinger_behavior = true
        scroll_factor = 1.0
      }
    }

    gestures {
      workspace_swipe_distance = 500
      workspace_swipe_cancel_ratio = 0.3
      workspace_swipe_min_speed_to_force = 20
      workspace_swipe_create_new = false
      workspace_swipe_forever = false
      workspace_swipe_direction_lock = true
    }
    # 3 ou 4 doigts horizontaux : espace voisin ; 4 doigts haut/bas : Mission Control / Exposé
    gesture = 3, horizontal, workspace
    gesture = 4, horizontal, workspace
    gesture = 4, up, dispatcher, global, macos:missioncontrol
    gesture = 4, down, dispatcher, global, macos:appexpose

    cursor {
      # macOS masque le pointeur pendant la frappe et ne le déplace jamais tout seul
      hide_on_key_press = true
      no_warps = true
      warp_on_change_workspace = 0
    }

    binds {
      workspace_back_and_forth = false
      allow_workspace_cycles = false
      hide_special_on_workspace_change = true
    }

    misc {
      disable_hyprland_logo = true
      disable_splash_rendering = true
      force_default_wallpaper = 0
      background_color = rgb(000000)
      font_family = Inter
      focus_on_activate = true
      middle_click_paste = false
      animate_manual_resizes = false
      animate_mouse_windowdragging = false
      close_special_on_empty = true
      enable_swallow = false
      allow_session_lock_restore = true
      key_press_enables_dpms = true
      mouse_move_enables_dpms = true
    }

    xwayland {
      force_zero_scaling = true
    }

    ecosystem {
      no_update_news = true
      no_donation_nag = true
    }
    # <<< look
  '';

  # Touches « Cmd » du Mac renvoyées à l'app en Ctrl (Ctrl+Maj dans les terminaux)
  # (A T V P L F R S W , = - et 1…9 sont pris par les raccourcis personnels, cf. bind)
  cmdKeys = ["C" "X" "Z" "N" "O" "B" "I" "U" "K" "0"];

  # Super+S : Spotify en « scratchpad » (espace spécial), lancé au premier appel
  spotifyPad = pkgs.writeShellScript "spotify-pad" ''
    if ! ${pkgs.hyprland}/bin/hyprctl clients -j | ${pkgs.jq}/bin/jq -e 'any(.[]; .class == "Spotify" or .class == "spotify")' >/dev/null; then
      ${pkgs.hyprland}/bin/hyprctl dispatch exec spotify >/dev/null
    fi
    ${pkgs.hyprland}/bin/hyprctl dispatch togglespecialworkspace spotify >/dev/null
  '';
in {
  # Disposition qwerty-fr (fichier xkb utilisateur, comme avec Mango)
  xdg.configFile."xkb/symbols/us_qwerty-fr".source = "${inputs.qwerty-fr}/linux/us_qwerty-fr";

  # macos-wm doit être dans le PATH : les boutons hyprbars du bloc « look » l'appellent
  # par son nom (le bloc est partagé avec le banc de test, sans chemins du store)
  home.packages = [
    macosPkgs.macos-wm
    macosPkgs.macos-screenshot
    macosPkgs.macos-appearance
    pkgs.grim
    pkgs.slurp
    pkgs.hyprlock
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    # Paquet et portail fournis par le module NixOS (programs.hyprland) : mêmes versions
    # que le plugin hyprbars, pas de doublon dans le profil.
    package = null;
    portalPackage = null;
    configType = "hyprlang";
    # Tout l'environnement de session (PATH, XDG_DATA_DIRS…) vers systemd/D-Bus :
    # le shell lancé en service et les apps qu'il démarre en héritent.
    systemd = {
      enable = true;
      variables = ["--all"];
    };

    settings = {
      # Chargé à la lecture de la config (version identique à Hyprland, cf. module NixOS)
      plugin = ["${hyprbars}/lib/libhyprbars.so"];

      monitor = [", preferred, auto, auto"];

      env = [
        "XCURSOR_THEME,macOS"
        "XCURSOR_SIZE,24"
        "NIXOS_OZONE_WL,1"
        "ELECTRON_OZONE_PLATFORM_HINT,auto"
        "MOZ_ENABLE_WAYLAND,1"
        "QT_QPA_PLATFORM,wayland;xcb"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        "GDK_BACKEND,wayland,x11,*"
        "SDL_VIDEODRIVER,wayland,x11"
        "QS_ICON_THEME,MacTahoe-Apple-dark"
      ];

      exec-once = [
        "hyprctl setcursor macOS 24"
        # macOS remonte toujours au premier plan la fenêtre qui prend le focus
        "${wm} watch-raise"
        # Mode clair / sombre de tout le système (suit gsettings color-scheme)
        "${appearance} watch"
        # Connexion automatique (greetd) : la session s'ouvre verrouillée, comme la
        # fenêtre de connexion du Mac (et le mot de passe déverrouille le trousseau)
        "${wm} lock-at-start"
      ];

      bind =
        [
          # ---- Contrat du shell (GlobalShortcut appid "macos") ----
          "SUPER, space, global, macos:spotlight"
          # ⌥⌘Espace : fenêtre du Finder (comme « Rechercher dans le Finder » sur Mac)
          "SUPER ALT, space, global, macos:finder"
          ", XF86LaunchB, global, macos:apps"
          ", F4, global, macos:apps"
          "SUPER CTRL, Q, global, macos:lock"
          "SUPER ALT, Escape, global, macos:forcequit"
          "SUPER SHIFT, P, global, macos:screenshot-ui"
          "CTRL, Up, global, macos:missioncontrol"
          ", XF86LaunchA, global, macos:missioncontrol"
          ", F3, global, macos:missioncontrol"
          "CTRL, Down, global, macos:appexpose"
          "SUPER, Tab, global, macos:switcher-next"
          "SUPER SHIFT, Tab, global, macos:switcher-prev"
          # Fn+C / Fn+N du Mac (la touche Fn/Globe n'existe pas pour Linux) -> Ctrl+Cmd
          "SUPER CTRL, C, global, macos:controlcenter"
          "SUPER CTRL, N, global, macos:notificationcenter"
          # Cmd+Opt+D : masquer / afficher automatiquement le Dock
          "SUPER ALT, D, global, macos:dock-autohide"

          # ---- Apps et fenêtres ----
          "SUPER, Return, exec, kitty"
          "SUPER, Q, exec, ${wm} quit-app"
          # Cmd+W ferme l'onglet / le document, Cmd+Maj+W la fenêtre (navigateurs)
          "SUPER SHIFT, W, killactive"
          # Cmd+M : effet « génie » vers le Dock
          "SUPER, M, exec, ${wm} minimize"
          "SUPER, H, exec, ${wm} hide-app"
          "SUPER ALT, H, exec, ${wm} hide-others"
          "SUPER, grave, exec, ${wm} cycle-app"
          # Ctrl+Cmd+F : plein écran dans son propre espace (comme le bouton vert)
          "SUPER CTRL, F, exec, ${wm} fullscreen"

          # ---- Espaces (Ctrl+←/→, Ctrl+1…9) ----
          "CTRL, Left, workspace, e-1"
          "CTRL, Right, workspace, e+1"

          # ---- Captures d'écran (nom macOS, ~/Pictures/Screenshots) ----
          # (⇧⌘3/4 cèdent la place à Super+Maj+1…9 : Super+P zone, Impr. écran écran entier)
          "SUPER, P, exec, ${shot} region"
          ", Print, exec, ${shot} full"
          "SHIFT, Print, exec, ${shot} region"
          "CTRL, Print, exec, ${shot} full --clipboard"
          "CTRL SHIFT, Print, exec, ${shot} region --clipboard"

          # ---- Édition façon Mac : Cmd+Maj+Z (rétablir), Cmd+Maj+T (rouvrir l'onglet) ----
          "SUPER SHIFT, Z, exec, ${wm} key Z shift"
          "SUPER SHIFT, T, exec, ${wm} key T shift"
          # Cmd+[ / Cmd+] : page précédente / suivante (navigateurs, Finder)
          "SUPER, bracketleft, sendshortcut, ALT, Left, activewindow"
          "SUPER, bracketright, sendshortcut, ALT, Right, activewindow"

          # ---- Raccourcis personnels (repris de l'ancienne config Mango/Noctalia) ----
          "SUPER, A, global, macos:apps" # lanceur (vue Applications)
          "SUPER, T, exec, kitty"
          "SUPER, E, exec, kitty -e yazi"
          "SUPER, V, exec, ${qs} spotlight-debug open clipboard" # historique du presse-papiers
          "SUPER, L, global, macos:lock"
          "SUPER, comma, exec, macos-settings"
          "SUPER, Escape, exec, ${qs} menubar-debug open logo" # menu Apple : veille, redémarrer, éteindre…
          "SUPER ALT, W, exec, ${qs} shell open wallpaper"
          "SUPER, S, exec, ${spotifyPad}"
          "SUPER, R, exec, hyprctl reload"
          "SUPER SHIFT CTRL, Q, exit"
          "SUPER, W, togglefloating"
          "SUPER, F, fullscreen, 0"
          # Espaces voisins (occupés / tous) et déplacement de la fenêtre
          "SUPER SHIFT, Up, workspace, e-1"
          "SUPER SHIFT, Down, workspace, e+1"
          "SUPER CTRL, Up, workspace, r-1"
          "SUPER CTRL, Down, workspace, r+1"
          "SUPER CTRL ALT, Up, movetoworkspace, r-1"
          "SUPER CTRL ALT, Down, movetoworkspace, r+1"
          # Écrans
          "SUPER CTRL, Left, focusmonitor, l"
          "SUPER CTRL, Right, focusmonitor, r"
          "SUPER SHIFT CTRL, Left, movewindow, mon:l"
          "SUPER SHIFT CTRL, Right, movewindow, mon:r"
        ]
        ++ map (k: "SUPER, ${k}, exec, ${wm} key ${k}") cmdKeys
        ++ builtins.concatLists (builtins.genList (i: let
            n = toString (i + 1);
          in [
            "CTRL, ${n}, workspace, ${n}"
            "CTRL SHIFT, ${n}, movetoworkspace, ${n}"
            "SUPER, ${n}, workspace, ${n}"
            "SUPER SHIFT, ${n}, movetoworkspace, ${n}"
          ])
          9);

      # Relâchement de Cmd : valide le sélecteur d'apps (Cmd+Tab)
      bindrt = ["SUPER, Super_L, global, macos:switcher-commit"];

      # Navigation et édition de texte façon Mac (répétées si maintenues) :
      #   Cmd+←/→ début/fin de ligne, Cmd+↑/↓ début/fin du document (+Maj : sélection)
      #   Opt+←/→ mot précédent/suivant (+Maj : sélection), Opt+⌫ / Opt+Suppr : mot
      #   Cmd+⌫ : efface jusqu'au début de la ligne
      binde = [
        "SUPER, Left, sendshortcut, , Home, activewindow"
        "SUPER, Right, sendshortcut, , End, activewindow"
        "SUPER, Up, sendshortcut, CTRL, Home, activewindow"
        "SUPER, Down, sendshortcut, CTRL, End, activewindow"
        "SUPER SHIFT, Left, sendshortcut, SHIFT, Home, activewindow"
        "SUPER SHIFT, Right, sendshortcut, SHIFT, End, activewindow"
        "ALT, Left, sendshortcut, CTRL, Left, activewindow"
        "ALT, Right, sendshortcut, CTRL, Right, activewindow"
        "ALT SHIFT, Left, sendshortcut, CTRL SHIFT, Left, activewindow"
        "ALT SHIFT, Right, sendshortcut, CTRL SHIFT, Right, activewindow"
        "ALT, BackSpace, sendshortcut, CTRL, BackSpace, activewindow"
        "ALT, Delete, sendshortcut, CTRL, Delete, activewindow"
        "SUPER, BackSpace, exec, ${wm} kill-line"
        # Redimensionner la fenêtre active (Super+= / Super+-, avec Ctrl : hauteur)
        "SUPER, equal, resizeactive, 40 0"
        "SUPER, minus, resizeactive, -40 0"
        "SUPER CTRL, equal, resizeactive, 0 40"
        "SUPER CTRL, minus, resizeactive, 0 -40"
      ];

      # Touches multimédia (répétées si maintenues, actives écran verrouillé) puis OSD du shell
      bindel = [
        ", XF86AudioRaiseVolume, exec, ${wpctl} set-volume -l 1 @DEFAULT_AUDIO_SINK@ 6.25%+ && ${qs} osd volume"
        ", XF86AudioLowerVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 6.25%- && ${qs} osd volume"
        ", XF86MonBrightnessUp, exec, ${brightnessctl} -e4 -n2 set 6.25%+ && ${qs} osd brightness"
        ", XF86MonBrightnessDown, exec, ${brightnessctl} -e4 -n2 set 6.25%- && ${qs} osd brightness"
        ", XF86KbdBrightnessUp, exec, ${brightnessctl} -d '*::kbd_backlight' set 10%+ && ${qs} osd keyboard"
        ", XF86KbdBrightnessDown, exec, ${brightnessctl} -d '*::kbd_backlight' set 10%- && ${qs} osd keyboard"
      ];
      bindl = [
        ", XF86AudioMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle && ${qs} osd volume"
        ", XF86AudioMicMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ", XF86AudioPlay, exec, ${playerctl} play-pause"
        ", XF86AudioPause, exec, ${playerctl} play-pause"
        ", XF86AudioNext, exec, ${playerctl} next"
        ", XF86AudioPrev, exec, ${playerctl} previous"
      ];

      # Cmd+glisser / Cmd+clic droit : déplacer / redimensionner
      bindm = [
        "SUPER, mouse:272, movewindow"
        "SUPER, mouse:273, resizewindow"
      ];
    };

    # Mode « capture » de Cmd+Maj+4 : Espace -> capture d'une fenêtre, Échap -> annuler
    # (le mode fenêtre garde la destination choisie : fichier ou presse-papiers)
    submaps.macos-capture.settings.bind = [
      ", space, exec, ${shot} window"
      ", escape, exec, ${pkgs.procps}/bin/pkill -x slurp"
    ];

    extraConfig = look;
  };

  # Presse-papiers : historique cliphist (wl-paste --watch)
  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  # Veille : verrouillage par le shell (raccourci global macos:lock, hyprlock si le
  # shell ne tourne pas), puis extinction de l'écran. Avant la mise en veille,
  # hypridle attend que l'écran soit réellement verrouillé (inhibit_sleep = 3).
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "${wm} lock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
        inhibit_sleep = 3;
      };
      listener = [
        {
          timeout = 600;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 900;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };
}
