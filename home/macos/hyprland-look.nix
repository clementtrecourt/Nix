# Bloc « look » de Hyprland façon macOS Tahoe : réglages visuels, règles de fenêtres,
# barres de titre hyprbars, animations, saisie et gestes. AUCUN chemin du store :
# expression Nix pure (sans argument ni nixpkgs), source UNIQUE de ce bloc pour
#   - la prod : home/macos/hyprland.nix (extraConfig) ;
#   - le banc de test : home/macos/dev/nested.sh (nix eval --raw -f ce fichier).
# Ainsi le banc imbriqué ne peut plus diverger de la session réelle.
let
  # Apps à décorations client sans identifiant « reverse-DNS » (navigateurs, Electron,
  # GTK à barre d'en-tête…) : pas de barre hyprbars, coins « barre d'outils » de Tahoe
  csdApps = builtins.concatStringsSep "|" [
    # Sélecteur de fichiers / dialogues du portail GTK (barre d'en-tête GTK propre)
    "xdg-desktop-portal-gtk"
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
  ssdApps = builtins.concatStringsSep "|" [
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
  # Petites fenêtres d'utilitaires qui flottent (comme sur Mac) au lieu d'être pavées
  floatApps = builtins.concatStringsSep "|" [
    "xdg-desktop-portal-gtk"
    "xdg-desktop-portal-gnome"
    "hyprland-share-picker"
    "org\\.gnome\\.Calculator"
    "gnome-calculator"
    "org\\.kde\\.kcalc"
    "qalculate-gtk"
    "polkit-gnome-authentication-agent-1"
    "org\\.kde\\.polkit-kde-authentication-agent-1"
    "hyprpolkitagent"
    "gcr-prompter"
    "pinentry-.*"
    "org\\.gnome\\.Settings"
    "nm-connection-editor"
    "blueman-manager"
    "pavucontrol"
    "org\\.pulseaudio\\.pavucontrol"
    "com\\.saivert\\.pwvucontrol"
    "nwg-look"
    "zenity"
    "yad"
    "org\\.gnome\\.FileRoller"
    "file-roller"
  ];
  # Titres de dialogues (navigateurs, Electron… qui n'exposent pas de parent)
  floatTitles = builtins.concatStringsSep "|" [
    "Open File.*"
    "Save File.*"
    "Save As.*"
    "Open Folder.*"
    "Select a File.*"
    "File Upload.*"
    "About .*"
    "Preferences"
    "Settings"
  ];
in ''
  # >>> look macOS Tahoe (généré depuis home/macos/hyprland-look.nix)
  general {
    # Pavage classique de Hyprland (choix de l'utilisateur) avec l'apparence de
    # Tahoe : marges de 5 px entre fenêtres, 10 px autour (en plus des zones
    # réservées de la barre des menus et du Dock)
    gaps_in = 5
    gaps_out = 10
    # Liseré d'un pixel : clair sur les fenêtres sombres de Tahoe (mode clair :
    # liseré noir ~20 %, réappliqué par macos-appearance)
    border_size = 1
    col.active_border = rgba(ffffff24)
    col.inactive_border = rgba(ffffff14)
    # Redimensionnement depuis les bords, comme sur Mac
    resize_on_border = true
    extend_border_grab_area = 10
    hover_icon_on_border = true
    layout = dwindle
    # Aimantation : ne concerne que les fenêtres flottantes
    # Aimantation des fenêtres entre elles et aux bords (macOS 15+)
    snap {
      enabled = true
      window_gap = 8
      monitor_gap = 8
      border_overlap = false
    }
  }

  dwindle {
    # Nouvelle fenêtre à droite / en bas, découpe conservée au redimensionnement,
    # pas de découpe selon la position du pointeur ; pseudo-pavage par le dispatcher « pseudo » (Super+Alt+P)
    preserve_split = true
    force_split = 2
    smart_split = false
    smart_resizing = true
  }

  decoration {
    # Coins « continus » (superellipse) : fenêtres à barre de titre de Tahoe
    rounding = 16
    rounding_power = 2.6
    active_opacity = 1.0
    inactive_opacity = 1.0
    dim_inactive = false
    # Ombre Tahoe (mesurée sur About This Mac) : large, diffuse et claire,
    # décalée vers le bas ; ~15 % d'assombrissement au contact du bord latéral,
    # nulle vers 40 pt. Le contour net vient du liseré, pas de l'ombre.
    # render_power 2 : décroissance douce, peu de densité près du bord.
    shadow {
      enabled = true
      range = 52
      render_power = 2
      offset = 0 14
      scale = 1.0
      color = rgba(00000028)
      color_inactive = rgba(0000001a)
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
    # Courbes Apple : amorti critique sans dépassement (ouverture, espaces), sortie rapide
    bezier = tahoe, 0.22, 1, 0.36, 1
    bezier = tahoeOut, 0.4, 0, 0.9, 0.6
    bezier = tahoeSpace, 0.2, 0.9, 0.25, 1
    # Fenêtres : ouverture = fondu + très léger zoom, sans rebond (~250 ms) ;
    # fermeture = fondu rapide (~150 ms) sans rétrécissement visible
    animation = windowsIn, 1, 2.5, tahoe, popin 95%
    animation = windowsOut, 1, 1.5, tahoeOut, popin 99%
    animation = windowsMove, 1, 3.5, tahoe
    animation = fadeIn, 1, 2.4, tahoe
    animation = fadeOut, 1, 1.5, tahoeOut
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

  # --- Fenêtres : pavage, flottantes seulement là où le Mac les fait flotter -----
  # Les fenêtres sont pavées (dwindle). Flottent, centrées : dialogues et fenêtres
  # transitoires (Hyprland les détecte déjà : parent, taille fixe), dialogues
  # modaux, sélecteur de fichiers du portail, petits utilitaires (calculatrice,
  # authentification, choix de partage d'écran…), « Get Info » du Finder,
  # incrustation vidéo. Super+W bascule pavée / flottante (macos-wm toggle-float).
  windowrule = float on, match:modal true
  windowrule = float on, match:class ^(${floatApps})$
  windowrule = center on, match:class ^(${floatApps})$
  windowrule = float on, match:title ^(${floatTitles})$
  windowrule = center on, match:title ^(${floatTitles})$
  # Sélecteur de fichiers : taille du panneau Open/Save du Mac
  windowrule = size 820 560, match:class ^(xdg-desktop-portal-gtk)$
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
  # Fenêtre inactive : titre en tertiaryLabel, feux gris (plugin). La barre garde
  # sa couleur : Tahoe ne change pas le fond de la barre de titre, et un fond
  # « backdrop » ferait une bande bicolore avec le contenu (barre d'outils GTK,
  # terminal) qui, lui, ne change pas.
  windowrule = hyprbars:title_color rgba(ffffff4d), match:focus false
  # Terminal : barre de titre de la couleur du fond, comme Terminal.app
  windowrule = hyprbars:bar_color rgb(1e1e1e), match:class ^(kitty|foot|footclient|Alacritty)$
  # Plein écran : ni coins ni ombre ni liseré
  windowrule = rounding 0, match:fullscreen true
  windowrule = no_shadow on, match:fullscreen true
  windowrule = border_size 0, match:fullscreen true
  # Dialogues GTK/portails : centrés au-dessus de leur parent
  windowrule = center on, match:modal true
  # Incrustation vidéo (Picture in Picture) : épinglée en coin, sans barre
  windowrule = float on, match:title ^(Picture-in-Picture|Picture in picture|Incrustation vidéo)$
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
  # « Get Info » et Réglages Système (largeur fixe) flottent ; la fenêtre principale
  # du Finder est pavée comme les autres apps
  windowrule = float on, match:class ^(org\.quickshell)$, match:title ^(.* Info|System Settings)$
  windowrule = center on, match:class ^(org\.quickshell)$, match:title ^(.* Info|System Settings)$

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
      # Tahoe aligne le titre à gauche (leading), juste après les feux
      bar_text_align = left
      bar_part_of_window = true
      bar_precedence_over_border = true
      bar_blur = false
      # Feux tricolores à gauche : Ø 14 pt, 9 pt d'écart, disque rouge à 9 pt du bord
      # (centre à 16 pt, liseré compris), comme sur About This Mac de Tahoe
      bar_buttons_alignment = left
      bar_padding = 8
      bar_button_padding = 9
      # Symboles visibles au survol du groupe, gris quand la fenêtre est inactive
      # (gris = voile blanc 18 % de Theme.trafficInactive sur la barre #333333)
      icon_on_hover = true
      inactive_button_color = rgb(585858)
      # Double-clic sur la barre : « Zoom » (remplit l'écran hors barre des menus/Dock)
      on_double_click = hyprctl dispatch fullscreen 1
      # hyprbars-button = fond, diamètre, symbole, action, couleur du symbole (de gauche à droite)
      # Couleurs = Theme.trafficRed/Yellow/Green du shell (relevées sur Tahoe 26)
      # Symboles (police « sans » à 9 px imposée par le plugin) : glyphes choisis au
      # banc pour leur taille à l'écran : ✕ ~6 px, ─ ~7 px, ⤡ diagonale ↖↘ comme Tahoe
      # Jaune : effet « génie » vers le Dock (macos-wm minimize -> global macos:minimize)
      # Vert : plein écran dans un nouvel espace (macos-wm fullscreen)
      hyprbars-button = rgb(ec6765), 14, ✕, hyprctl dispatch killactive, rgb(8c1a10)
      hyprbars-button = rgb(f2ca44), 14, ─, macos-wm minimize, rgb(8f5a00)
      hyprbars-button = rgb(65c466), 14, ⤡, macos-wm fullscreen, rgb(1b6a1d)
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
  # Réglages par défaut du trackpad Mac : 3 doigts horizontaux = espace voisin,
  # 3 doigts vers le haut = Mission Control, 3 doigts vers le bas = App Exposé
  # (mêmes gestes à 4 doigts, l'autre variante proposée par macOS)
  gesture = 3, horizontal, workspace
  gesture = 3, up, dispatcher, global, macos:missioncontrol
  gesture = 3, down, dispatcher, global, macos:appexpose
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
''
