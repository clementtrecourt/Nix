{
  writeShellApplication,
  coreutils,
  findutils,
  procps,
  glib,
  libnotify,
  matugen,
  python3,
  osyx-themes,
  mmsgReload,
  flavors,
}:
writeShellApplication {
  name = "themes";
  runtimeInputs = [coreutils findutils procps glib libnotify matugen (python3.withPackages (p: [p.jinja2]))];
  text = ''
    themes_dir=''${OSYX_THEMES_DIR:-${osyx-themes}}
    state=''${OSYX_STATE_DIR:-''${XDG_STATE_HOME:-$HOME/.local/state}/osyx}
    default=versailles
    contrast=''${OSYX_CONTRAST:-0.0}
    # saturation | value | less-saturation | darkness | lightness : quelle couleur de l'image sert de base
    prefer=''${OSYX_PREFER:-saturation}
    # 0 = fonds gris, 1 = teinte Material brute
    tint=''${OSYX_TINT:-0.25}
    export OSYX_TINT=$tint

    list() { find "$themes_dir" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort; }
    current() { cat "$state/theme.current" 2>/dev/null || true; }
    # dynamic (suit le wallpaper, défaut) ou fixed (palette épinglée)
    mode() { cat "$state/theme.mode" 2>/dev/null || echo dynamic; }

    link() { ln -sfn "$root/$2" "$state/$1"; }

    reload() {
      [ -n "''${OSYX_NO_RELOAD:-}" ] && return 0
      if command -v makoctl >/dev/null 2>&1; then makoctl reload || true; fi
      # sous Nix le processus s'appelle .kitty-wrapped
      pkill -USR1 -x kitty || true
      pkill -USR1 -x .kitty-wrapped || true
      if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
        tmux source-file "$state/tmux.conf" || true
        # l'environnement global de tmux hérite d'un ancien STARSHIP_CONFIG : les nouvelles fenêtres le prennent
        tmux set-environment -g STARSHIP_CONFIG "$state/starship.toml" || true
      fi
      if command -v gsettings >/dev/null 2>&1; then
        # force GTK/libadwaita à relire gtk.css
        gsettings set org.gnome.desktop.interface color-scheme default || true
        gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3 || true
        gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark || true
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
      fi
      # Zed surveille ~/.config/zed/themes : un événement sur le lien lui signale le changement
      touch -h "$HOME/.config/zed/themes/osyx.json" 2>/dev/null || true
      if command -v nvim >/dev/null 2>&1; then
        for sock in "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/nvim.*.0; do
          [ -S "$sock" ] || continue
          nvim --server "$sock" --remote-send "<Cmd>lua dofile('$state/nvim-theme.lua')<CR>" || true
        done
      fi
      # Vicinae relit le thème quand on le (re)sélectionne
      if command -v vicinae >/dev/null 2>&1; then vicinae theme set osyx >/dev/null 2>&1 || true; fi
      ${mmsgReload} || true
    }

    # $1 = dossier contenant .config/… générés, $2 = nom du thème, $3 = mode
    link_all() {
      root=$1
      mkdir -p "$state"
      link mako.conf .config/mako/config
      link starship.toml .config/starship.toml
      link tmux.conf .config/tmux/osyx-theme.conf
      link dircolors .dircolors
      link mango-colors.conf .config/mango/colors.conf
      link lookas.toml .config/lookas.toml
      link powyx.toml .config/powyx/powyx.toml
      link kitty.conf .config/kitty/osyx.conf
      link gtk.css .config/gtk-3.0/gtk.css
      link qt6ct.conf .config/qt6ct/colors/osyx.conf
      link zed.json .config/zed/themes/osyx.json
      link nvim-theme.lua .config/nvim/osyx-theme.lua
      link swaylock.conf .config/swaylock/config
      link vicinae.toml .config/vicinae-theme.toml
      link hyprlock-colors.conf .config/hypr/hyprlock-colors.conf
      echo "$2" > "$state/theme.current"
      echo "$3" > "$state/theme.mode"
      reload
    }

    apply() {
      name=$1
      if [ ! -d "$themes_dir/$name" ]; then
        echo "themes: thème inconnu: $name" >&2
        exit 1
      fi
      link_all "$themes_dir/$name" "$name" fixed
    }

    # Palette générée depuis l'image par matugen, rendue avec les mêmes templates que les palettes fixes.
    from_wallpaper() {
      img=$1
      if [ ! -f "$img" ]; then
        echo "themes: image introuvable: $img" >&2
        exit 1
      fi
      # la clé du cache couvre l'image, les réglages et la version des templates (chemin du store)
      hash=$(printf '%s|%s|%s|%s|%s' "$(sha256sum "$img" | cut -d' ' -f1)" "${flavors}" "$tint" "$contrast" "$prefer" | sha256sum | cut -d' ' -f1)
      cache="$state/dynamic-cache/$hash"
      if [ ! -d "$cache" ]; then
        mkdir -p "$state/dynamic-cache"
        work=$(mktemp -d "$state/dynamic-work.XXXXXX")
        if ! json=$(matugen image "$img" --json hex --dry-run --mode dark --prefer "$prefer" --contrast "$contrast" 2>"$work/err"); then
          msg=$(head -n 3 "$work/err" | tr '\n' ' ')
          echo "themes: matugen a échoué sur $img: $msg" >&2
          notify-send "Thème" "Impossible de tirer les couleurs de l'image" 2>/dev/null || true
          rm -rf "$work"
          exit 1
        fi
        printf '%s' "$json" > "$work/matugen.json"
        cp -r ${flavors} "$work/flavors"
        chmod -R u+w "$work/flavors"
        (cd "$work/flavors" && python3 generate.py --from-matugen ../matugen.json >/dev/null)
        rm -rf "$work/flavors" "$work/matugen.json" "$work/err"
        mv -T "$work" "$cache" 2>/dev/null || rm -rf "$work"
        # ne garder que les 8 dernières palettes générées
        find "$state/dynamic-cache" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -rn | tail -n +9 | cut -d' ' -f2- | xargs -r rm -rf
      fi
      link_all "$cache" dynamic dynamic
    }

    wallpaper_image() {
      img=$(cat "$state/wallpaper" 2>/dev/null || true)
      if [ -z "$img" ] || [ ! -f "$img" ]; then
        echo "themes: aucun wallpaper mémorisé (choisis-en un avec: wallpaper pick)" >&2
        exit 1
      fi
      printf '%s' "$img"
    }

    rotate() {
      cur=$(current)
      mapfile -t all < <(list)
      next=''${all[0]}
      for i in "''${!all[@]}"; do
        if [ "''${all[$i]}" = "$cur" ]; then
          next=''${all[$(( (i + 1) % ''${#all[@]} ))]}
        fi
      done
      apply "$next"
    }

    case "''${1:-}" in
      list) list ;;
      current) current ;;
      mode) mode ;;
      apply)
        [ $# -ge 2 ] || { echo "usage: themes apply <nom>" >&2; exit 2; }
        apply "$2" ;;
      from-wallpaper)
        [ $# -ge 2 ] || { echo "usage: themes from-wallpaper <image>" >&2; exit 2; }
        from_wallpaper "$2" ;;
      dynamic) from_wallpaper "$(wallpaper_image)" ;;
      apply-default)
        # au login : relier l'état au thème courant (les chemins du store changent à chaque rebuild)
        if [ "$(mode)" = dynamic ]; then
          img=$(cat "$state/wallpaper" 2>/dev/null || true)
          if [ -n "$img" ] && [ -f "$img" ]; then
            from_wallpaper "$img" || link_all "$themes_dir/$default" "$default" dynamic
          else
            # pas encore de wallpaper : palette de départ sans épingler le mode
            link_all "$themes_dir/$default" "$default" dynamic
          fi
        else
          cur=$(current)
          apply "''${cur:-$default}"
        fi ;;
      rotate) rotate ;;
      *)
        if [ -n "''${1:-}" ] && [ -d "$themes_dir/$1" ]; then apply "$1"; else
          echo "usage: themes list|current|mode|apply <nom>|from-wallpaper <image>|dynamic|apply-default|rotate|<nom>" >&2
          exit 2
        fi ;;
    esac
  '';
}
