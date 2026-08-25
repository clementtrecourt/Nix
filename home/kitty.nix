{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.kitty = {
    enable = true;

    # Police d'écriture
    font = {
      name = "BlexMono Nerd Font";
      size = 15;
    };

    # Configuration générale
    settings = {
      # Curseur
      cursor_shape = "beam";
      cursor_blink_interval = "1.0";
      cursor_stop_blinking_after = 30;
      cursor_trail = 10;
      cursor_trail_start_threshold = 20;
      shell_integration = "no-cursor";

      # Performance / Latence
      repaint_delay = 8;
      input_delay = 0;

      # Fenêtre & Apparence
      remember_window_size = "no";
      window_padding_width = 10;
      hide_window_decorations = "yes";
      background_opacity = "0.65";
      dynamic_background_opacity = "no";
      confirm_os_window_close = 0;
      enable_audio_bell = "no";
      scrollback_lines = 2000;
      wheel_scroll_min_lines = 1;
    };

    # Raccourcis clavier
    keybindings = {
      # Vos raccourcis existants...
      "ctrl+shift+left" = "neighboring_window left";
      "ctrl+shift+right" = "neighboring_window right";
      # ...

      # ========================================================
      # FLASH / JUMP STYLE NEOVIM (Natif Kitty)
      # ========================================================
      # Alt + s : Flashe tous les MOTS à l'écran et copie celui choisi
      "alt+s" = "kitten hints --type word --program @";

      # Alt + f : Flashe tous les CHEMINS DE FICHIERS à l'écran et les copie
      "alt+f" = "kitten hints --type path --program @";

      # Alt + h : Flashe tous les HASH GIT (commits) à l'écran et les copie
      "alt+h" = "kitten hints --type hash --program @";

      # Alt + u : Flashe et ouvre directement les URLs dans votre navigateur
      "alt+u" = "kitten hints --type url";
    };

    # Inclusion du thème dynamique Noctalia
    extraConfig = ''
      include themes/noctalia.conf
    '';
  };

  # Crée le dossier des thèmes et le fichier vide s'il n'existe pas encore
  home.activation.createEmptyKittyNoctaliaTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p $HOME/.config/kitty/themes
    touch $HOME/.config/kitty/themes/noctalia.conf
  '';
}
