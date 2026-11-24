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
  appearanceState = "${config.xdg.stateHome}/macos-appearance";
  fileChooser = {
    show-hidden = false;
    sort-column = "name";
    sort-order = "ascending";
    sort-directories-first = false;
    startup-mode = "cwd";
    clock-format = "12h";
    date-format = "regular";
    show-size-column = true;
    window-size = lib.hm.gvariant.mkTuple [820 480];
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
    # Sélecteur de fichiers GTK (portail xdg-desktop-portal-gtk, dialogues GTK3/GTK4)
    # réglé comme le panneau Open/Save du Mac : fichiers cachés masqués, tri par nom
    # (dossiers mêlés aux fichiers, comme le Finder), ouverture dans le dossier de
    # l'app et non dans « Recent », taille de panneau du Mac, heures en 12 h (US)
    "org/gtk/settings/file-chooser" = fileChooser;
    "org/gtk/gtk4/settings/file-chooser" = fileChooser;
    # Nemo (gestionnaire GTK3 resté installé) : sans barre de menus dans la fenêtre
    # ni fichiers cachés, comme le Finder
    "org/nemo/window-state" = {
      start-with-menu-bar = false;
    };
    "org/nemo/preferences" = {
      show-hidden-files = false;
    };
  };

  # Fichiers suivant le mode clair / sombre, écrits par macos-appearance dans
  # ~/.local/state/macos-appearance et liés ici (gérés par home-manager, contenu
  # réécrit à chaud) : feux tricolores de Tahoe pour GTK3, schéma de couleurs
  # MacTahoe des apps KDE (remplacent les restes de l'ancienne config Noctalia)
  xdg.configFile = {
    "gtk-3.0/gtk.css".source = config.lib.file.mkOutOfStoreSymlink "${appearanceState}/gtk3.css";
    "kdeglobals".source = config.lib.file.mkOutOfStoreSymlink "${appearanceState}/kdeglobals";
  };
  # Les cibles existent dès l'activation (avant la première ouverture de session)
  home.activation.macosAppearanceFiles = lib.hm.dag.entryAfter ["linkGeneration" "macosAppearanceDefaults"] ''
    run ${macosPkgs.macos-appearance}/bin/macos-appearance files || true
  '';

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
  # kvantum.kvconfig appartient à macos-appearance (réécrit à chaque bascule
  # clair/sombre) : Home Manager ne doit pas le générer, sinon chaque switch
  # bute sur le fichier réécrit (« would be clobbered »)
  xdg.configFile."Kvantum/kvantum.kvconfig".enable = lib.mkForce false;

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

  # Rendu du texte sur écran 1x : antialiasing en niveaux de gris (pas de franges
  # colorées sous-pixel sur le verre translucide), hinting léger pour la netteté
  xdg.configFile."fontconfig/conf.d/99-macos-rendering.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <match target="font">
        <edit name="antialias" mode="assign"><bool>true</bool></edit>
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
        <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
        <edit name="rgba" mode="assign"><const>none</const></edit>
        <edit name="lcdfilter" mode="assign"><const>lcdnone</const></edit>
      </match>
    </fontconfig>
  '';

  # Icône Zen Browser (l'entrée .desktop réclame « zen-beta », absent des thèmes)
  xdg.dataFile."icons/hicolor/scalable/apps/zen-beta.svg".source = "${macosPkgs.mactahoe-icon-theme}/share/icons/MacTahoe/apps/scalable/zen-browser.svg";

  home.packages = [
    pkgs.inter
    macosPkgs.mactahoe-kde # fonds d'écran Tahoe (share/backgrounds/MacTahoe)
    pkgs.sound-theme-freedesktop
  ];
}
