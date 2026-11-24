# Petits utilitaires appelés par les raccourcis Hyprland pour reproduire les
# comportements de macOS :
#   macos-wm         : quitter / masquer / réduire une app, plein écran dans son
#                      propre espace, touches Cmd façon Mac, Cmd+`, verrouillage
#   macos-screenshot : Cmd+Maj+3 / Cmd+Maj+4 (+ Espace = fenêtre), nommage macOS français
#   macos-appearance : mode clair / sombre de tout le système (GTK4/libadwaita,
#                      Kvantum, barres de titre hyprbars) d'après gsettings color-scheme
#   macos-settings   : « Réglages Système » (gnome-control-center hors GNOME), aussi
#                      exposé sous le nom gnome-control-center appelé par le shell
{
  lib,
  writeShellApplication,
  symlinkJoin,
  coreutils,
  dconf,
  gawk,
  gnome-control-center,
  grim,
  hyprland,
  hyprlock,
  jq,
  libnotify,
  mactahoe-gtk-theme,
  pipewire,
  procps,
  quickshell,
  slurp,
  socat,
  sound-theme-freedesktop,
  wdisplays,
  wl-clipboard,
}: let
  # ---------------------------------------------------------------------------
  # Apparence claire / sombre
  # ---------------------------------------------------------------------------
  appearance = writeShellApplication {
    name = "macos-appearance";
    runtimeInputs = [coreutils dconf hyprland];
    text = ''
      # macos-appearance <commande>
      #   apply [dark|light]  applique le mode (par défaut : celui de gsettings color-scheme)
      #   hypr [dark|light]   réapplique seulement les couleurs Hyprland (après un reload)
      #   watch               applique puis suit les changements de color-scheme
      #                       (Control Center du shell, Réglages, gsettings…)
      #
      # Le shell (controlcenter/Appearance.qml) écrit color-scheme + gtk-theme ;
      # ce script propage aux parties que gsettings ne pilote pas :
      #   - libadwaita/GTK4 : ~/.config/gtk-4.0/gtk.css importe MacTahoe-Light ou -Dark
      #   - Qt (Kvantum)     : ~/.config/Kvantum/kvantum.kvconfig -> MacTahoe / MacTahoeDark
      #   - hyprbars         : couleur des barres de titre, du titre, feux inactifs
      # kitty suit seul le mode (fichiers *-theme.auto.conf, via le portail Settings).
      cmd="''${1:-apply}"
      key=/org/gnome/desktop/interface/color-scheme
      conf="''${XDG_CONFIG_HOME:-$HOME/.config}"
      themes="${mactahoe-gtk-theme}/share/themes"

      mode() {
        case "$(dconf read "$key" 2>/dev/null)" in
          *dark*) echo dark ;;
          *) echo light ;;
        esac
      }

      # Écrit un fichier en remplaçant un éventuel lien vers le store (ancienne génération)
      put() {
        mkdir -p "$(dirname "$1")"
        rm -f "$1"
        printf '%s\n' "$2" >"$1"
      }

      hypr() {
        [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || return 0
        # Barre de titre = fond de la barre d'en-tête MacTahoe (#333333 / #ffffff),
        # titre en label (actif) ou tertiaryLabel (inactif), feux inactifs gris.
        # (barre inactive = fond « backdrop » de la barre d'en-tête MacTahoe)
        if [ "$1" = dark ]; then
          bar="rgb(333333)" back="rgb(242424)" text="rgba(ffffffd9)" dim="rgba(ffffff4d)" off="rgb(4f4f52)" term="rgb(1e1e1e)"
        else
          bar="rgb(ffffff)" back="rgb(f2f2f2)" text="rgba(000000d9)" dim="rgba(0000004d)" off="rgb(d9d9d9)" term="rgb(ffffff)"
        fi
        local b=""
        b+="keyword plugin:hyprbars:bar_color $bar;"
        b+="keyword plugin:hyprbars:col.text $text;"
        b+="keyword plugin:hyprbars:inactive_button_color $off;"
        # Règles ajoutées après celles de la config : elles l'emportent (terminal en dernier)
        b+="keyword windowrule hyprbars:bar_color $back, match:focus false;"
        b+="keyword windowrule hyprbars:bar_color $term, match:class ^(kitty|foot|footclient|Alacritty)\$;"
        b+="keyword windowrule hyprbars:title_color $dim, match:focus false"
        hyprctl --batch "$b" >/dev/null 2>&1 || true
      }

      apply() {
        local m="''${1:-$(mode)}" T K
        if [ "$m" = dark ]; then T=Dark K=MacTahoeDark; else T=Light K=MacTahoe; fi
        # gtk-theme suit le mode (utile si le mode a été changé hors du shell)
        if [ "$(dconf read /org/gnome/desktop/interface/gtk-theme 2>/dev/null)" != "'MacTahoe-$T'" ]; then
          dconf write /org/gnome/desktop/interface/gtk-theme "'MacTahoe-$T'" 2>/dev/null || true
        fi
        put "$conf/gtk-4.0/gtk.css" "/* Généré par macos-appearance (mode $m) : thème des apps libadwaita */
      @import url(\"file://$themes/MacTahoe-$T/gtk-4.0/gtk.css\");"
        put "$conf/Kvantum/kvantum.kvconfig" "[General]
      theme=$K"
        hypr "$m"
      }

      case "$cmd" in
        apply) apply "''${2:-}" ;;
        hypr) hypr "''${2:-$(mode)}" ;;
        watch)
          apply
          # dconf watch : une ligne par changement (clé puis valeur)
          dconf watch "$key" | while read -r line; do
            case "$line" in
              *dark* | *light* | *default*) apply ;;
            esac
          done
          ;;
        *)
          sed -n '/^# macos-appearance/,/^cmd=/p' "$0" | sed '$d'
          exit 1
          ;;
      esac
    '';
  };

  # ---------------------------------------------------------------------------
  # Fenêtres et clavier
  # ---------------------------------------------------------------------------
  wm = writeShellApplication {
    name = "macos-wm";
    runtimeInputs = [coreutils hyprland hyprlock jq socat];
    text = ''
      # macos-wm <commande> [args]
      #   quit-app          Cmd+Q : ferme toutes les fenêtres de l'app au premier plan
      #   close             Cmd+W : ferme l'onglet (navigateurs, terminaux, éditeurs,
      #                     Finder) sinon la fenêtre
      #   hide-app          Cmd+H : masque l'app (special:hidden, ré-affichée par le Dock)
      #   hide-others       Cmd+Opt+H : masque les autres apps de l'espace courant
      #   minimize          Cmd+M / bouton jaune : effet « génie » du Dock (global
      #                     macos:minimize), sinon special:minimized
      #   fullscreen        Ctrl+Cmd+F / bouton vert : plein écran dans un nouvel espace
      #                     (et retour à l'espace d'origine en sortie)
      #   cycle-app         Cmd+` : fenêtre suivante de la même app
      #   key <k> [shift]   Cmd+<k> -> Ctrl+<k> (Ctrl+Maj pour les terminaux)
      #   kill-line         Cmd+⌫ : efface jusqu'au début de la ligne
      #   lock              verrouille (écran du shell, sinon hyprlock)
      #   lock-at-start     (exec-once) verrouille à l'ouverture de session si
      #                     MACOS_LOCK_AT_START=1 (connexion automatique de greetd)
      #   watch-raise       (exec-once) remonte au premier plan toute fenêtre qui reçoit
      #                     le focus et place en cascade les nouvelles fenêtres d'une app
      cmd="''${1:-}"
      shift || true

      state="''${XDG_RUNTIME_DIR:-/tmp}/macos-wm"
      mkdir -p "$state"

      active() { hyprctl activewindow -j 2>/dev/null || echo '{}'; }

      # Raccourci global du shell enregistré ? (le shell tourne)
      has_global() { hyprctl globalshortcuts 2>/dev/null | grep -q "^macos:$1 ->"; }

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

      # Apps à onglets / documents : Cmd+W ferme l'onglet courant (Ctrl+W chez elles)
      has_tabs() {
        case "$1" in
          zen* | firefox* | librewolf | brave-browser* | chromium* | google-chrome* | helium* | \
            dev.zed.Zed* | zed | Zed | code | Code | code-oss | cursor | obsidian | \
            nemo | org.gnome.Nautilus | org.gnome.TextEditor | org.gnome.Ptyxis | org.gnome.Console) return 0 ;;
          *) return 1 ;;
        esac
      }

      # Fenêtres non spéciales des espaces affichés
      visible_windows() {
        local ws
        ws=$(hyprctl monitors -j | jq '[.[].activeWorkspace.id]')
        hyprctl clients -j | jq -r --argjson ws "$ws" --arg c "$1" '
          .[] | select(.mapped and .class != $c and (.workspace.id as $w | $ws | index($w)))
          | .address'
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
        close)
          cls=$(active | jq -r '.class // empty')
          [ -n "$cls" ] || exit 0
          if is_terminal "$cls"; then
            hyprctl dispatch sendshortcut "CTRL SHIFT, w, activewindow" >/dev/null
          elif has_tabs "$cls"; then
            hyprctl dispatch sendshortcut "CTRL, w, activewindow" >/dev/null
          else
            hyprctl dispatch killactive >/dev/null
          fi
          ;;
        hide-app)
          # special:hidden (et non special:minimized) : le Dock n'affiche pas de
          # vignette et ré-affiche l'app au clic sur son icône (DockModel.unhide)
          cls=$(active | jq -r '.class // empty')
          [ -n "$cls" ] || exit 0
          batch=""
          while read -r addr; do
            [ -n "$addr" ] && batch+="dispatch movetoworkspacesilent special:hidden,address:$addr;"
          done < <(hyprctl clients -j | jq -r --arg c "$cls" \
            '.[] | select(.class == $c and .mapped and .workspace.name != "special:minimized") | .address')
          [ -n "$batch" ] && hyprctl --batch "$batch" >/dev/null
          ;;
        hide-others)
          cls=$(active | jq -r '.class // empty')
          [ -n "$cls" ] || exit 0
          batch=""
          while read -r addr; do
            [ -n "$addr" ] && batch+="dispatch movetoworkspacesilent special:hidden,address:$addr;"
          done < <(visible_windows "$cls")
          [ -n "$batch" ] && hyprctl --batch "$batch" >/dev/null
          ;;
        minimize)
          if has_global minimize; then
            hyprctl dispatch global macos:minimize >/dev/null
          else
            hyprctl dispatch movetoworkspacesilent special:minimized >/dev/null
          fi
          ;;
        fullscreen)
          win=$(active)
          addr=$(jq -r '.address // empty' <<<"$win")
          [ -n "$addr" ] || exit 0
          fs=$(jq -r '.fullscreen // 0' <<<"$win")
          # 2 = plein écran (1 = « Zoom » du double-clic : le bouton vert passe en plein écran)
          if [ "$fs" = 2 ]; then
            # Sortie du plein écran : retour dans l'espace d'origine
            hyprctl dispatch fullscreenstate "0 0" >/dev/null
            if [ -f "$state/fs-$addr" ]; then
              orig=$(cat "$state/fs-$addr")
              rm -f "$state/fs-$addr"
              hyprctl dispatch movetoworkspace "$orig,address:$addr" >/dev/null
            fi
          else
            # Nouvel espace juste après l'espace courant (glissement), puis plein écran
            jq -r '.workspace.id' <<<"$win" >"$state/fs-$addr"
            hyprctl --batch "dispatch movetoworkspace emptynm,address:$addr; dispatch fullscreenstate 2 2" >/dev/null
          fi
          ;;
        cycle-app)
          win=$(active)
          cls=$(jq -r '.class // empty' <<<"$win")
          [ -n "$cls" ] || exit 0
          next=$(hyprctl clients -j | jq -r --arg c "$cls" '
            [.[] | select(.class == $c and .mapped and (.workspace.name | startswith("special:") | not))]
            | sort_by(.focusHistoryID) | map(.address)
            | if length < 2 then empty else (.[length - 1]) end')
          [ -n "$next" ] && hyprctl dispatch focuswindow "address:$next" >/dev/null
          ;;
        key)
          # keysym en minuscules (c et non C, qui désignerait Maj+c)
          k="''${1:?touche manquante}"
          k="''${k,,}"
          extra="''${2:-}"
          cls=$(active | jq -r '.class // empty')
          mods="CTRL"
          if is_terminal "$cls"; then
            # Terminaux : copier/coller, onglets, fenêtres, taille du texte, effacer
            # passent par Ctrl+Maj (Ctrl seul est envoyé au programme)
            case "$k" in c | v | t | n | f | w | k | equal | minus | 0) mods="CTRL SHIFT" ;; esac
          fi
          [ "$extra" = shift ] && mods="CTRL SHIFT"
          hyprctl dispatch sendshortcut "$mods, $k, activewindow" >/dev/null
          ;;
        kill-line)
          cls=$(active | jq -r '.class // empty')
          if is_terminal "$cls"; then
            hyprctl dispatch sendshortcut "CTRL, u, activewindow" >/dev/null
          else
            hyprctl --batch "dispatch sendshortcut SHIFT, Home, activewindow; dispatch sendshortcut , BackSpace, activewindow" >/dev/null
          fi
          ;;
        lock)
          if has_global lock; then
            hyprctl dispatch global macos:lock >/dev/null
          else
            # Shell absent : verrouillage de secours
            pgrep -x hyprlock >/dev/null || hyprlock --immediate &
          fi
          ;;
        lock-at-start)
          [ "''${MACOS_LOCK_AT_START:-}" = 1 ] || exit 0
          # Attend que le shell ait enregistré son écran de verrouillage (15 s max)
          for _ in $(seq 1 60); do
            has_global lock && break
            sleep 0.25
          done
          "$0" lock
          ;;
        watch-raise)
          # Comme macOS : la fenêtre active passe toujours devant (Cmd+Tab, Dock,
          # notifications…), pas seulement au clic. Écoute le socket d'événements
          # (reconnexion si la connexion tombe, fin si Hyprland s'arrête).
          sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
          while [ -S "$sock" ]; do
            socat -U - "UNIX-CONNECT:$sock" | while read -r line; do
              case "$line" in
                activewindowv2'>>'?*)
                  addr="''${line#*>>}"
                  hyprctl dispatch alterzorder "top,address:0x$addr" >/dev/null 2>&1 || true
                  ;;
                configreloaded'>>'*)
                  # Reload de la config : les couleurs du mode clair sont à réappliquer
                  ${appearance}/bin/macos-appearance hypr || true
                  ;;
                openwindow'>>'?*)
                  # Fenêtres en cascade, comme les nouvelles fenêtres d'une app Mac :
                  # si une autre fenêtre de la même app occupe déjà la même position
                  # (règle « center »), décalage de 26 px vers le bas à droite, sans
                  # jamais sortir de la zone utile de l'écran.
                  addr="0x''${line#*>>}"
                  addr="''${addr%%,*}"
                  pos=$(jq -rn --arg a "$addr" \
                    --argjson cl "$(hyprctl clients -j)" --argjson mons "$(hyprctl monitors -j)" '
                    ($cl[] | select(.address == $a)) as $w
                    | if ($w.floating | not) then empty else
                        ($mons[] | select(.id == $w.monitor)) as $m
                        | ($m.x + $m.width / $m.scale - $m.reserved[2]) as $right
                        | ($m.y + $m.height / $m.scale - $m.reserved[3]) as $bottom
                        | [$cl[] | select(.address != $a and .class == $w.class and .mapped
                                          and .workspace.id == $w.workspace.id) | .at] as $taken
                        | def free($p): ($taken | map(select(((.[0] - $p[0]) | fabs) < 4 and ((.[1] - $p[1]) | fabs) < 4)) | length) == 0;
                          def fits($p): ($p[0] + $w.size[0] <= $right) and ($p[1] + $w.size[1] <= $bottom);
                          [range(0; 12) | [$w.at[0] + . * 26, $w.at[1] + . * 26]]
                          | map(select(free(.) and fits(.))) | first // empty
                          | select(. != $w.at) | "\(.[0]) \(.[1])"
                      end' 2>/dev/null) || pos=""
                  [ -n "$pos" ] && hyprctl dispatch movewindowpixel "exact $pos,address:$addr" >/dev/null 2>&1 || true
                  ;;
              esac
            done
            sleep 1
          done
          ;;
        *)
          sed -n '/^# macos-wm/,/^cmd=/p' "$0" | sed '$d'
          exit 1
          ;;
      esac
    '';
  };

  # ---------------------------------------------------------------------------
  # Captures d'écran
  # ---------------------------------------------------------------------------
  screenshot = writeShellApplication {
    name = "macos-screenshot";
    runtimeInputs = [coreutils gawk grim hyprland jq libnotify pipewire procps quickshell slurp wl-clipboard];
    text = ''
      # macos-screenshot <full|region|window> [--clipboard]
      #   full    Cmd+Maj+3      chaque écran (un fichier par écran, comme macOS)
      #   region  Cmd+Maj+4      sélection d'une zone ; Espace bascule en mode fenêtre
      #   window  (Espace)       clic sur une fenêtre (garde le --clipboard de region)
      # Fichiers (nommés comme macOS en anglais US, espace fine insécable U+202F
      # avant AM/PM) : ~/Pictures/Screenshots/Screenshot 2026-11-24 at 9.12.11 AM.png
      # (« … (2).png » pour le 2e écran), puis vignette flottante :
      #   quickshell -c macos ipc call screenshot show <chemin>
      mode="''${1:-region}"
      clip="''${2:-}"
      dir="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
      mkdir -p "$dir"
      ts="$(LC_ALL=C date '+%Y-%m-%d at %-I.%M.%S %p')"
      base="$dir/Screenshot ''${ts% *}"$'\u202f'"''${ts##* }"
      out="$base.png"
      run="''${XDG_RUNTIME_DIR:-/tmp}/macos-screenshot"
      mkdir -p "$run"
      shutter="${sound-theme-freedesktop}/share/sounds/freedesktop/stereo/camera-shutter.oga"

      # Apparence de la sélection façon macOS (réticule blanc, voile gris, cotes affichées)
      slurp_style=(-d -b 00000000 -c ffffffe6 -s ffffff1f -B 00000000 -w 1 -F Inter)

      # La vignette de la capture précédente (et la barre ⇧⌘5) ne doivent pas
      # apparaître dans l'image : le shell les cache le temps de la capture.
      qs_ipc() { quickshell -c macos ipc call screenshot "$@" >/dev/null 2>&1 || true; }
      qs_ipc prepare
      qs_restore() { qs_ipc "done"; }
      trap qs_restore EXIT
      sleep 0.08

      finish() {
        # $1 = fichier capturé (vignette) ; les suivants : autres écrans
        pw-play "$shutter" >/dev/null 2>&1 &
        if [ "$clip" = --clipboard ]; then
          wl-copy --type image/png <"$1"
          rm -f "$@"
          exit 0
        fi
        quickshell -c macos ipc call screenshot show "$1" >/dev/null 2>&1 ||
          notify-send -a "Screenshot" -i "$1" "Screenshot" "$(basename "$1")"
      }

      case "$mode" in
        full)
          # Écran actif d'abord (vignette, presse-papiers), puis les autres
          mapfile -t mons < <(hyprctl monitors -j | jq -r 'sort_by(.focused | not) | .[].name')
          if [ "$clip" = --clipboard ] || [ "''${#mons[@]}" -le 1 ]; then
            grim -o "''${mons[0]}" "$out"
            finish "$out"
          fi
          files=()
          for i in "''${!mons[@]}"; do
            f="$out"
            [ "$i" -gt 0 ] && f="$base ($((i + 1))).png"
            grim -o "''${mons[$i]}" "$f"
            files+=("$f")
          done
          finish "''${files[@]}"
          ;;
        region)
          rm -f "$run/window"
          # Le mode fenêtre (Espace) reprend la destination (fichier / presse-papiers)
          if [ "$clip" = --clipboard ]; then touch "$run/clip"; else rm -f "$run/clip"; fi
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
          [ -e "$run/clip" ] && clip=--clipboard
          rm -f "$run/clip"
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

  # ---------------------------------------------------------------------------
  # Réglages Système : gnome-control-center (barre latérale + panneaux, la plus
  # proche des Réglages Système du Mac) lancé hors GNOME ; « Écrans » -> wdisplays
  # (le panneau GNOME exige Mutter). Le shell appelle `gnome-control-center <panneau>`.
  # ---------------------------------------------------------------------------
  settingsScript = writeShellApplication {
    name = "macos-settings";
    runtimeInputs = [coreutils];
    text = ''
      case "''${1:-}" in
        display | displays) exec ${lib.getExe wdisplays} ;;
      esac
      # gnome-control-center refuse de démarrer hors GNOME sans ce marqueur
      export XDG_CURRENT_DESKTOP=GNOME
      # Les panneaux sont décrits par des fichiers .desktop cherchés dans XDG_DATA_DIRS
      export XDG_DATA_DIRS="${gnome-control-center}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
      # … et ignorés si leur Exec=gnome-control-center n'est pas dans le PATH
      export PATH="${gnome-control-center}/bin:$PATH"
      exec ${gnome-control-center}/bin/gnome-control-center "$@"
    '';
  };
  settings = symlinkJoin {
    name = "macos-settings";
    paths = [settingsScript];
    postBuild = ''
      ln -s macos-settings $out/bin/gnome-control-center
      # Entrées .desktop et icônes de gnome-control-center (Spotlight, Dock)
      mkdir -p $out/share
      ln -s ${gnome-control-center}/share/icons $out/share/icons
      mkdir -p $out/share/applications
      sed "s|^Exec=.*|Exec=$out/bin/macos-settings|; s|^OnlyShowIn=.*||" \
        ${gnome-control-center}/share/applications/org.gnome.Settings.desktop \
        >$out/share/applications/org.gnome.Settings.desktop
    '';
    meta.mainProgram = "macos-settings";
  };
in {
  inherit wm screenshot appearance settings;
  all = [wm screenshot appearance settings];
}
