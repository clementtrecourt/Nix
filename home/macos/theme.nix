# Apparence macOS Tahoe : GTK MacTahoe, icônes MacTahoe (squircles Tahoe), curseur
# macOS, police d'interface Inter (SF Pro n'est pas redistribuable), Qt via Kvantum
# MacTahoe, fonds d'écran Tahoe.
#
# Mode clair / sombre : piloté à chaud par gsettings color-scheme (Control Center du
# shell). Rien ici ne fige le mode : le thème GTK3/GTK4 suit gsettings gtk-theme,
# et macos-appearance (exec-once, cf. pkgs/macos-scripts.nix) réécrit le CSS
# libadwaita (~/.config/gtk-4.0/gtk.css), le thème Kvantum et les barres hyprbars.
# Le mode sombre n'est posé qu'à la première activation (clé encore vide).
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  macosPkgs = import ./pkgs {inherit pkgs inputs;};
  gtkTheme = "MacTahoe-Dark";
  # Vraies icônes d'apps de macOS 26, le reste hérité de MacTahoe-dark
  iconTheme = "MacTahoe-Apple-dark";
  # Taille du texte système du Mac : 13 pt ≈ Inter 10 (GTK/Qt raisonnent en points à 96 dpi)
  uiFont = {
    name = "Inter";
    size = 10;
  };
in {
  gtk = {
    enable = true;
    theme = {
      name = gtkTheme;
      package = macosPkgs.mactahoe-gtk-theme;
    };
    iconTheme = {
      name = iconTheme;
      package = macosPkgs.mactahoe-apple-icon-theme;
    };
    font = uiFont;
    # Pas de gtk-application-prefer-dark-theme : il forcerait la variante sombre
    # (gtk-dark.css) même avec MacTahoe-Light, et casserait le mode clair.
    gtk3.extraConfig = {
      # Boutons de fenêtre à gauche, dans l'ordre du Mac
      gtk-decoration-layout = "close,minimize,maximize:";
    };
    gtk4 = {
      # ~/.config/gtk-4.0/gtk.css (import du thème pour libadwaita) n'est PAS géré
      # ici : macos-appearance l'écrit selon le mode clair / sombre courant.
      theme = null;
      extraConfig.gtk-decoration-layout = "close,minimize,maximize:";
    };
  };

  dconf.settings = {
    # color-scheme et gtk-theme : réglés par le shell (cf. activation ci-dessous)
    "org/gnome/desktop/interface" = {
      icon-theme = iconTheme;
      cursor-theme = config.home.pointerCursor.name;
      font-name = "${uiFont.name} ${toString uiFont.size}";
      document-font-name = "${uiFont.name} ${toString uiFont.size}";
      monospace-font-name = "JetBrains Mono 11";
      font-antialiasing = "grayscale";
      font-hinting = "slight";
    };
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "close,minimize,maximize:";
      titlebar-font = "${uiFont.name} Semi-Bold ${toString uiFont.size}";
    };
  };

  # Mode sombre par défaut, posé seulement si l'utilisateur n'a encore rien choisi :
  # une activation home-manager ne doit pas annuler le choix fait dans le Control Center.
  home.activation.macosAppearanceDefaults = lib.hm.dag.entryAfter ["dconfSettings"] ''
    if [[ -v DBUS_SESSION_BUS_ADDRESS ]]; then dbusRun=""; else
      dbusRun="${pkgs.dbus}/bin/dbus-run-session --dbus-daemon=${pkgs.dbus}/bin/dbus-daemon"
    fi
    if [ -z "$($dbusRun ${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/color-scheme)" ]; then
      run $dbusRun ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
      run $dbusRun ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/gtk-theme "'${gtkTheme}'"
    fi
  '';

  # Curseur macOS (apple-cursor)
  home.pointerCursor = {
    enable = true;
    name = "macOS";
    package = pkgs.apple-cursor;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
    # apple-cursor ne fournit que des curseurs XCursor (pas de manifeste hyprcursor) :
    # Hyprland les utilise directement (XCURSOR_THEME, hyprctl setcursor)
    hyprcursor.enable = false;
  };

  # Qt : Kvantum MacTahoe + qt6ct (icônes et polices). Le thème actif (MacTahoe /
  # MacTahoeDark, kvantum.kvconfig) est écrit par macos-appearance selon le mode.
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
    kvantum = {
      enable = true;
      themes = [macosPkgs.mactahoe-kde];
    };
    qt5ctSettings = {
      Appearance = {
        style = "kvantum";
        icon_theme = iconTheme;
        standard_dialogs = "xdgdesktopportal";
      };
      Fonts = {
        general = ''"Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"'';
        fixed = ''"JetBrains Mono,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"'';
      };
    };
    qt6ctSettings = {
      Appearance = {
        style = "kvantum";
        icon_theme = iconTheme;
        standard_dialogs = "xdgdesktopportal";
      };
      Fonts = {
        general = ''"Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"'';
        fixed = ''"JetBrains Mono,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"'';
      };
    };
  };

  # Polices d'interface (sans-serif -> Inter réglé au niveau système, cf. modules/common.nix)
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      sansSerif = ["Inter"];
      serif = ["IBM Plex Serif"];
      monospace = ["JetBrains Mono" "IBM Plex Mono"];
      emoji = ["Noto Color Emoji"];
    };
  };

  # Icône Zen Browser (l'entrée .desktop réclame « zen-beta », absent des thèmes)
  xdg.dataFile."icons/hicolor/scalable/apps/zen-beta.svg".source = "${macosPkgs.mactahoe-icon-theme}/share/icons/MacTahoe/apps/scalable/zen-browser.svg";

  home.packages = [
    pkgs.inter
    macosPkgs.mactahoe-kde # fonds d'écran Tahoe (share/backgrounds/MacTahoe)
    pkgs.sound-theme-freedesktop
  ];
}
