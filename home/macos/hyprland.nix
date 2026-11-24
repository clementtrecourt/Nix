# Hyprland façon macOS Tahoe : fenêtres flottantes centrées, barres de titre à
# feux tricolores (hyprbars), coins arrondis continus, grande ombre douce,
# flou des surfaces du shell (macos-*), animations et gestes du Mac, raccourcis Cmd.
#
# Format : hyprlang (hyprland.conf). Le format Lua de Hyprland 0.56 change la syntaxe
# de `hyprctl dispatch` (attend du Lua : hl.dsp…) ; or Quickshell 0.3.1
# (Hyprland.dispatch), le shell (services/Windows.qml) et les boutons hyprbars
# envoient des dispatchers classiques. À migrer quand Quickshell suivra.
#
# Le bloc « look » vit dans hyprland-look.nix : même source pour la prod et pour le
# banc de test imbriqué (dev/nested.sh), qui reste ainsi fidèle.
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
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  playerctl = "${pkgs.playerctl}/bin/playerctl";

  # Rendu (réglages visuels, règles de fenêtres, hyprbars, animations, saisie, gestes) :
  # source unique partagée avec le banc de test (dev/nested.sh), sans chemin du store
  look = import ./hyprland-look.nix;
  settingsConf = "${config.xdg.configHome}/hypr/macos-settings.conf";

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
          # Pavée <-> flottante (flottante : centrée, taille confortable)
          "SUPER, W, exec, ${wm} toggle-float"
          "SUPER, F, fullscreen, 0"
          # ---- Pavage (dwindle) ----
          # Focus : Super+Alt+flèches ; déplacer / échanger : Super+Alt+Maj+flèches
          "SUPER ALT, Left, movefocus, l"
          "SUPER ALT, Right, movefocus, r"
          "SUPER ALT, Up, movefocus, u"
          "SUPER ALT, Down, movefocus, d"
          "SUPER ALT SHIFT, Left, movewindow, l"
          "SUPER ALT SHIFT, Right, movewindow, r"
          "SUPER ALT SHIFT, Up, movewindow, u"
          "SUPER ALT SHIFT, Down, movewindow, d"
          # Sens de la découpe (horizontal / vertical) et pseudo-pavage
          "SUPER, J, layoutmsg, togglesplit"
          "SUPER ALT, P, pseudo"
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
        # Luminosité : le shell choisit brightnessctl (dalle interne) ou ddcutil
        # (écrans externes, DDC/CI) et affiche le HUD
        ", XF86MonBrightnessUp, exec, ${qs} osd brightnessUp"
        ", XF86MonBrightnessDown, exec, ${qs} osd brightnessDown"
        ", XF86KbdBrightnessUp, exec, ${qs} osd keyboardUp"
        ", XF86KbdBrightnessDown, exec, ${qs} osd keyboardDown"
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

    # Réglages de l'utilisateur écrits par l'app Réglages Système du shell (clavier,
    # souris, trackpad, écrans) : chargés EN DERNIER pour l'emporter sur ce qui précède.
    # Fichier non géré par home-manager (cf. activation ci-dessous).
    extraConfig =
      look
      + ''

        source = ${settingsConf}
      '';
  };

  # Le fichier sourcé doit exister dès le premier démarrage (sinon erreur de config) ;
  # jamais réécrit : il appartient à l'app Réglages Système
  home.activation.macosSettingsConf = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -e ${settingsConf} ]; then
      run mkdir -p "$(dirname ${settingsConf})"
      run touch ${settingsConf}
    fi
  '';

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
      # Pas de minuteries ici : les délais (verrouillage 10 min, extinction de
      # l'écran 15 min par défaut) sont gérés par le shell et réglables dans
      # System Settings ▸ Lock Screen ; hypridle reste le relais de
      # « loginctl lock-session » (lock_cmd) et du verrouillage avant la veille.
    };
  };
}
