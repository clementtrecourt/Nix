pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Fond d'écran : image utilisateur (~/.config/macos-shell/wallpaper, fichier ou
// lien symbolique) ou, à défaut, le fond procédural "Tahoe" (shaders/tahoe.frag).
//
// Le chemin est surveillé (sondage léger toutes les 3 s : un lien symbolique
// remplacé n'est pas toujours vu par inotify) ; `source` change -> fondu.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // MACOS_SHELL_CONFIG permet de tester sans toucher à la vraie config
    readonly property string configDir: Quickshell.env("MACOS_SHELL_CONFIG") || (home + "/.config/macos-shell")
    readonly property string linkPath: configDir + "/wallpaper"

    // URL de l'image utilisateur ("" = fond procédural Tahoe)
    property string source: ""
    // Chemin réel de l'image (pour cocher la vignette dans le sélecteur)
    property string realPath: ""

    // Images proposées par le sélecteur
    property var images: []

    // Change le fond : chemin absolu d'une image, ou "" pour revenir à Tahoe.
    // Si l'utilisateur a déposé un vrai fichier (pas un lien), il est conservé
    // sous wallpaper.orig plutôt qu'écrasé.
    function set(path) {
        setter.command = ["sh", "-c",
            'mkdir -p "$1"; if [ -f "$3" ] && [ ! -L "$3" ]; then mv -f "$3" "$3.orig"; fi; ' +
            'if [ -n "$2" ]; then ln -sfn "$2" "$3"; else rm -f "$3"; fi',
            "sh", configDir, path ?? "", linkPath];
        setter.running = true;
    }

    function refresh() { if (!probe.running) probe.running = true; }
    function scanImages() { if (!scanner.running) scanner.running = true; }

    Process {
        id: setter
        onExited: root.refresh()
    }

    // Lit "<chemin réel>\n<mtime>" si le fichier existe
    Process {
        id: probe
        command: ["sh", "-c", 'p="$1"; [ -e "$p" ] && printf "%s\\n%s" "$(readlink -f "$p")" "$(stat -L -c %Y "$p")"; true', "sh", root.linkPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length >= 2 && lines[0]) {
                    root.realPath = lines[0];
                    // La requête "?mtime" force le rechargement si le fichier est remplacé
                    root.source = "file://" + lines[0] + "?" + lines[1];
                } else {
                    root.realPath = "";
                    root.source = "";
                }
            }
        }
    }

    Process {
        id: scanner
        command: ["sh", "-c",
            // Dossiers de fonds d'écran uniquement (pas toute la photothèque)
            'for d in "$HOME/Pictures/Wallpapers" "$HOME/Pictures/wallpapers" "$HOME/Pictures/walls" "$HOME/Images/Fonds d’écran" ' +
            '"$HOME/Images/Wallpapers" "$HOME/.config/macos-shell/wallpapers" "$HOME/.local/share/backgrounds" /run/current-system/sw/share/backgrounds; do ' +
            '[ -d "$d" ] && find -L "$d" -maxdepth 3 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.heic" -o -iname "*.avif" \\) 2>/dev/null; ' +
            'done | sort -u | head -n 120']
        stdout: StdioCollector {
            onStreamFinished: root.images = text.split("\n").filter(l => l.length > 0)
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
