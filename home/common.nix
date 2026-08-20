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
    ];
  home.username = "clem";
  home.homeDirectory = "/home/clem";
  home.stateVersion = "24.11";


  # Symlinks vers ~/Dot — le dépôt git reste la seule source de vérité.
  home.file = {
    # Fish
    ".config/fish/config.fish".source = dot "fish/config.fish";
    ".config/fish/fish_variables".source = dot "fish/fish_variables";
    ".config/fish/functions".source = dot "fish/functions";

    # Foot & Tmux
    ".config/foot/foot.ini".source = dot "foot/foot.ini";
    ".tmux.conf".source = dot ".tmux.conf";

    # Caelestia
    # ".config/caelestia/monitors".source = dot "caelestia/monitors";
    # ".config/caelestia/hypr-vars.lua".source = dot "caelestia/hypr-vars.lua";
    # ".config/caelestia/hypr-user.lua".source = dot "caelestia/hypr-user.lua";
    # ".config/caelestia/monitors.lua".source = dot "caelestia/monitors.lua";
    # ".config/caelestia/monitors-work.lua".source = dot "caelestia/monitors-work.lua";
    # ".config/caelestia/shell.json".source = dot "caelestia/shell.json";
    # ".config/caelestia/user-config.fish".source = dot "caelestia/user-config.fish";
    # Mango
    ".config/mango".source = dot "mango";
    # Rofi
    ".config/rofi/".source = dot "rofi/";
    # Scripts
    ".local/bin/".source = dot "scripts/";
    # Waybar
    ".config/waybar".source = dot "waybar";
    # Quickshell
    ".config/quickshell/".source = dot "quickshell";
    # Matugen
    ".config/matugen/".source = dot "matugen/";
    # Kitty
    ".config/kitty/".source = dot "kitty/";
    # Icons
    ".icons/icon_scripts".source = dot "icons/icon_scripts";
    # Swaylock
    ".config/swaylock/".source = dot "swaylock";
    # Fastfetch
    ".config/fastfetch/".source = dot "fastfetch/";
    # Hyprlock
    ".config/hyprlock/".source = dot "hyprlock/";
    # Dunst
    ".config/dunst/".source = dot "dunst/";
    # Hyprland
    ".config/hypr/hyprland".source = dot "hypr/hyprland";
    ".config/hypr/utils".source = dot "hypr/utils";
    ".config/hypr/hyprland.lua".source = dot "hypr/hyprland.lua";
    ".config/hypr/hyprshade.toml".source = dot "hypr/hyprshade.toml";
    ".config/hypr/variables.lua".source = dot "hypr/variables.lua";
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
  greetd
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
  niri
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
