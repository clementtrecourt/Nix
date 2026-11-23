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
      name = "JetBrainsMonoNF-Regular";
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

      # Fenêtre & Apparence (façon Terminal.app : 80×24, opaque, barre de titre hyprbars)
      remember_window_size = "no";
      initial_window_width = "80c";
      initial_window_height = "24c";
      window_padding_width = "4 6";
      hide_window_decorations = "yes";
      background_opacity = "1.0";
      confirm_os_window_close = 0;
      enable_audio_bell = "no";
      scrollback_lines = 2000;
      wheel_scroll_min_lines = 1;
      dynamic_background_opacity = "yes";
    };

    # Raccourcis clavier
    keybindings = {
      # Vos raccourcis existants...
      "ctrl+shift+left" = "neighboring_window left";
      "ctrl+shift+right" = "neighboring_window right";
      "ctrl+shift+o" = "set_background_opacity 1.0";
      "ctrl+shift+u" = "set_background_opacity 0.80";
    };

    # Couleurs du profil « Basique » de Terminal.app en mode sombre
    extraConfig = ''
      foreground #ffffff
      background #1e1e1e
      selection_foreground none
      selection_background #3f638b
      cursor #a6a6a6
      cursor_text_color background
      url_color #4ea1ff
      active_border_color #5a5a5a
      inactive_border_color #333333
      tab_bar_background #1e1e1e
      active_tab_foreground #ffffff
      active_tab_background #3a3a3c
      inactive_tab_foreground #9a9a9e
      inactive_tab_background #1e1e1e

      # Palette ANSI de Terminal.app
      color0  #000000
      color1  #c23621
      color2  #25bc24
      color3  #adad27
      color4  #492ee1
      color5  #d338d3
      color6  #33bbc8
      color7  #cbcccd
      color8  #818383
      color9  #fc391f
      color10 #31e722
      color11 #eaec23
      color12 #5833ff
      color13 #f935f8
      color14 #14f0f0
      color15 #e9ebeb
    '';
  };
}
