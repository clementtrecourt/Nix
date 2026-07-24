{ config, pkgs, ... }:
let
  kvantumTheme = pkgs.catppuccin-kvantum.override {
    accent = "blue";     # pick any of: blue, flamingo, green, lavender, maroon, mauve, peach, pink, red, rosewater, sapphire, sky, teal, yellow
    variant = "mocha";
  };
in
{
  imports = [
      ./caelestia.nix
  ];
  home.username = "clem";
  home.homeDirectory = "/home/clem";
  home.stateVersion = "26.05";
  # Symlinks vers ~/Dot — le dépôt git reste la seule source de vérité.

  home.file = {
    # Fish
    ".config/fish/config.fish".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/fish/config.fish";
    ".config/fish/fish_variables".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/fish/fish_variables";
    ".config/fish/functions".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/fish/functions";

    # # Foot
    ".config/foot/foot.ini".source =
     config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/foot/foot.ini";
    # # Tmux
    ".tmux.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/.tmux.conf";
    ## Caelestia
    ".config/caelestia/monitors".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/caelestia/monitors";
    ".config/caelestia/hypr-vars.lua".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/caelestia/hypr-vars.lua";
    ".config/caelestia/hypr-user.lua".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/caelestia/hypr-user.lua";
    ".config/caelestia/monitors.lua".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/caelestia/monitors.lua";
    ".config/caelestia/monitors-work.lua".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/caelestia/monitors-work.lua";
    ".config/caelestia/shell.json".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/caelestia/shell.json";
    ".config/caelestia/user-config.fish".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/caelestia/user-config.fish";


    ## Hyprland
    ".config/hypr/hyprland".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/hypr/hyprland";
    ".config/hypr/utils".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/hypr/utils";
    ".config/hypr/hyprland.lua".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/hypr/hyprland.lua";
    ".config/hypr/hyprshade.toml".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/hypr/hyprshade.toml";
    ".config/hypr/variables.lua".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/hypr/variables.lua";
  };
  qt = {
      enable = true;
      style.name = "kvantum";
      platformTheme.name = "qtct";
    };

    xdg.configFile = {
      "Kvantum/kvantum.kvconfig".text = ''
        [General]
        theme=catppuccin-mocha-blue
      '';
      "Kvantum/catppuccin-mocha-blue".source = "${kvantumTheme}/share/Kvantum/catppuccin-mocha-blue";
    };
  programs.git = {
    enable = true;
    settings = {
      user.name = "clementtrecourt";
      user.email = "clementt.pro@protonmail.com";
      init.defaultBranch = "main";
    };
  };
  # Packages utilisateur communs (hors gaming)
  home.packages = with pkgs; [
    tree
    eza
    nerd-fonts.im-writing
    firefox
    brave
    nitch
    foot
    hyprshade
    cliphist
    wl-clipboard
  ];
}
