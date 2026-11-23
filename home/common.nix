{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  dot = path: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dot/${path}";
in {
  imports = [
    ./macos # Bureau macOS Tahoe : Hyprland + shell Quickshell + thèmes MacTahoe
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
  # Agent Polkit : fourni par le shell macOS (Quickshell.Services.Polkit)

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
  # Thèmes & Apparence : voir home/macos/theme.nix (MacTahoe, curseur macOS, Inter)
  # ============================================

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

  # ============================================
  # Packages utilisateur (sans doublons)
  # ============================================
  home.packages = with pkgs; [
    # Outils CLI & système
    brightnessctl
    cbonsai
    chafa
    cliphist
    fd
    fzf
    gammastep
    imv
    iwd
    jq
    mpv
    networkmanagerapplet
    nwg-look
    openssh
    pipes
    playerctl
    quickshell
    ripgrep
    trashy
    tuigreet
    uv
    vlc
    wl-clipboard
    wlsunset
    zathura
    # Polices
    inter
    jetbrains-mono
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
