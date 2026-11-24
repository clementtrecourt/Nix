# Kitty façon Terminal.app (profil « Basique ») : SF Mono 11 pt -> JetBrains Mono à la
# même taille à l'écran, fenêtre 80×24, couleurs du profil clair / sombre qui suivent
# le mode du système (fichiers *-theme.auto.conf, via le portail Settings).
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Palette ANSI de Terminal.app (identique en clair et en sombre)
  ansi = ''
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
  dark =
    ''
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
    ''
    + ansi;
  light =
    ''
      foreground #000000
      background #ffffff
      selection_foreground none
      selection_background #b3d7ff
      cursor #929292
      cursor_text_color background
      url_color #0068da
      active_border_color #b0b0b0
      inactive_border_color #e0e0e0
      tab_bar_background #f2f2f2
      active_tab_foreground #000000
      active_tab_background #ffffff
      inactive_tab_foreground #6e6e73
      inactive_tab_background #e6e6e6
    ''
    + ansi;
in {
  programs.kitty = {
    enable = true;

    # Police : Terminal.app « Basique » = SF Mono 11 pt, soit 11 px logiques.
    # kitty compte en points typographiques à 96 dpi : 11 × 72/96 = 8,25.
    # (Cmd+= / Cmd+- / Cmd+0 changent la taille, comme dans Terminal)
    font = {
      name = "JetBrainsMonoNF-Regular";
      size = 8.25;
    };

    # Configuration générale
    settings = {
      # Curseur de Terminal.app (profil Basique) : bloc fixe, sans clignotement ni
      # traînée animée ; l'intégration shell ne le change pas en barre
      cursor_shape = "block";
      cursor_blink_interval = 0;
      cursor_trail = 0;
      shell_integration = "no-cursor";

      # Onglets sous la barre de titre, comme dans Terminal (et non en bas)
      tab_bar_edge = "top";
      tab_bar_style = "separator";
      tab_separator = "\" │ \"";

      # Performance / Latence
      repaint_delay = 8;
      input_delay = 0;

      # Fenêtre & Apparence (façon Terminal.app : 80×24, opaque)
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
      # Touches Cmd du Mac (macos-wm key les envoie en Ctrl+Maj aux terminaux) :
      # Cmd+0 taille par défaut, Cmd+K effacer l'historique, Cmd+F rechercher
      "ctrl+shift+0" = "change_font_size all 0";
      "ctrl+shift+k" = "clear_terminal to_cursor active";
      "ctrl+shift+f" = "show_scrollback";
    };

    # Couleurs par défaut (sombre) ; remplacées à chaud selon le mode du système
    extraConfig = dark;
  };

  # Thèmes automatiques (kitty ≥ 0.38) : profil « Basique » clair / sombre de Terminal
  xdg.configFile = {
    "kitty/dark-theme.auto.conf".text = dark;
    "kitty/light-theme.auto.conf".text = light;
    "kitty/no-preference-theme.auto.conf".text = light;
  };
}
