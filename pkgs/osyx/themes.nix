{
  writeShellApplication,
  coreutils,
  findutils,
  procps,
  osyx-themes,
  mmsgReload,
}:
writeShellApplication {
  name = "themes";
  runtimeInputs = [coreutils findutils procps];
  text = ''
    themes_dir=''${OSYX_THEMES_DIR:-${osyx-themes}}
    state=''${OSYX_STATE_DIR:-''${XDG_STATE_HOME:-$HOME/.local/state}/osyx}
    default=versailles

    list() { find "$themes_dir" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort; }
    current() { cat "$state/theme.current" 2>/dev/null || true; }

    link() { ln -sfn "$themes_dir/$name/$2" "$state/$1"; }

    reload() {
      [ -n "''${OSYX_NO_RELOAD:-}" ] && return 0
      if command -v makoctl >/dev/null 2>&1; then makoctl reload || true; fi
      pkill -USR1 -x kitty || true
      if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
        tmux source-file "$state/tmux.conf" || true
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
      echo "$name" > "$state/theme.current"
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
