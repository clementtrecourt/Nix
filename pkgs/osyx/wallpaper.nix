{
  writeShellApplication,
  coreutils,
  findutils,
  imagemagick,
}:
# awww n'est volontairement pas dans runtimeInputs : on utilise celui de la session.
writeShellApplication {
  name = "wallpaper";
  runtimeInputs = [coreutils findutils imagemagick];
  text = ''
    state=''${OSYX_STATE_DIR:-''${XDG_STATE_HOME:-$HOME/.local/state}/osyx}
    dirs=''${OSYX_WALLPAPER_DIRS:-$HOME/Pictures/Wallpapers}

    images() {
      IFS=: read -ra arr <<< "$dirs"
      find -L "''${arr[@]}" -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) \
        2>/dev/null | sort
    }

    # Copie réduite du fond pour l'écran de verrouillage (hyprlock) et pour SDDM, qui ne peut pas lire
    # $HOME : le dossier de SDDM est créé par la config NixOS, lisible par tous et inscriptible par l'utilisateur.
    backdrops() {
      lockimg="$state/lock-wallpaper.jpg"
      key=$(stat -L -c '%n|%Y|%s' "$1")
      if [ ! -s "$lockimg" ] || [ "$(cat "$state/lock-wallpaper.key" 2>/dev/null || true)" != "$key" ]; then
        magick "''${1}[0]" -auto-orient -resize '2560x1440^>' -quality 90 "$lockimg.tmp.jpg" 2>/dev/null || { rm -f "$lockimg.tmp.jpg"; return 1; }
        mv -f "$lockimg.tmp.jpg" "$lockimg"
        printf '%s\n' "$key" > "$state/lock-wallpaper.key"
      fi
      greeter=''${OSYX_SDDM_DIR:-/var/lib/sddm-wallpaper}
      if [ -d "$greeter" ] && [ -w "$greeter" ]; then
        install -m 644 "$lockimg" "$greeter/wallpaper.jpg.tmp"
        mv -f "$greeter/wallpaper.jpg.tmp" "$greeter/wallpaper.jpg"
      fi
    }

    # Mémorise le fond et fait suivre le thème, sauf si une palette est épinglée (themes apply <nom>).
    remember() {
      img=$1
      case "$img" in /*) ;; *) img="$PWD/$img" ;; esac
      if [ ! -f "$img" ]; then
        echo "wallpaper: fichier introuvable: $img" >&2
        exit 1
      fi
      # le pool de matuwall ne contient que des liens (vers les aperçus) : on mémorise le fichier réel
      img=$(readlink -f "$img")
      mkdir -p "$state"
      echo "$img" > "$state/wallpaper"
      backdrops "$img" || true
      if command -v themes >/dev/null 2>&1 && [ "$(themes mode 2>/dev/null || echo dynamic)" = dynamic ]; then
        themes from-wallpaper "$img" || true
      fi
    }

    # $1 = image, $2 = fun (animation) ou none (instantané).
    # fun : une vague (angle aléatoire à chaque changement, 40 px d'amplitude). Courbe .34,1.56,.64,1 (ease-out-back) :
    # départ vif, dépassement, arrêt net. Elle atteint la couverture complète à 37 % de la durée : 2,8 s → ~1 s visibles.
    # awww met le fond à jour de façon incrémentale : un vrai rebond (aller-retour) est impossible, d'où ce rendu.
    awww_set() {
      anim=(--transition-type none)
      if [ "$2" = fun ]; then
        anim=(--transition-type wave --transition-angle $((RANDOM % 360)) --transition-wave "80,40"
          --transition-duration 2.8 --transition-bezier ".34,1.56,.64,1")
      fi
      awww img "$1" "''${anim[@]}" --transition-fps 144 || echo "wallpaper: awww a échoué (démon absent ?)" >&2
    }

    # $2 = fun par défaut ; none au login
    set_wallpaper() {
      remember "$1"
      img=$(cat "$state/wallpaper")
      # le démon est lancé en parallèle au login : attendre qu'il réponde
      for _ in $(seq 1 40); do awww query >/dev/null 2>&1 && break; sleep 0.25; done
      awww_set "$img" "''${2:-fun}"
    }

    restore() {
      img=$(cat "$state/wallpaper" 2>/dev/null || true)
      if [ -z "$img" ] || [ ! -f "$img" ]; then
        # ancien fond Caelestia, puis première image trouvée
        img=$(cat "$HOME/.local/state/caelestia/wallpaper/path.txt" 2>/dev/null || true)
        if [ -z "$img" ] || [ ! -f "$img" ]; then img=$(images | head -n 1); fi
      fi
      [ -n "$img" ] || exit 0
      set_wallpaper "$img" none
    }

    # Aperçus (720x405) que matuwall décode pour ses vignettes : un PNG 4096 px coûte ~0,7 s à décoder,
    # un aperçu quelques ms. Le fond posé reste l'original : à côté de chaque aperçu, <clé>.src le désigne.
    previews="$state/wallpaper-previews"
    preview_file() {
      printf '%s/%s.jpg' "$previews" "$(stat -L -c '%n|%Y|%s' "$1" | sha256sum | cut -c1-32)"
    }

    # Un dossier unique pour matuwall : liens vers toutes les images (sous-dossiers compris).
    # Nom sans espace : <dossier parent>__<fichier>, caractères hors [A-Za-z0-9._-] remplacés par _ (dans $name).
    pool="$state/wallpaper-pool"
    pool_name() {
      pn=''${1%/*}
      pn=''${pn##*/}__''${1##*/}
      name=''${pn//[^A-Za-z0-9._-]/_}
    }

    # Pool provisoire (première ouverture ou liens cassés) : liens vers les originaux, sans sous-processus
    # coûteux. Le pool définitif, avec les aperçus, est construit en arrière-plan par `warm`.
    quick_pool() {
      rm -rf "$pool"
      mkdir -p "$pool"
      while read -r p; do
        pool_name "$p"
        ln -s "$p" "$pool/$name"
      done < <(images)
    }

    # Crée les aperçus manquants et supprime ceux dont l'original n'existe plus.
    warm() {
      lock="$state/warm.pid"
      mkdir -p "$state"
      if [ -f "$lock" ] && kill -0 "$(cat "$lock")" 2>/dev/null; then exit 0; fi
      echo $$ > "$lock"
      trap 'rm -f "$lock"' EXIT
      # ancienne version : copies 2560 px dont le fond mémorisé pouvait être une copie → on retrouve l'original
      old="$state/wallpaper-cache"
      if [ -d "$old" ]; then
        cur=$(cat "$state/wallpaper" 2>/dev/null || true)
        images | while read -r p; do
          k=$(stat -L -c '%n|%Y|%s' "$p" | sha256sum | cut -c1-32)
          if [ "$old/$k.jpg" = "$cur" ]; then echo "$p" > "$state/wallpaper"; fi
        done
        rm -rf "$old"
      fi
      mkdir -p "$previews"
      new="$pool.new"
      rm -rf "$new"
      mkdir -p "$new"
      keep=$(mktemp)
      images | while read -r p; do
        c=$(preview_file "$p")
        printf '%s\n' "$c" >> "$keep"
        if [ ! -s "$c" ]; then
          # [0] : première image seulement pour les GIF animés
          if magick "''${p}[0]" -auto-orient -resize '720x405^>' -quality 85 "$c.tmp.jpg" 2>/dev/null; then
            printf '%s\n' "$p" > "''${c%.jpg}.src"
            mv -f "$c.tmp.jpg" "$c"
          else
            rm -f "$c.tmp.jpg"
          fi
        fi
        pool_name "$p"
        if [ -s "$c" ]; then ln -s "$c" "$new/$name"; else ln -s "$p" "$new/$name"; fi
      done
      find "$previews" -maxdepth 1 -name '*.jpg' | { grep -v -x -F -f "$keep" || true; } | while read -r f; do
        rm -f "$f" "''${f%.jpg}.src"
      done
      rm -f "$keep"
      # le pool n'est remplacé que s'il a changé : pas de fenêtre où il serait vide pendant une ouverture
      if [ "$(find "$new" -maxdepth 1 -type l -printf '%f %l\n' | sort)" != "$(find "$pool" -maxdepth 1 -type l -printf '%f %l\n' 2>/dev/null | sort)" ]; then
        rm -rf "$pool"
        mv "$new" "$pool"
      else
        rm -rf "$new"
      fi
    }

    # Appelé par matuwall (backend command) avec un fichier du pool : retrouve l'original, pose le fond
    # tout de suite, puis fait suivre le thème en arrière-plan (matuwall attend la fin de la commande).
    apply() {
      real=$(readlink -f "$1")
      case "$real" in
        "$previews"/*.jpg)
          src=$(cat "''${real%.jpg}.src" 2>/dev/null || true)
          if [ -f "$src" ]; then real=$src; fi ;;
      esac
      awww_set "$real" fun
      ( remember "$real" ) >/dev/null 2>&1 &
    }

    # couleur "#rrggbb" d'une clé du thème courant (kitty.conf généré par `themes`), sinon défaut
    theme_color() {
      c=$(sed -n "s/^$1 \(#[0-9a-fA-F]\{6\}\)$/\1/p" "$state/kitty.conf" 2>/dev/null | head -n 1 || true)
      printf '%s' "''${c:-$2}"
    }

    pick() {
      mkdir -p "$state"
      # ouverture immédiate : on réutilise le pool existant (mis à jour par `warm`), sauf s'il manque ou a des liens cassés
      if [ ! -d "$pool" ] || [ -n "$(find "$pool" -maxdepth 1 -xtype l -print -quit)" ]; then quick_pool; fi
      bg=$(theme_color background '#11111b')
      accent=$(theme_color cursor '#f2cdcd')
      cfg="$state/matuwall.toml"
      cat > "$cfg" <<EOF
    [general]
    directory = "$state/wallpaper-pool"
    recursive = false
    backend = "command"

    [backend.command]
    apply = "wallpaper apply {path}"

    [window]
    position = "bottom"
    background = "''${bg}e6"

    [input]
    mouse = true

    [animation]
    zoom_percent = 0

    [grid]
    carousel = true
    edge = "clip"
    columns = 5
    ring_width = 4

    [colors]
    ring = "$accent"
    EOF
      # aperçus manquants en arrière-plan : la prochaine ouverture en profite
      if [ -z "''${OSYX_NO_WARM:-}" ]; then nohup "$0" warm >/dev/null 2>&1 & fi
      exec matuwall --config "$cfg"
    }

    # Ancien sélecteur à vignettes (waypaper) ; il pose le fond avec awww puis appelle `remember`.
    pick_classic() {
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
      pick-classic) pick_classic ;;
      warm) warm ;;
      apply)
        [ $# -ge 2 ] || { echo "usage: wallpaper apply <image>" >&2; exit 2; }
        apply "$2" ;;
      *) echo "usage: wallpaper set <image>|remember <image>|restore|pick|pick-classic|warm|apply <image>" >&2; exit 2 ;;
    esac
  '';
}
