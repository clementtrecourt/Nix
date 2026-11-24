{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.kitty = {
    enable = true;

    # Police d'écriture
    # SF Mono (variante Nerd Font : icônes starship/yazi incluses), cf. modules/fonts.nix
    font = {
      name = "SFMono Nerd Font";
      size = 13.5;
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
      background_opacity = "0.7";
      confirm_os_window_close = 0;
      enable_audio_bell = "no";
      scrollback_lines = 2000;
      wheel_scroll_min_lines = 1;
      dynamic_background_opacity = "yes";

      # Typo : graisse "macOS" (gamma 1.2, contraste +10 %) et interligne aéré
      text_composition_strategy = "1.2 10";
      modify_font = "cell_height 112%";
      disable_ligatures = "cursor";
    };

    # Raccourcis clavier
    keybindings = {
      # Vos raccourcis existants...
      "ctrl+shift+left" = "neighboring_window left";
      "ctrl+shift+right" = "neighboring_window right";
      "ctrl+shift+o" = "set_background_opacity 1.0";
      "ctrl+shift+u" = "set_background_opacity 0.80";
    };

    # Couleurs générées par DMS (thème shell -> kitty)
    extraConfig = ''
      include dank-theme.conf
    '';
  };

  # Fichier vide au premier déploiement, DMS le remplit ensuite
  home.activation.createEmptyKittyDankTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p $HOME/.config/kitty
    [ -e $HOME/.config/kitty/dank-theme.conf ] || touch $HOME/.config/kitty/dank-theme.conf
  '';
}
