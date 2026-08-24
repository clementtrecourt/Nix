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


  # Symlinks vers ~/Dot — le dépôt git reste la seule source de vérité.
  home.file = {
    # Icons
    ".icons/icon_scripts".source = dot "icons/icon_scripts";

  };
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
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
      gtk4 = {
        theme = null;
        extraConfig = {
          gtk-application-prefer-dark-theme = 1;
        };
      };
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "catppuccin-mocha-blue-standard";
        icon-theme = "Papirus-Dark";
      };
    };

    # Cursor Hyprland / GTK
    home.pointerCursor = {
      enable = true; # 👈 Règle le 2ème avertissement
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

  programs.git = {
    enable = true;
    settings = {
      user.name = "clementtrecourt";
      user.email = "clementt.pro@protonmail.com";
      init.defaultBranch = "main";
    };
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  xdg.dataFile."icons/hicolor/scalable/apps/zen-beta.svg".source =
    "${pkgs.papirus-icon-theme}/share/icons/Papirus/48x48/apps/zen-browser.svg";
  # Packages utilisateur communs
  home.packages = with pkgs; [
  awww
  bat
  bibata-cursors
  brightnessctl
  btop
  cava
  cbonsai
  chafa
  cliphist
  dunst
  eza
  fastfetch
  fd
  fzf
  gammastep
  git
  tuigreet
  hyprshot
  hyprshade
  imv
  inter
  iwd
  jq
  kitty
  librewolf
  material-symbols
  matugen
  mpv
  neovim
  networkmanagerapplet
  nwg-look
  openssh
  papirus-icon-theme
  pipes
  quickshell
  ripgrep
  rofi
  rofi-calc
  rofimoji
  swayidle
  swaylock
  terminus_font_ttf
  inter
  trashy
  jetbrains-mono
  uv
  vlc
  waybar
  wl-clipboard
  yazi
  clipse
  zathura
  swaybg
  zoxide
  playerctl
  hyprlock
  zsh
  xdg-desktop-portal-gtk

  wlsunset
  pkg-config
  sqlite
  # Qt
  qt6Packages.qt6ct
  kdePackages.plasma-integration
  motrix-next
  ];
}
