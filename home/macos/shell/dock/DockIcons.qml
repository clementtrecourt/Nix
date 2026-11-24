import QtQuick
import Quickshell
import Quickshell.Io

// Résolution des icônes du Dock, par ordre de priorité :
//   1. surcharge utilisateur : ~/.local/share/macos-shell/icons/<clé>.png (ou .svg)
//      <clé> = id .desktop sans extension (sinon classe en minuscules), ou
//      « apps », « downloads », « user-trash », « user-trash-full ».
//      C'est là qu'on dépose les VRAIES icônes Tahoe (toiles 1024×1024 extraites
//      d'un Mac) : elles sont affichées telles quelles, sans masque ni ombre ajoutés.
//      Elles ne sont jamais versionnées (dépôt public).
//   2. thème d'icônes (MacTahoe-Apple-dark = vraies icônes Tahoe en PNG 1024 ;
//      sinon MacTahoe) : le PNG le plus grand s'il couvre la taille
//      affichée maximale (agrandissement × densité), sinon le SVG via le thème.
//   3. absente du thème : icône amont (hicolor) via Quickshell.iconPath, que le
//      Dock pose sur un squircle gris réduit, comme Tahoe pour les icônes non
//      conformes à la grille Apple.
// La recherche se fait dans un script shell (aucun accès disque synchrone en QML),
// relancé quand de nouvelles icônes sont demandées et toutes les 20 s (pour
// prendre en compte une surcharge déposée pendant que le shell tourne).
Item {
    id: root
    visible: false

    // Taille maximale affichée en pixels physiques (sourceSize des Image)
    property int maxPixels: 160
    readonly property string theme: Quickshell.env("QS_ICON_THEME") || "MacTahoe-dark"
    readonly property string overrideDir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/macos-shell/icons"

    // clé -> { path, override }
    property var resolved: ({})
    // clé -> nom d'icône du thème (ou chemin absolu)
    property var wanted: ({})

    function want(key, themeName) {
        if (!key) return;
        if (wanted[key] === themeName) return;
        wanted[key] = themeName;
        resolveTimer.restart();
    }
    function info(key) { return resolved[key] ?? null; }

    Timer {
        id: resolveTimer
        interval: 50
        onTriggered: root.resolve()
    }
    Timer {
        interval: 20000; running: true; repeat: true
        onTriggered: root.resolve()
    }

    function resolve() {
        if (proc.running) { resolveTimer.restart(); return; }
        const args = [];
        for (const k in wanted) args.push(k + "=" + wanted[k]);
        if (args.length === 0) return;
        proc.command = ["sh", "-c", script, "sh", root.theme, root.overrideDir, String(root.maxPixels)].concat(args);
        proc.running = true;
    }

    // $1 thème, $2 dossier de surcharge, $3 taille minimale d'un PNG, puis clé=nom…
    readonly property string script: '
theme="$1"; ovr="$2"; min="$3"; shift 3
dirs="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/run/current-system/sw/share}"
base="${theme%-dark}"; base="${base%-light}"
# Thèmes à parcourir : le thème, ses parents (Inherits=, sauf hicolor), puis la base
themes="$theme"; todo="$theme"
while [ -n "$todo" ]; do
  cur="${todo%% *}"; [ "$cur" = "$todo" ] && todo="" || todo="${todo#* }"
  IFS=:
  for d in $dirs; do
    f="$d/icons/$cur/index.theme"
    [ -f "$f" ] || continue
    inh=$(sed -n "s/^Inherits=//p" "$f" | head -1 | tr "," " ")
    break
  done
  unset IFS
  for i in $inh; do
    case " $themes hicolor " in *" $i "*) ;; *) themes="$themes $i"; todo="$todo $i" ;; esac
  done
  inh=""
  todo="${todo# }"
done
case " $themes " in *" $base "*) ;; *) themes="$themes $base" ;; esac
# Séparées par « : » (la boucle de recherche tourne avec IFS=:)
themes=$(printf %s "$themes" | tr " " :)
for pair in "$@"; do
  key="${pair%%=*}"; name="${pair#*=}"
  low=$(printf %s "$key" | tr "[:upper:]" "[:lower:]")
  found=""
  for k in "$key" "$low"; do
    for ext in png svg; do
      if [ -z "$found" ] && [ -f "$ovr/$k.$ext" ]; then found="$ovr/$k.$ext"; fi
    done
  done
  if [ -n "$found" ]; then printf "%s\\t%s\\t1\\n" "$key" "$found"; continue; fi
  case "$name" in /*) [ -f "$name" ] && printf "%s\\t%s\\t0\\n" "$key" "$name"; continue ;; esac
  # « @nom » : icône prise d abord dans le thème de base (MacTahoe clair) :
  # Tahoe garde la Corbeille de verre dépoli et le dossier bleu clair en mode
  # sombre, alors que MacTahoe-dark les assombrit.
  order="$themes"
  case "$name" in @*) name="${name#@}"; order="${base%-Apple}:$themes" ;; esac
  # Noms de repli : sans suffixe de canal (-beta, -bin…), dernier segment d un
  # id inversé (dev.zed.Zed -> Zed), « <nom>-browser » (zen-beta -> zen-browser)
  stem=$(printf %s "$name" | sed -E "s/[-_](beta|bin|stable|nightly|dev|git|preview|desktop)$//")
  last="${name##*.}"
  cands="$name"
  for c in "$stem" "$last" "$(printf %s "$last" | tr "[:upper:]" "[:lower:]")" "$stem-browser"; do
    case " $cands " in *" $c "*) ;; *) [ -n "$c" ] && cands="$cands $c" ;; esac
  done
  for cand in $cands; do
  best=""; bestsz=0; svg=""
  IFS=:
  for d in $dirs; do
    # Thème choisi seulement : hicolor (icônes amont non stylées) ne doit pas
    # passer devant un SVG du thème ; le repli hicolor reste assuré par Qt.
    for t in $order; do
      r="$d/icons/$t"
      [ -d "$r" ] || continue
      for f in "$r"/*/*/"$cand".svg "$r"/*/"$cand".svg; do
        [ -f "$f" ] || continue
        # Préférer le dessin « scalable » aux variantes 16/22/24 px simplifiées
        case "$svg" in */scalable/*) ;; *) case "$f" in */scalable/*) svg="$f" ;; *) [ -z "$svg" ] && svg="$f" ;; esac ;; esac
      done
      for f in "$r"/*/*/"$cand".png "$r"/*/"$cand".png; do
        [ -f "$f" ] || continue
        rel="${f#$r/}"
        sz=$(printf %s "$rel" | grep -o "[0-9][0-9]*" | head -1)
        [ -n "$sz" ] || continue
        case "$rel" in *@2x*) sz=$((sz * 2)) ;; esac
        if [ "$sz" -gt "$bestsz" ]; then bestsz=$sz; best="$f"; fi
      done
    done
  done
  unset IFS
  [ -n "$best$svg" ] && break
  done
  # Toile >= 512 px : icône Apple exportée d un Mac (squircle à 80,5 %) -> 2
  if [ -n "$best" ] && [ "$bestsz" -ge 512 ]; then printf "%s\\t%s\\t2\\n" "$key" "$best";
  elif [ -n "$best" ] && [ "$bestsz" -ge "$min" ]; then printf "%s\\t%s\\t0\\n" "$key" "$best";
  elif [ -n "$svg" ]; then printf "%s\\t%s\\t0\\n" "$key" "$svg";
  elif [ -n "$best" ]; then printf "%s\\t%s\\t0\\n" "$key" "$best";
  # Absente du thème : icône amont (hicolor…), mise « en boîte » par le Dock
  else printf "%s\\t\\t3\\n" "$key"; fi
done
'

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                const r = {};
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length < 3) continue;
                    // apple : toile Apple (1024, squircle 824) affichée à 100 %
                    // foreign : absente du thème (Tahoe la pose sur un squircle gris)
                    if (f[2] === "3") { r[f[0]] = { path: "", override: false, apple: false, foreign: true }; continue; }
                    r[f[0]] = { path: "file://" + f[1], override: f[2] === "1", apple: f[2] !== "0", foreign: false };
                }
                if (JSON.stringify(r) !== JSON.stringify(root.resolved)) root.resolved = r;
            }
        }
    }
}
