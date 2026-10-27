{
  writeShellApplication,
  coreutils,
  findutils,
}:
# awww n'est volontairement pas dans runtimeInputs : on utilise celui de la session.
writeShellApplication {
  name = "wallpaper";
  runtimeInputs = [coreutils findutils];
  text = ''
    state=''${OSYX_STATE_DIR:-''${XDG_STATE_HOME:-$HOME/.local/state}/osyx}
    dirs=''${OSYX_WALLPAPER_DIRS:-$HOME/Pictures/Wallpapers:$HOME/Pictures/wallpapers}

    images() {
      IFS=: read -ra arr <<< "$dirs"
      find -L "''${arr[@]}" -maxdepth 2 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) \
        2>/dev/null | sort
    }

    # Mémorise le fond et fait suivre le thème, sauf si une palette est épinglée (themes apply <nom>).
    remember() {
      img=$1
      case "$img" in /*) ;; *) img="$PWD/$img" ;; esac
      if [ ! -f "$img" ]; then
        echo "wallpaper: fichier introuvable: $img" >&2
        exit 1
      fi
      mkdir -p "$state"
      echo "$img" > "$state/wallpaper"
      if command -v themes >/dev/null 2>&1 && [ "$(themes mode 2>/dev/null || echo dynamic)" = dynamic ]; then
        themes from-wallpaper "$img" || true
      fi
    }

    set_wallpaper() {
      remember "$1"
      img=$(cat "$state/wallpaper")
      # le démon est lancé en parallèle au login : attendre qu'il réponde
      for _ in $(seq 1 40); do awww query >/dev/null 2>&1 && break; sleep 0.25; done
      awww img "$img" --transition-type fade || echo "wallpaper: awww a échoué (démon absent ?)" >&2
    }

    restore() {
      img=$(cat "$state/wallpaper" 2>/dev/null || true)
      if [ -z "$img" ] || [ ! -f "$img" ]; then
        # ancien fond Caelestia, puis première image trouvée
        img=$(cat "$HOME/.local/state/caelestia/wallpaper/path.txt" 2>/dev/null || true)
        if [ -z "$img" ] || [ ! -f "$img" ]; then img=$(images | head -n 1); fi
      fi
      [ -n "$img" ] || exit 0
      set_wallpaper "$img"
    }

    # Sélecteur graphique à vignettes (waypaper) ; il pose le fond avec awww puis appelle `remember`.
    pick() {
      mkdir -p "$state"
      cfg="$state/waypaper.ini"
      {
        echo "[Settings]"
        IFS=: read -ra arr <<< "$dirs"
        printf 'folder = '
        for i in "''${!arr[@]}"; do
          [ "$i" -gt 0 ] && printf '\n  '
          printf '%s' "''${arr[$i]}"
        done
        printf '\n'
        echo "backend = awww"
        echo "fill = Fill"
        echo "subfolders = True"
        echo "number_of_columns = 4"
        echo "swww_transition_type = fade"
        echo "swww_transition_duration = 1"
        # $wallpaper est substitué par waypaper, pas par le shell
        # shellcheck disable=SC2016
        echo 'post_command = wallpaper remember $wallpaper'
      } > "$cfg"
      exec waypaper --config-file "$cfg" --state-file "$state/waypaper-state.ini" --backend awww
    }

    case "''${1:-}" in
      set)
        [ $# -ge 2 ] || { echo "usage: wallpaper set <image>" >&2; exit 2; }
        set_wallpaper "$2" ;;
      remember)
        [ $# -ge 2 ] || { echo "usage: wallpaper remember <image>" >&2; exit 2; }
        remember "$2" ;;
      restore) restore ;;
      pick) pick ;;
      *) echo "usage: wallpaper set <image>|remember <image>|restore|pick" >&2; exit 2 ;;
    esac
  '';
}
