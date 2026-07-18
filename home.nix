{ config, pkgs, ... }:

{
  home.username = "clem";
  home.homeDirectory = "/home/clem";
  home.stateVersion = "26.05";

  # Symlinks vers ~/Dot — le dépôt git reste la seule source de vérité.
  # mkOutOfStoreSymlink crée un lien symbolique réel (pas une copie dans le store).
  home.file = {
    # Fish
    ".config/fish/config.fish".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/fish/config.fish";
    ".config/fish/fish_variables".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/fish/fish_variables";
    ".config/fish/functions".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/fish/functions";

    # Kitty
    ".config/kitty/kitty.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/kitty/kitty.conf";
    ".config/kitty/themes".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/kitty/themes";
    # current-theme.conf est géré par Noctalia (post_hook template-apply.sh kitty)
    # Ne pas le mettre ici pour éviter le conflit avec le symlink relatif de Noctalia.

    # Starship
    ".config/starship.toml".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/starship.toml";

    # Neovim (sous-dépôt git indépendant)
    ".config/nvim".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/nvim";

    # Mango WM
    ".config/mango/config.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/mango/config.conf";
    ".config/mango/bind.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/mango/bind.conf";
    ".config/mango/env.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/mango/env.conf";
    ".config/mango/keyboard.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/mango/keyboard.conf";
    ".config/mango/monitor.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/mango/monitor.conf";
    # mango/noctalia.conf est généré automatiquement par Noctalia, pas géré ici.
    ".config/mango/rule.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/mango/rule.conf";
    ".config/mango/tag.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/mango/tag.conf";

    # Tmux
    ".tmux.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/home/clem/Dot/.tmux.conf";
  };
  programs.git = {
  enable = true;
  userName = "clementtrecourt"; # ton nom
  userEmail = "clementt.pro@protonmail.com";
  settings = {
    init.defaultBranch = "main";
  };
};
  # Packages exclusivement liés à l'utilisateur clem
  home.packages = with pkgs; [
    tree
    ludusavi
    eza
    flatpak
    brave
    nitch
  ];
}
