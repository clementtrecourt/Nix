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
      ./caelestia.nix
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
    ".config/caelestia/monitors".source = dot "caelestia/monitors";
    ".config/caelestia/hypr-vars.lua".source = dot "caelestia/hypr-vars.lua";
    ".config/caelestia/hypr-user.lua".source = dot "caelestia/hypr-user.lua";
    ".config/caelestia/monitors.lua".source = dot "caelestia/monitors.lua";
    ".config/caelestia/monitors-work.lua".source = dot "caelestia/monitors-work.lua";
    ".config/caelestia/shell.json".source = dot "caelestia/shell.json";
    ".config/caelestia/user-config.fish".source = dot "caelestia/user-config.fish";

    # Hyprland
    ".config/hypr/hyprland".source = dot "hypr/hyprland";
    ".config/hypr/utils".source = dot "hypr/utils";
    ".config/hypr/hyprland.lua".source = dot "hypr/hyprland.lua";
    ".config/hypr/hyprshade.toml".source = dot "hypr/hyprshade.toml";
    ".config/hypr/variables.lua".source = dot "hypr/variables.lua";
  };
  dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "Adwaita-dark";
        icon-theme = "Papirus-Dark";
      };
    };
    gtk = {
      enable = true;

      theme = {
        name = "Adwaita-dark";
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
        theme = null; # 👈 Règle le 1er avertissement
        extraConfig = {
          gtk-application-prefer-dark-theme = 1;
        };
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
    platformTheme.name = "qtct";
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
  # Packages utilisateur communs
  home.packages = with pkgs; [
    tree
    eza
    firefox
    brave
    nitch
    foot
    hyprshade
    material-symbols
    cliphist
    matugen
    wl-clipboard
  ];
}
