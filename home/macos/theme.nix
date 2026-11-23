# Apparence macOS Tahoe (mode sombre) : GTK MacTahoe, icônes MacTahoe (squircles
# Tahoe), curseur macOS, police d'interface Inter (SF Pro n'est pas redistribuable),
# Qt via Kvantum MacTahoe, fonds d'écran Tahoe.
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
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      # Boutons de fenêtre à gauche, dans l'ordre du Mac
      gtk-decoration-layout = "close,minimize,maximize:";
    };
    # libadwaita : importe le CSS gtk-4.0 du thème dans ~/.config/gtk-4.0/gtk.css
    gtk4 = {
      theme = {
        name = gtkTheme;
        package = macosPkgs.mactahoe-gtk-theme;
      };
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-decoration-layout = "close,minimize,maximize:";
      };
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = gtkTheme;
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

  # Curseur macOS (apple-cursor)
  home.pointerCursor = {
    enable = true;
    name = "macOS";
    package = pkgs.apple-cursor;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor = {
      enable = true;
      size = 24;
    };
  };

  # Qt : Kvantum MacTahoe sombre + qt6ct (icônes et polices)
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
    kvantum = {
      enable = true;
      themes = [macosPkgs.mactahoe-kde];
      settings.General.theme = "MacTahoeDark";
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
