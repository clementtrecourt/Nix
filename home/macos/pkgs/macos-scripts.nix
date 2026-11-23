# Petits utilitaires appelés par les raccourcis Hyprland pour reproduire les
# comportements de macOS :
#   macos-wm         : quitter / masquer / réduire une app, touches Cmd façon Mac, Cmd+`
#   macos-screenshot : Cmd+Maj+3 / Cmd+Maj+4 (+ Espace = fenêtre), nommage macOS français
{
  writeShellApplication,
  coreutils,
  gawk,
  grim,
  hyprland,
  jq,
  libnotify,
  pipewire,
  procps,
  quickshell,
  slurp,
  socat,
  sound-theme-freedesktop,
  wl-clipboard,
}: let
  wm = writeShellApplication {
    name = "macos-wm";
    runtimeInputs = [coreutils hyprland jq socat];
    text = ''
      # macos-wm <commande> [args]
      #   quit-app          Cmd+Q : ferme toutes les fenêtres de l'app au premier plan
      #   hide-app          Cmd+H : masque l'app (toutes ses fenêtres -> special:minimized)
      #   minimize          Cmd+M : réduit la fenêtre active (special:minimized, restaurée par le Dock)
      #   cycle-app         Cmd+` : fenêtre suivante de la même app
      #   key <k> [shift]   Cmd+<k> -> Ctrl+<k> (Ctrl+Maj pour copier/coller/onglets des terminaux)
      #   watch-raise       (exec-once) remonte au premier plan toute fenêtre qui reçoit le focus
      cmd="''${1:-}"
      shift || true

      active() { hyprctl activewindow -j 2>/dev/null || echo '{}'; }

      # Adresses des fenêtres d'une classe (sur tous les espaces)
      windows_of() {
        hyprctl clients -j | jq -r --arg c "$1" \
          '.[] | select(.class == $c and .mapped) | .address'
      }

      is_terminal() {
        case "$1" in
          kitty | foot | footclient | Alacritty | com.mitchellh.ghostty | org.wezfurlong.wezterm) return 0 ;;
          *) return 1 ;;
        esac
      }

      case "$cmd" in
        quit-app)
          cls=$(active | jq -r '.class // empty')
          [ -n "$cls" ] || exit 0
          batch=""
          while read -r addr; do
            [ -n "$addr" ] && batch+="dispatch closewindow address:$addr;"
          done < <(windows_of "$cls")
          [ -n "$batch" ] && hyprctl --batch "$batch" >/dev/null
          ;;
        hide-app)
          cls=$(active | jq -r '.class // empty')
          [ -n "$cls" ] || exit 0
          batch=""
          while read -r addr; do
            [ -n "$addr" ] && batch+="dispatch movetoworkspacesilent special:minimized,address:$addr;"
          done < <(windows_of "$cls")
          [ -n "$batch" ] && hyprctl --batch "$batch" >/dev/null
          ;;
        minimize)
          hyprctl dispatch movetoworkspacesilent special:minimized >/dev/null
          ;;
        cycle-app)
          win=$(active)
          cls=$(jq -r '.class // empty' <<<"$win")
          cur=$(jq -r '.address // empty' <<<"$win")
          [ -n "$cls" ] || exit 0
          next=$(hyprctl clients -j | jq -r --arg c "$cls" --arg cur "$cur" '
            [.[] | select(.class == $c and .mapped and (.workspace.name | startswith("special:") | not))]
            | sort_by(.focusHistoryID) | map(.address)
            | if length < 2 then empty else (.[length - 1]) end')
          [ -n "$next" ] && hyprctl dispatch focuswindow "address:$next" >/dev/null
          ;;
        key)
          k="''${1:?touche manquante}"
          extra="''${2:-}"
          cls=$(active | jq -r '.class // empty')
          mods="CTRL"
          if is_terminal "$cls"; then
            # Terminaux : copier/coller/nouvel onglet/nouvelle fenêtre passent par Ctrl+Maj
            case "$k" in c | v | t | n | f) mods="CTRL SHIFT" ;; esac
          fi
          [ "$extra" = shift ] && mods="CTRL SHIFT"
          hyprctl dispatch sendshortcut "$mods, $k, activewindow" >/dev/null
          ;;
        watch-raise)
          # Comme macOS : la fenêtre active passe toujours devant (Cmd+Tab, Dock,
          # notifications…), pas seulement au clic. Écoute le socket d'événements.
          sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
          socat -U - "UNIX-CONNECT:$sock" | while read -r line; do
            case "$line" in
              activewindowv2'>>'?*)
                addr="''${line#*>>}"
                hyprctl dispatch alterzorder "top,address:0x$addr" >/dev/null 2>&1 || true
                ;;
            esac
          done
          ;;
        *)
          sed -n '/^# macos-wm/,/^cmd=/p' "$0" | sed '$d'
          exit 1
          ;;
      esac
    '';
  };

  screenshot = writeShellApplication {
    name = "macos-screenshot";
    runtimeInputs = [coreutils gawk grim hyprland jq libnotify pipewire procps quickshell slurp wl-clipboard];
    text = ''
      # macos-screenshot <full|region|window> [--clipboard]
      #   full    Cmd+Maj+3      tout l'écran (écran sous le pointeur)
      #   region  Cmd+Maj+4      sélection d'une zone ; Espace bascule en mode fenêtre
      #   window  (Espace)       clic sur une fenêtre
      # Fichiers : ~/Pictures/Screenshots/Capture d’écran AAAA-MM-JJ à HH.MM.SS.png
      # puis vignette flottante : quickshell -c macos ipc call screenshot show <chemin>
      mode="''${1:-region}"
      clip="''${2:-}"
      dir="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
      mkdir -p "$dir"
      out="$dir/Capture d’écran $(date '+%Y-%m-%d à %H.%M.%S').png"
      run="''${XDG_RUNTIME_DIR:-/tmp}/macos-screenshot"
      mkdir -p "$run"
      shutter="${sound-theme-freedesktop}/share/sounds/freedesktop/stereo/camera-shutter.oga"

      # Apparence de la sélection façon macOS (réticule blanc, voile gris, cotes affichées)
      slurp_style=(-d -b 00000000 -c ffffffe6 -s ffffff1f -B 00000000 -w 1 -F Inter)

      finish() {
        # $1 = fichier capturé
        pw-play "$shutter" >/dev/null 2>&1 &
        if [ "$clip" = --clipboard ]; then
          wl-copy --type image/png <"$1"
          rm -f "$1"
          exit 0
        fi
        quickshell -c macos ipc call screenshot show "$1" >/dev/null 2>&1 ||
          notify-send -a "Capture d’écran" -i "$1" "Capture d’écran" "$(basename "$1")"
      }

      case "$mode" in
        full)
          mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
          grim -o "$mon" "$out"
          finish "$out"
          ;;
        region)
          rm -f "$run/window"
          # Sous-carte "macos-capture" : Espace -> mode fenêtre, Échap -> annule
          hyprctl dispatch submap macos-capture >/dev/null
          geom=$(slurp "''${slurp_style[@]}") || geom=""
          # Si Espace a été pressé, la capture de fenêtre a pris le relais
          [ -e "$run/window" ] && exit 0
          hyprctl dispatch submap reset >/dev/null
          [ -n "$geom" ] || exit 0
          grim -g "$geom" "$out"
          finish "$out"
          ;;
        window)
          touch "$run/window"
          pkill -x slurp || true
          hyprctl dispatch submap reset >/dev/null
          # Rectangles des fenêtres visibles sur les espaces affichés
          active_ws=$(hyprctl monitors -j | jq '[.[].activeWorkspace.id]')
          boxes=$(hyprctl clients -j | jq -r --argjson ws "$active_ws" '
            .[] | select(.mapped and (.hidden | not) and (.workspace.id as $w | $ws | index($w)))
            | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
          geom=$(slurp -r -b 00000000 -c 00000000 -s 0a84ff40 -B 00000000 <<<"$boxes") || geom=""
          rm -f "$run/window"
          [ -n "$geom" ] || exit 0
          grim -g "$geom" "$out"
          finish "$out"
          ;;
        *)
          echo "usage: macos-screenshot <full|region|window> [--clipboard]" >&2
          exit 1
          ;;
      esac
    '';
  };
in {
  inherit wm screenshot;
  all = [wm screenshot];
}
