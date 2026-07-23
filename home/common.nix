{ config, pkgs, ... }:

{
  home.username = "clem";
  home.homeDirectory = "/home/clem";
  home.stateVersion = "26.05";

  # Symlinks vers ~/Dot — le dépôt git reste la seule source de vérité.
  home.file = {
    # # Fish
    # ".config/fish/config.fish".source =
    #   config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/fish/config.fish";
    # ".config/fish/fish_variables".source =
    #   config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/fish/fish_variables";
    # ".config/fish/functions".source =
    #   config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/fish/functions";
    #
    # # Kitty
    # ".config/kitty/kitty.conf".source =
    #   config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/kitty/kitty.conf";
    # ".config/kitty/themes".source =
    #   config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/kitty/themes";
    # # Tmux
    ".tmux.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/.tmux.conf";
  };

  programs.git = {
  enable = true;
  settings = {
    user.name = "clementtrecourt";
    user.email = "clementt.pro@protonmail.com";
    init.defaultBranch = "main";
  };
};
  home.sessionVariables = {
   XDG_DATA_DIRS = "$HOME/.local/share:/run/current-system/sw/share:/etc/profiles/per-user/$USER/share";
  };

  # Packages utilisateur communs (hors gaming)
  home.packages = with pkgs; [
    tree
    eza
    flatpak
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
