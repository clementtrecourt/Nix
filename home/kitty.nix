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
    # Couleurs : thème kitty de DMS, puis par-dessus un thème tiré de la palette
    # Material de DMS (voir kitty-dms-material plus bas). Un include absent est
    # ignoré par kitty : dank-theme.conf sert alors de repli.
    extraConfig = ''
      include dank-theme.conf
      include dms-material.conf
    '';
  };

  # Le thème kitty de DMS (dank16) garde un rouge, un vert et un jaune fixes quel
  # que soit le fond d'écran : seuls les bleus suivent. On regénère donc les 16
  # couleurs depuis la palette Material de DMS (dms-colors.json), pour que le
  # terminal n'affiche que des teintes du fond d'écran (sauf le rouge des erreurs).
  #
  # Rechargement : sous NixOS le processus kitty s'appelle `.kitty-wrapped`,
  # d'où le pkill explicite.
  systemd.user.paths.kitty-dms-material = {
    Unit.Description = "Surveille la palette générée par DMS";
    Path.PathChanged = ["${config.xdg.cacheHome}/dms/dms-colors.json"];
    Install.WantedBy = ["default.target"];
  };

  systemd.user.services.kitty-dms-material = {
    Unit.Description = "Génère le thème kitty depuis la palette Material de DMS et recharge kitty";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe (pkgs.writeShellApplication {
        name = "kitty-dms-material";
        runtimeInputs = [pkgs.jq pkgs.procps pkgs.coreutils];
        text = ''
          src="${config.xdg.cacheHome}/dms/dms-colors.json"
          out="${config.xdg.configHome}/kitty/dms-material.conf"

          if [[ -s "$src" ]] && jq -e '.colors[.mode // "dark"].primary' "$src" >/dev/null 2>&1; then
            mkdir -p "$(dirname "$out")"
            tmp=$(mktemp "$out.XXXXXX")
            jq -r '.colors[.mode // "dark"] |
              "# Généré par kitty-dms-material (home/kitty.nix) depuis la palette DMS",
              "foreground \(.on_surface)",
              "background \(.surface)",
              "selection_foreground \(.on_primary_container)",
              "selection_background \(.primary_container)",
              "cursor \(.primary)",
              "cursor_text_color \(.on_primary)",
              "url_color \(.tertiary)",
              "active_border_color \(.primary)",
              "inactive_border_color \(.outline_variant)",
              "bell_border_color \(.error)",
              "color0 \(.surface_container)",
              "color8 \(.outline)",
              "color1 \(.error)",
              "color9 \(.on_error_container)",
              "color2 \(.secondary)",
              "color10 \(.secondary_fixed)",
              "color3 \(.tertiary_fixed_dim)",
              "color11 \(.tertiary_fixed)",
              "color4 \(.primary)",
              "color12 \(.primary_fixed)",
              "color5 \(.tertiary)",
              "color13 \(.on_tertiary_container)",
              "color6 \(.primary_fixed_dim)",
              "color14 \(.secondary_fixed_dim)",
              "color7 \(.on_surface_variant)",
              "color15 \(.on_surface)"
            ' "$src" >"$tmp"
            mv "$tmp" "$out"
          fi

          # Code 1 = aucun kitty ouvert : pas une erreur
          pkill -USR1 -x .kitty-wrapped || true
        '';
      });
    };
    # Génère aussi le thème à l'ouverture de session
    Install.WantedBy = ["default.target"];
  };

  # Fichier vide au premier déploiement, DMS le remplit ensuite
  home.activation.createEmptyKittyDankTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p $HOME/.config/kitty
    [ -e $HOME/.config/kitty/dank-theme.conf ] || touch $HOME/.config/kitty/dank-theme.conf
  '';
}
