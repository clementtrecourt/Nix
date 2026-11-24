pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Concentration (Focus) : mode actif ("Ne pas déranger", "Sommeil",
// "Personnel", "Travail"), partagé entre le Control Center (qui le pilote) et
// les notifications (qui le lisent : pas de bannière quand doNotDisturb est
// vrai, la notification va directement au centre). Tous les modes coupent les
// bannières (pas de listes d'exceptions ici).
//
// Persisté dans ~/.local/state/macos-shell/focus.json :
//   { "doNotDisturb": true, "mode": "dnd", "until": 1764000000000, "untilKind": "hour" }
//   (until = 0 : jusqu'à désactivation)
//
// IPC : quickshell -c macos ipc call focus toggle | set true|false | get | mode <id>
Singleton {
    id: root

    // Un mode Concentration est actif
    property bool doNotDisturb: false
    // Mode actif (ou dernier utilisé) : id de `modes`
    property string mode: "dnd"
    // Fin programmée (ms depuis l'époque Unix), 0 = jusqu'à désactivation
    property real until: 0
    // Option de durée choisie : "" (sans limite), "hour", "tonight", "morning"
    property string untilKind: ""

    // Modes proposés par macOS par défaut (pictogramme et couleur de pastille)
    readonly property var modes: [
        { id: "dnd", name: "Do Not Disturb", symbol: "moon.fill", color: "#5E5CE6" },
        { id: "sleep", name: "Sleep", symbol: "bed.double.fill", color: "#30B0C7" },
        { id: "personal", name: "Personal", symbol: "person.fill", color: "#BF5AF2" },
        { id: "work", name: "Work", symbol: "person.lanyardcard.fill", color: "#32ADE6" }
    ]
    function modeInfo(id) { return modes.find(m => m.id === id) ?? modes[0]; }
    readonly property string modeName: modeInfo(mode).name
    readonly property string modeSymbol: modeInfo(mode).symbol
    readonly property color modeColor: modeInfo(mode).color

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/macos-shell"
    readonly property string stateFile: stateDir + "/focus.json"

    function setDoNotDisturb(on, untilMs, kind) {
        doNotDisturb = on;
        until = on ? (untilMs ?? 0) : 0;
        untilKind = on && until > 0 ? (kind ?? "") : "";
        save();
    }
    function toggle() { setDoNotDisturb(!doNotDisturb, 0); }

    // Active un mode (sans limite) ; re-cliquer le mode actif le désactive.
    function toggleMode(id) {
        if (doNotDisturb && mode === id) { setDoNotDisturb(false); return; }
        mode = id;
        setDoNotDisturb(true, 0);
    }
    function setMode(id) { mode = id; if (doNotDisturb) save(); }

    // Durées du sous-menu « … » d'un mode (macOS)
    function forOneHour() { setDoNotDisturb(true, Date.now() + 3600 * 1000, "hour"); }
    function untilTonight() {
        const d = new Date();
        d.setHours(19, 0, 0, 0);                   // "Jusqu'à ce soir" = 19 h
        if (d.getTime() <= Date.now()) d.setDate(d.getDate() + 1);
        setDoNotDisturb(true, d.getTime(), "tonight");
    }
    function untilTomorrowMorning() {
        const d = new Date();
        d.setDate(d.getDate() + 1);
        d.setHours(7, 0, 0, 0);                    // "Jusqu'à demain matin" = 7 h
        setDoNotDisturb(true, d.getTime(), "morning");
    }

    // Horloge (minute) : le libellé "aujourd'hui / demain" suit le temps qui passe
    property real now: Date.now()
    Timer {
        running: root.doNotDisturb && root.until > 0
        interval: 30000
        repeat: true
        onTriggered: root.now = Date.now()
    }

    // Libellé du sous-titre (OS en anglais US) : alias de untilLabelEn
    readonly property string untilLabel: untilLabelEn

    function save() {
        now = Date.now();
        writer.command = ["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$3"', "sh",
                          stateDir, JSON.stringify({ doNotDisturb: doNotDisturb, mode: mode, until: until, untilKind: untilKind }), stateFile];
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
                root.mode = root.modes.some(m => m.id === o.mode) ? o.mode : "dnd";
                root.untilKind = o.untilKind ?? "";
                root.now = Date.now();
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
        function mode(id: string): void { root.toggleMode(id); }
    }

    // ---- Libellés anglais (US) de macOS (ajout agent controlcenter) ----
    readonly property var namesEn: ({ dnd: "Do Not Disturb", sleep: "Sleep", personal: "Personal", work: "Work" })
    function nameEn(id) { return namesEn[id] ?? namesEn.dnd; }
    readonly property string modeNameEn: nameEn(mode)
    // Sous-titre du module Focus : "Until 7:00 PM", "Until tomorrow, 7:00 AM"
    readonly property string untilLabelEn: {
        if (!doNotDisturb || until <= 0) return "";
        const d = new Date(until);
        const today = new Date(now);
        const hm = d.toLocaleTimeString(Qt.locale("en_US"), "h:mm AP");
        return d.toDateString() === today.toDateString() ? "Until " + hm : "Until tomorrow, " + hm;
    }
}
