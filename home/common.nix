{ config, pkgs, ... }:

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
  ];

  home.username = "clem";
  home.homeDirectory = "/home/clem";
  home.stateVersion = "24.11";

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
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
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
    userName = "clementtrecourt";
    userEmail = "clementt.pro@protonmail.com";
    extraConfig.init.defaultBranch = "main";
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    # Si tu as un fichier starship.toml personnalisé dans ~/Dot :
    # settings = builtins.fromTOML (builtins.readFile "${config.home.homeDirectory}/Dot/starship.toml");
  };

  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.bat.enable = true;
  programs.zoxide.enable = true;

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
    neovim
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
