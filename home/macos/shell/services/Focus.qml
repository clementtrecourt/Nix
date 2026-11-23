pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Concentration (Focus) : état "Ne pas déranger", partagé entre le Control
// Center (qui le pilote) et les notifications (qui le lisent : pas de bannière
// quand doNotDisturb est vrai, la notification va directement au centre).
//
// Persisté dans ~/.local/state/macos-shell/focus.json :
//   { "doNotDisturb": true, "until": 1764000000000 }   (until = 0 : sans limite)
//
// IPC : quickshell -c macos ipc call focus toggle | set true|false | get
Singleton {
    id: root

    // Ne pas déranger actif
    property bool doNotDisturb: false
    // Fin programmée (ms depuis l'époque Unix), 0 = jusqu'à désactivation
    property real until: 0

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/macos-shell"
    readonly property string stateFile: stateDir + "/focus.json"

    function setDoNotDisturb(on, untilMs) {
        doNotDisturb = on;
        until = on ? (untilMs ?? 0) : 0;
        save();
    }
    function toggle() { setDoNotDisturb(!doNotDisturb, 0); }

    // Raccourcis des options du menu Concentration de macOS
    function forOneHour() { setDoNotDisturb(true, Date.now() + 3600 * 1000); }
    function untilTonight() {
        const d = new Date();
        d.setHours(19, 0, 0, 0);                   // "Jusqu'à ce soir" = 19 h
        if (d.getTime() <= Date.now()) d.setDate(d.getDate() + 1);
        setDoNotDisturb(true, d.getTime());
    }
    function untilTomorrowMorning() {
        const d = new Date();
        d.setDate(d.getDate() + 1);
        d.setHours(7, 0, 0, 0);                    // "Jusqu'à demain matin" = 7 h
        setDoNotDisturb(true, d.getTime());
    }

    // Libellé du sous-titre ("Jusqu'à 19:00", ...)
    readonly property string untilLabel: {
        if (!doNotDisturb || until <= 0) return "";
        const d = new Date(until);
        const today = new Date();
        const hm = d.toLocaleTimeString(Qt.locale("fr_FR"), "HH:mm");
        return d.getDate() === today.getDate() ? "Jusqu'à " + hm : "Jusqu'à demain " + hm;
    }

    function save() {
        writer.command = ["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$3"', "sh",
                          stateDir, JSON.stringify({ doNotDisturb: doNotDisturb, until: until }), stateFile];
        writer.running = true;
    }

    Process { id: writer }

    FileView {
        path: root.stateFile
        printErrors: false
        onLoaded: {
            try {
                const o = JSON.parse(text());
                root.doNotDisturb = !!o.doNotDisturb;
                root.until = Number(o.until) || 0;
            } catch (e) {}
        }
    }

    // Expiration de la fin programmée
    Timer {
        running: root.doNotDisturb && root.until > 0
        interval: 15000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (Date.now() >= root.until) root.setDoNotDisturb(false)
    }

    IpcHandler {
        target: "focus"
        function toggle(): void { root.toggle(); }
        function set(on: bool): void { root.setDoNotDisturb(on, 0); }
        function get(): bool { return root.doNotDisturb; }
    }
}
