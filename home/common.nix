{ config, pkgs, lib, inputs, ... }:

let
  kvantumTheme = pkgs.catppuccin-kvantum.override {
    accent = "blue";
    variant = "mocha";
  };

  dot = path: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dot/${path}";
in
{
  imports = [
    ./noctalia.nix
    ./mango.nix
    ./kitty.nix
    ./fish.nix
    ./tmux.nix
    ./zed.nix
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
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    Unit = {
      Description = "Polkit GNOME Authentication Agent";
      After = [ "graphical-session-pre.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

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
        accents = [ "blue" ];
        variant = "mocha";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
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
      gtk-theme = "catppuccin-mocha-blue-standard";
      icon-theme = "Papirus-Dark";
    };
  };

  home.pointerCursor = {
    enable = true;
    name = "capitaine-cursors";
    package = pkgs.capitaine-cursors;
    size = 24;
    gtk.enable = true;
    hyprcursor.enable = true;
  };

  qt = {
    enable = true;
    style.name = "kvantum";
    platformTheme.name = "qt6ct";
  };

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
            { mime = "image/*"; use = [ "image" ]; }
          ];
        };
      };
    };

  programs.bat.enable = true;
  programs.zoxide.enable = true;
  xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "image/png" = [ "imv.desktop" ];
        "image/jpeg" = [ "imv.desktop" ];
        "image/gif" = [ "imv.desktop" ];
        "image/webp" = [ "imv.desktop" ];
        "image/bmp" = [ "imv.desktop" ];
        "image/tiff" = [ "imv.desktop" ];
        "image/svg+xml" = [ "imv.desktop" ];
        "image/avif" = [ "imv.desktop" ];
        "image/heic" = [ "imv.desktop" ];
        "image/jxl" = [ "imv.desktop" ];
      };
    };

  xdg.dataFile."icons/hicolor/scalable/apps/zen-beta.svg".source =
    "${pkgs.papirus-icon-theme}/share/icons/Papirus/48x48/apps/zen-browser.svg";

  # ============================================
  # Packages utilisateur (sans doublons)
  # ============================================
  home.packages = with pkgs; [
    # Outils CLI & système
    awww
    bibata-cursors
    brightnessctl
    cbonsai
    chafa
    cliphist
    clipse
    dunst
    fd
    fzf
    gammastep
    hyprshot
    hyprshade
    hyprlock
    imv
    iwd
    jq
    matugen
    mpv
    networkmanagerapplet
    nwg-look
    openssh
    pipes
    playerctl
    quickshell
    ripgrep
    rofi
    rofi-calc
    rofimoji
    swayidle
    swaylock
    swaybg
    trashy
    tuigreet
    uv
    vlc
    waybar
    wl-clipboard
    wlsunset
    zathura
    imv

    # Polices
    inter
    jetbrains-mono
    material-symbols
    terminus_font_ttf

    # Utilitaires & Dev
    pkg-config
    sqlite
    librewolf
    motrix-next

    # Qt & Intégration
    qt6Packages.qt6ct
    kdePackages.plasma-integration
    xdg-desktop-portal-gtk
  ];
}
