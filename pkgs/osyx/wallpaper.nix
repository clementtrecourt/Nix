{
  writeShellApplication,
  coreutils,
  findutils,
  gawk,
  wofi,
}:
# awww n'est volontairement pas dans runtimeInputs : on utilise celui de la session.
writeShellApplication {
  name = "wallpaper";
  runtimeInputs = [coreutils findutils gawk wofi];
  text = ''
    state=''${OSYX_STATE_DIR:-''${XDG_STATE_HOME:-$HOME/.local/state}/osyx}
    dirs=''${OSYX_WALLPAPER_DIRS:-$HOME/Pictures/Wallpapers:$HOME/Pictures/wallpapers}

    images() {
      IFS=: read -ra arr <<< "$dirs"
      find -L "''${arr[@]}" -maxdepth 2 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) \
        2>/dev/null | sort
    }

    set_wallpaper() {
      img=$1
      case "$img" in /*) ;; *) img="$PWD/$img" ;; esac
      if [ ! -f "$img" ]; then
        echo "wallpaper: fichier introuvable: $img" >&2
        exit 1
      fi
      mkdir -p "$state"
      echo "$img" > "$state/wallpaper"
      # le démon est lancé en parallèle au login : attendre qu'il réponde
      for _ in $(seq 1 40); do awww query >/dev/null 2>&1 && break; sleep 0.25; done
      awww img "$img" --transition-type fade || echo "wallpaper: awww a échoué (démon absent ?)" >&2
      # le thème suit le wallpaper, sauf si une palette est épinglée (themes apply <nom>)
      if command -v themes >/dev/null 2>&1 && [ "$(themes mode 2>/dev/null || echo dynamic)" = dynamic ]; then
        themes from-wallpaper "$img" || true
      fi
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

    pick() {
      list=$(images | while read -r p; do printf '%s\t%s\n' "$(basename "$p")" "$p"; done)
      [ -n "$list" ] || { echo "wallpaper: aucune image dans $dirs" >&2; exit 1; }
      choice=$(printf '%s\n' "$list" | cut -f1 | wofi --dmenu --prompt wallpaper) || exit 0
      path=$(printf '%s\n' "$list" | awk -F'\t' -v n="$choice" '$1 == n {print $2; exit}')
      [ -n "$path" ] && set_wallpaper "$path"
    }

    case "''${1:-}" in
      set)
        [ $# -ge 2 ] || { echo "usage: wallpaper set <image>" >&2; exit 2; }
        set_wallpaper "$2" ;;
      restore) restore ;;
      pick) pick ;;
      *) echo "usage: wallpaper set <image>|restore|pick" >&2; exit 2 ;;
    esac
  '';
}
