{
  config,
  pkgs,
  lib,
  inputs,
  osConfig,
  ...
}: let
  kvantumTheme = pkgs.catppuccin-kvantum.override {
    accent = "blue";
    variant = "mocha";
  };

  dot = path: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dot/${path}";
in {
  imports = [
    ./niri.nix
    ./dms.nix
    ./kitty.nix
    ./fish.nix
    ./tmux.nix
    ./zed.nix
    ./zen.nix
    inputs.lazyvim.homeManagerModules.default
  ];

  home.username = "clem";
  home.homeDirectory = "/home/clem";
  home.stateVersion = "24.11";
  xdg.enable = true;

  # Nettoie les backups bloquants avant l'activation
  home.activation.cleanGtkBackups = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    rm -f $HOME/.config/gtk-4.0/gtk.css.bak $HOME/.config/gtk-3.0/gtk.css.bak
  '';
  programs.lazyvim.enable = true;
  # Active la CLI 'home-manager' et la gestion automatique du shell profile
  programs.home-manager.enable = true;

  # Symlinks vers ~/Dot (ou sources directes)
  home.file = {
    ".icons/icon_scripts".source = dot "icons/icon_scripts";
  };

  # Gestion déclarative des configs sans module natif
  xdg.configFile = {
    "cava".source = dot "cava";
    "fastfetch".source = dot "fastfetch";
    "btop".source = dot "btop";
  };

  # ============================================
  # Thèmes & Apparence
  # ============================================
  gtk = {
    enable = true;
    theme = {
      name = "catppuccin-mocha-blue-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = ["blue"];
        variant = "mocha";
      };
    };
    iconTheme = {
      # Colloid (vinceliuice) : squircles façon macOS, sobres et complets
      name = "Colloid-Dark";
      package = pkgs.colloid-icon-theme;
    };
    font = {
      name = "SF Pro Text";
      size = 11;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4 = {
      theme = null; # Nouveau standard Home Manager
      extraConfig.gtk-application-prefer-dark-theme = 1;
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      # Polices lues par GTK4/libadwaita, les portails et les apps GNOME
      font-name = "SF Pro Text 11";
      document-font-name = "SF Pro Text 11";
      monospace-font-name = "SF Mono 11";
      # Rendu selon la densité de l'écran de l'hôte (modules/display.nix)
      font-antialiasing =
        if osConfig.my.display.hidpi
        then "grayscale"
        else "rgba";
      font-hinting =
        if osConfig.my.display.hidpi
        then "none"
        else "slight";
      font-rgba-order = osConfig.my.display.subpixelOrder;
      gtk-theme = "catppuccin-mocha-blue-standard";
      icon-theme = "Colloid-Dark";
    };
  };

  home.pointerCursor = {
    enable = true;
    name = "capitaine-cursors";
    package = pkgs.capitaine-cursors;
    size = 24;
    gtk.enable = true;
  };

  qt = {
    enable = true;
    style.name = "kvantum";
    platformTheme.name = "qt6ct";
  };

  # Polices et icônes Qt : qt6ct.conf reste un fichier normal car DMS y écrit la palette
  # (sed) ; on n'impose que les polices et le thème d'icônes à chaque activation.
  home.activation.qt6ctFonts = lib.hm.dag.entryAfter ["writeBoundary"] (let
    conf = "${config.xdg.configHome}/qt6ct/qt6ct.conf";
    set = key: value: "run ${pkgs.crudini}/bin/crudini --ini-options=nospace --set \"${conf}\" Fonts ${key} '\"${value},11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\"'";
  in ''
    run mkdir -p "$(dirname "${conf}")"
    run touch "${conf}"
    ${set "general" "SF Pro Text"}
    ${set "fixed" "SF Mono"}
    run ${pkgs.crudini}/bin/crudini --ini-options=nospace --set "${conf}" Appearance icon_theme Colloid-Dark
  '');

  # ============================================
  # Programmes gérés nativement par Home Manager
  # ============================================
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "clementtrecourt";
        email = "clementt.pro@protonmail.com";
      };
      init = {
        defaultBranch = "main";
      };
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "y";

    settings = {
      opener = {
        image = [
          {
            run = ''imv "$@"'';
            orphan = true;
            for = "unix";
            desc = "imv";
          }
        ];
      };
      # On utilise prepend_rules pour être PRIORITAIRE sur les presets Yazi
      open = {
        prepend_rules = [
          {
            mime = "image/*";
            use = ["image"];
          }
        ];
      };
    };
  };

  programs.bat.enable = true;
  programs.zoxide.enable = true;
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/png" = ["imv.desktop"];
      "image/jpeg" = ["imv.desktop"];
      "image/gif" = ["imv.desktop"];
      "image/webp" = ["imv.desktop"];
      "image/bmp" = ["imv.desktop"];
      "image/tiff" = ["imv.desktop"];
      "image/svg+xml" = ["imv.desktop"];
      "image/avif" = ["imv.desktop"];
      "image/heic" = ["imv.desktop"];
      "image/jxl" = ["imv.desktop"];
    };
  };

  # Zen (beta) annonce l'icône "zen-beta", absente des thèmes : on lui donne celle de Colloid
  xdg.dataFile."icons/hicolor/scalable/apps/zen-beta.svg".source = "${pkgs.colloid-icon-theme}/share/icons/Colloid/apps/scalable/app.zen_browser.zen.svg";

  # ============================================
  # Packages utilisateur (sans doublons)
  # ============================================
  home.packages = with pkgs; [
    # Outils CLI & système
    bibata-cursors
    brightnessctl
    cbonsai
    chafa
    fd
    fzf
    imv
    iwd
    jq
    mpv
    nwg-look
    openssh
    pipes
    playerctl
    ripgrep
    trashy
    uv
    vlc
    wl-clipboard
    zathura
    # Polices (le reste de la typo est géré au niveau système : modules/fonts.nix)
    material-symbols

    # Utilitaires & Dev
    pkg-config
    sqlite
    librewolf
    rayburst

    # Qt & Intégration
    qt6Packages.qt6ct
    kdePackages.plasma-integration
    xdg-desktop-portal-gtk
  ];
}
