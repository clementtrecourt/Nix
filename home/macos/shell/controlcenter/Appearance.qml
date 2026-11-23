pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Apparence (Control Center > Mode sombre) : pilote Theme.dark ET le système
// (gsettings color-scheme + thème GTK MacTahoe-Dark / MacTahoe-Light).
//
// État persisté dans ~/.local/state/macos-shell/appearance.json ({"dark": true}).
// Au démarrage on ne fait que LIRE (fichier, sinon gsettings) : le système
// n'est modifié que sur action explicite (setDark), pour ne pas écraser les
// réglages au lancement de plusieurs instances.
//
// MACOS_SHELL_DEV=1 : n'appelle pas gsettings (banc de test imbriqué).
Singleton {
    id: root

    readonly property bool dark: Theme.dark
    readonly property bool devMode: (Quickshell.env("MACOS_SHELL_DEV") ?? "") !== ""
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/macos-shell"
    readonly property string stateFile: stateDir + "/appearance.json"

    function toggle() { setDark(!Theme.dark); }

    function setDark(d) {
        Theme.dark = d;
        writer.command = ["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$3"', "sh",
                          stateDir, JSON.stringify({ dark: d }), stateFile];
        writer.running = true;
        if (devMode) return;
        // gsettings si disponible (schémas installés), sinon dconf directement.
        Quickshell.execDetached(["sh", "-c",
            'if command -v gsettings >/dev/null; then ' +
            '  gsettings set org.gnome.desktop.interface color-scheme "$1"; gsettings set org.gnome.desktop.interface gtk-theme "$2"; ' +
            'elif command -v dconf >/dev/null; then ' +
            "  dconf write /org/gnome/desktop/interface/color-scheme \"'$1'\"; dconf write /org/gnome/desktop/interface/gtk-theme \"'$2'\"; " +
            'fi', "sh", d ? "prefer-dark" : "prefer-light", d ? "MacTahoe-Dark" : "MacTahoe-Light"]);
    }

    Process { id: writer }

    // Pas de fichier d'état : on suit le réglage système courant.
    Process {
        id: probe
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t.length > 0) Theme.dark = t.indexOf("dark") >= 0;
            }
        }
    }

    FileView {
        path: root.stateFile
        printErrors: false
        onLoaded: {
            try { Theme.dark = !!JSON.parse(text()).dark; } catch (e) { probe.running = true; }
        }
        onLoadFailed: probe.running = true
    }

    IpcHandler {
        target: "appearance"
        function toggle(): void { root.toggle(); }
        function setDark(d: bool): void { root.setDark(d); }
        function isDark(): bool { return Theme.dark; }
    }
}
