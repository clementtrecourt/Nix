{
  writeShellApplication,
  coreutils,
  findutils,
  procps,
  glib,
  osyx-themes,
  mmsgReload,
}:
writeShellApplication {
  name = "themes";
  runtimeInputs = [coreutils findutils procps glib];
  text = ''
    themes_dir=''${OSYX_THEMES_DIR:-${osyx-themes}}
    state=''${OSYX_STATE_DIR:-''${XDG_STATE_HOME:-$HOME/.local/state}/osyx}
    default=versailles

    list() { find "$themes_dir" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort; }
    current() { cat "$state/theme.current" 2>/dev/null || true; }

    link() { ln -sfn "$themes_dir/$name/$2" "$state/$1"; }

    # swww (démon lancé en parallèle au login) : attendre qu'il réponde, puis poser le fond du thème
    wallpaper() {
      command -v swww >/dev/null 2>&1 || return 0
      dir=''${OSYX_WALLPAPER_DIR:-$HOME/Pictures/osyx}
      img=$(find -L "$dir" -maxdepth 1 -name "$name.*" -print -quit 2>/dev/null || true)
      [ -n "$img" ] || return 0
      for _ in $(seq 1 20); do swww query >/dev/null 2>&1 && break; sleep 0.25; done
      swww img "$img" --transition-type fade || true
    }

    reload() {
      [ -n "''${OSYX_NO_RELOAD:-}" ] && return 0
      if command -v makoctl >/dev/null 2>&1; then makoctl reload || true; fi
      pkill -USR1 -x kitty || true
      if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
        tmux source-file "$state/tmux.conf" || true
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
      ${mmsgReload} || true
    }

    apply() {
      name=$1
      if [ ! -d "$themes_dir/$name" ]; then
        echo "themes: thème inconnu: $name" >&2
        exit 1
      fi
      mkdir -p "$state"
      link mako.conf .config/mako/config
      link starship.toml .config/starship.toml
      link wofi.css .config/wofi/style.css
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
      echo "$name" > "$state/theme.current"
      wallpaper
      reload
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
      apply)
        [ $# -ge 2 ] || { echo "usage: themes apply <nom>" >&2; exit 2; }
        apply "$2" ;;
      apply-default)
        cur=$(current)
        apply "''${cur:-$default}" ;;
      rotate) rotate ;;
      *)
        if [ -n "''${1:-}" ] && [ -d "$themes_dir/$1" ]; then apply "$1"; else
          echo "usage: themes list|current|apply <nom>|apply-default|rotate|<nom>" >&2
          exit 2
        fi ;;
    esac
  '';
}
