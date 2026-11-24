# Kitty en verre, comme les surfaces du shell : fond translucide flouté par Hyprland
# (decoration.blur, même flou que les matériaux macos-*), texte à 14 px, couleurs
# tirées du fond d'écran (matugen, Material You) en clair comme en sombre.
#
# Les couleurs vivent dans les fichiers *-theme.auto.conf de kitty (≥ 0.38), que
# kitty applique selon le mode du système (portail Settings). Ils ne sont PAS gérés
# par home-manager : kitty-wallpaper-colors les réécrit à chaque changement du fond
# (~/.config/macos-shell/wallpaper, celui du shell) puis kitty les relit à chaud
# (SIGUSR1). Sans image, le fond procédural « Tahoe » sert de source (bleu Tahoe).
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Opacité du fond : celle des menus du shell (Theme.menuBackground ≈ 0,62)
  opacity = "0.62";

  # Couleurs ANSI : couleurs système de macOS (mode sombre), harmonisées avec la
  # couleur source du fond d'écran (blend matugen) pour rester dans sa teinte
  matugenConfig = pkgs.writeText "kitty-matugen.toml" ''
    [config]
    [config.custom_colors]
    red = { color = "#ff453a", blend = true }
    green = { color = "#32d74b", blend = true }
    yellow = { color = "#ffd60a", blend = true }
    blue = { color = "#0a84ff", blend = true }
    magenta = { color = "#bf5af2", blend = true }
    cyan = { color = "#64d2ff", blend = true }
    [templates]
  '';

  # JSON de matugen -> fichier de couleurs kitty pour le mode $m (dark | light)
  toKitty = pkgs.writeText "kitty-colors.jq" ''
    . as $root
    | def c($n): $root.colors[$n][$m].color;
    def ansi($n; $normal; $bright): "color\($n) \(c($normal))\ncolor\($n + 8) \(c($bright))";
    [
      "# Généré par kitty-wallpaper-colors (mode \($m)) : ne pas modifier",
      "foreground \(c("on_surface"))",
      "background \(c("surface"))",
      "selection_foreground \(c("on_primary_container"))",
      "selection_background \(c("primary_container"))",
      "cursor \(c("primary"))",
      "cursor_text_color \(c("on_primary"))",
      "cursor_trail_color \(c("primary"))",
      "url_color \(c("tertiary"))",
      "active_border_color \(c("primary"))",
      "inactive_border_color \(c("outline_variant"))",
      "bell_border_color \(c("error"))",
      "active_tab_foreground \(c("on_secondary_container"))",
      "active_tab_background \(c("secondary_container"))",
      "inactive_tab_foreground \(c("on_surface_variant"))",
      "inactive_tab_background \(c("surface_container"))",
      "mark1_foreground \(c("on_primary"))",
      "mark1_background \(c("primary"))",
      (if $m == "dark" then
        "color0 \(c("surface_container_highest"))\ncolor8 \(c("outline"))\ncolor7 \(c("on_surface_variant"))\ncolor15 \(c("on_surface"))"
      else
        "color0 \(c("on_surface"))\ncolor8 \(c("outline"))\ncolor7 \(c("outline_variant"))\ncolor15 \(c("surface_container_low"))"
      end),
      # Sombre : ton 80 (normal) / 90 (vif) ; clair : ton 40 pour les deux
      ([["red", 1], ["green", 2], ["yellow", 3], ["blue", 4], ["magenta", 5], ["cyan", 6]][]
        | ansi(.[1]; .[0]; if $m == "dark" then "on_\(.[0])_container" else .[0] end))
    ] | join("\n")
  '';

  kitty-wallpaper-colors = pkgs.writeShellApplication {
    name = "kitty-wallpaper-colors";
    runtimeInputs = with pkgs; [coreutils jq matugen procps];
    text = ''
      # kitty-wallpaper-colors [apply | watch]
      #   apply : régénère les couleurs de kitty d'après le fond d'écran actuel
      #   watch : idem, puis suit les changements du fond (sondage toutes les 3 s,
      #           comme le shell : un lien symbolique remplacé échappe à inotify)
      conf="''${XDG_CONFIG_HOME:-$HOME/.config}"
      link="''${MACOS_SHELL_CONFIG:-$conf/macos-shell}/wallpaper"
      out="$conf/kitty"
      # Bleu du fond procédural Tahoe (shell/session/shaders/tahoe.frag, bandC)
      tahoe="#0a63d0"

      # Identité du fond : chemin réel + date de modification
      key() {
        if [ -e "$link" ]; then
          printf '%s:%s' "$(readlink -f "$link")" "$(stat -L -c %Y "$link")"
        else
          echo tahoe
        fi
      }

      scheme() {
        local args=(-t scheme-tonal-spot -c ${matugenConfig} --dry-run -q -j hex)
        if [ -e "$link" ] && matugen image "$(readlink -f "$link")" --source-color-index 0 "''${args[@]}"; then
          return 0
        fi
        matugen color hex "$tahoe" "''${args[@]}"
      }

      # Écriture atomique (remplace aussi un ancien lien vers le store)
      put() {
        printf '%s\n' "$2" >"$1.tmp"
        mv -f "$1.tmp" "$1"
      }

      apply() {
        local json dark light
        json="$(scheme)" || return 0
        dark="$(jq -r --arg m dark -f ${toKitty} <<<"$json")"
        light="$(jq -r --arg m light -f ${toKitty} <<<"$json")"
        mkdir -p "$out"
        put "$out/dark-theme.auto.conf" "$dark"
        put "$out/light-theme.auto.conf" "$light"
        put "$out/no-preference-theme.auto.conf" "$light"
        # Les kitty ouverts relisent leur configuration (et ces fichiers)
        pkill -USR1 -x kitty || true
      }

      case "''${1:-apply}" in
        apply) apply ;;
        watch)
          last=""
          while :; do
            k="$(key)"
            if [ "$k" != "$last" ]; then
              apply
              last="$k"
            fi
            sleep 3
          done
          ;;
        *)
          echo "usage : kitty-wallpaper-colors [apply | watch]" >&2
          exit 2
          ;;
      esac
    '';
  };
in {
  home.packages = [kitty-wallpaper-colors];

  programs.kitty = {
    enable = true;

    # 14 px logiques. kitty compte en points typographiques à 96 dpi :
    # 14 × 72/96 = 10,5. (Cmd+= / Cmd+- / Cmd+0 changent la taille, comme dans Terminal)
    font = {
      name = "JetBrainsMonoNF-Regular";
      size = 10.5;
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

      # Fenêtre : 80×24 comme Terminal, en verre. Le fond translucide est flouté
      # par Hyprland ; le liseré clair et les coins viennent aussi du compositeur.
      remember_window_size = "no";
      initial_window_width = "80c";
      initial_window_height = "24c";
      window_padding_width = "6 8";
      hide_window_decorations = "yes";
      background_opacity = opacity;
      dynamic_background_opacity = "yes";
      confirm_os_window_close = 0;
      enable_audio_bell = "no";
      scrollback_lines = 2000;
      wheel_scroll_min_lines = 1;
    };

    # Raccourcis clavier
    keybindings = {
      "ctrl+shift+left" = "neighboring_window left";
      "ctrl+shift+right" = "neighboring_window right";
      # Opaque / retour au verre
      "ctrl+shift+o" = "set_background_opacity 1.0";
      "ctrl+shift+u" = "set_background_opacity ${opacity}";
      # Touches Cmd du Mac (macos-wm key les envoie en Ctrl+Maj aux terminaux) :
      # Cmd+0 taille par défaut, Cmd+K effacer l'historique, Cmd+F rechercher
      "ctrl+shift+0" = "change_font_size all 0";
      "ctrl+shift+k" = "clear_terminal to_cursor active";
      "ctrl+shift+f" = "show_scrollback";
    };

    # Couleurs de repli si le système ne signale aucun mode (fichiers générés)
    extraConfig = ''
      globinclude dark-theme.auto.conf
    '';
  };

  # Premières couleurs dès l'activation (avant le démarrage du service)
  home.activation.kittyWallpaperColors = lib.hm.dag.entryAfter ["linkGeneration"] ''
    run ${kitty-wallpaper-colors}/bin/kitty-wallpaper-colors apply || true
  '';

  # Suit les changements de fond d'écran pendant la session
  systemd.user.services.kitty-wallpaper-colors = {
    Unit = {
      Description = "Couleurs de kitty d'après le fond d'écran";
      PartOf = ["hyprland-session.target"];
      After = ["hyprland-session.target"];
    };
    Service = {
      Type = "exec";
      ExecStart = "${kitty-wallpaper-colors}/bin/kitty-wallpaper-colors watch";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = ["hyprland-session.target"];
  };
}
