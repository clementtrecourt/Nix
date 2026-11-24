pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Luminosité de l'écran et du rétroéclairage clavier.
//
// Écran, deux moyens (le premier disponible l'emporte) :
//  - "backlight" : rétroéclairage interne via brightnessctl
//    (`brightnessctl -m` répond "device,class,courant,pourcentage%,max") ;
//  - "ddc" : écrans externes via DDC/CI (ddcutil, code VCP 0x10). Détection
//    asynchrone au démarrage (`ddcutil detect --brief`), lecture `getvcp 10`,
//    écriture `setvcp 10 <v>`. DDC est lent (~50-200 ms par commande) : une
//    seule écriture à la fois par écran, la dernière valeur demandée est
//    envoyée dès que la précédente est terminée (pas de file d'attente).
//    Un seul curseur pilote TOUS les écrans DDC (valeur affichée : le premier).
// Sans l'un ni l'autre, `available` reste faux (module Display grisé).
//
// MACOS_SHELL_DEV=1 : n'écrit jamais la luminosité (banc de test imbriqué),
// seule la valeur affichée change ; sauf si MACOS_DDCUTIL désigne un ddcutil
// de remplacement (banc : faux ddcutil qui journalise ses appels).
Singleton {
    id: root

    readonly property bool devMode: (Quickshell.env("MACOS_SHELL_DEV") ?? "") !== ""
    // Exécutable ddcutil (MACOS_DDCUTIL : remplacement pour le banc de test)
    readonly property string ddcutilCmd: Quickshell.env("MACOS_DDCUTIL") || "ddcutil"
    readonly property bool ddcWritable: !devMode || (Quickshell.env("MACOS_DDCUTIL") ?? "") !== ""

    // Écran
    // "" (aucun moyen) | "backlight" | "ddc"
    property string backend: ""
    readonly property bool available: backend !== "" || fake
    property real value: 0.5            // 0..1
    // Débogage : luminosité simulée (machine de test sans écran pilotable)
    property bool fake: false
    // Écrans DDC détectés : [{ bus, connector, model, max, value }]
    property var ddcDisplays: []
    // Clavier
    property bool kbdAvailable: false
    property real kbdValue: 0

    // Pas des touches de luminosité (macOS : 16 crans)
    readonly property real step: 1 / 16

    signal screenRefreshed()
    signal keyboardRefreshed()

    function parse(line) {
        const f = line.trim().split(",");
        if (f.length < 5) return -1;
        const cur = Number(f[2]), max = Number(f[4]);
        return max > 0 ? cur / max : -1;
    }

    // Relit les valeurs. En DDC, pas de relecture pendant / juste après une
    // écriture (le moniteur renverrait l'ancienne valeur).
    function refresh() {
        if (!backlightProbe.running) backlightProbe.running = true;
        if (!kbdProbe.running) kbdProbe.running = true;
    }

    function clamp01(v) { return Math.max(0, Math.min(1, v)); }

    function set(v) {
        value = clamp01(v);
        if (fake) return;
        if (backend === "backlight") {
            if (!devMode) writeTimer.restart();
        } else if (backend === "ddc") {
            lastWrite = Date.now();
            for (const w of ddcWriters.instances) w.request(value);
        }
    }
    // Touches de luminosité : un cran vers le haut (+1) ou le bas (-1)
    function stepBy(dir) {
        if (!available) return false;
        // Aligne sur la grille des 16 crans (comme macOS)
        const n = Math.round(value / step) + dir;
        set(n * step);
        return true;
    }

    function setKeyboard(v) {
        kbdValue = clamp01(v);
        if (!devMode && kbdAvailable)
            Quickshell.execDetached(["brightnessctl", "-q", "-d", "*kbd_backlight*", "set", Math.round(kbdValue * 100) + "%"]);
    }
    function stepKeyboard(dir) {
        if (!kbdAvailable) return false;
        setKeyboard((Math.round(kbdValue / step) + dir) * step);
        return true;
    }

    // ---- Rétroéclairage interne (brightnessctl) ----
    Timer {
        id: writeTimer
        interval: 30
        onTriggered: Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "set",
                                              Math.max(1, Math.round(root.value * 100)) + "%"])
    }

    // `command -v` : pas d'erreur dans le journal si l'outil est absent
    Process {
        id: backlightProbe
        command: ["sh", "-c", "command -v brightnessctl >/dev/null 2>&1 && brightnessctl -m -c backlight 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = root.parse(text);
                if (v >= 0) {
                    root.backend = "backlight";
                    root.value = v;
                    root.screenRefreshed();
                } else if (root.backend === "backlight") {
                    root.backend = "";
                    root.screenRefreshed();
                } else if (root.backend === "ddc") {
                    root.readDdc();
                } else {
                    if (!root.ddcDetected) root.detectDdc();
                    root.screenRefreshed();
                }
            }
        }
    }
    Process {
        id: kbdProbe
        command: ["sh", "-c", "command -v brightnessctl >/dev/null 2>&1 && brightnessctl -m -d '*kbd_backlight*' 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = root.parse(text);
                root.kbdAvailable = v >= 0;
                if (v >= 0) root.kbdValue = v;
                root.keyboardRefreshed();
            }
        }
    }

    // ---- Écrans externes (DDC/CI) ----
    property bool ddcDetected: false
    property real lastWrite: 0

    function detectDdc() {
        ddcDetected = true;
        if (!ddcDetect.running) ddcDetect.running = true;
    }

    // Lecture de la luminosité de chaque écran (sauf écriture récente)
    function readDdc() {
        if (Date.now() - lastWrite < 2000) { screenRefreshed(); return; }
        for (const w of ddcWriters.instances) w.read();
    }

    // Sortie de `ddcutil detect --brief` :
    //   Display 1
    //      I2C bus:  /dev/i2c-4
    //      DRM connector:  card1-DP-3
    //      Monitor:  GSM:LG ULTRAGEAR:
    //   Invalid display        <- écran sans DDC/CI : ignoré
    function parseDetect(text) {
        const out = [];
        let cur = null;
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (/^Display \d+/.test(line)) { cur = { bus: -1, connector: "", model: "" }; out.push(cur); continue; }
            if (/^(Invalid|Phantom) display/i.test(line) || line === "") { if (line !== "") cur = null; continue; }
            if (!cur) continue;
            let m;
            if ((m = line.match(/^I2C bus:\s*\/dev\/i2c-(\d+)/))) cur.bus = Number(m[1]);
            else if ((m = line.match(/^DRM connector:\s*(?:card\d+-)?(\S+)/))) cur.connector = m[1];
            else if ((m = line.match(/^Monitor:\s*[^:]*:([^:]*):/))) cur.model = m[1].trim();
        }
        return out.filter(d => d.bus >= 0);
    }

    Process {
        id: ddcDetect
        command: ["sh", "-c", 'command -v "$1" >/dev/null 2>&1 || exit 0; "$1" detect --brief 2>/dev/null; true', "sh", root.ddcutilCmd]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = root.parseDetect(text);
                root.ddcDisplays = found;
                if (found.length > 0 && root.backend === "") {
                    root.backend = "ddc";
                    root.readDdc();
                }
            }
        }
    }

    // Un pilote par écran DDC : lecture, écriture limitée en débit
    Variants {
        id: ddcWriters
        model: root.ddcDisplays
        delegate: QtObject {
            id: w
            required property var modelData
            readonly property int bus: modelData.bus
            property real max: 100
            // Dernière valeur demandée (0..1), -1 = rien à écrire
            property real pending: -1

            function request(v) {
                pending = v;
                if (!root.ddcWritable) { pending = -1; return; }
                if (!setter.running) flush();
            }
            function flush() {
                if (pending < 0) return;
                const raw = Math.round(pending * max);
                pending = -1;
                setter.command = [root.ddcutilCmd, "--bus", String(bus), "--noverify", "--skip-ddc-checks",
                                  "setvcp", "10", String(raw)];
                setter.running = true;
            }
            function read() { if (!getter.running && !setter.running) getter.running = true; }

            readonly property Process setter: Process {
                // Écriture suivante dès la fin de la précédente (débit naturel du bus)
                onExited: w.flush()
            }
            // `getvcp --brief` : "VCP 10 C <courant> <max>"
            readonly property Process getter: Process {
                command: [root.ddcutilCmd, "--bus", String(w.bus), "--brief", "--skip-ddc-checks", "getvcp", "10"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const m = text.match(/VCP\s+10\s+C\s+(\d+)\s+(\d+)/);
                        if (m && Number(m[2]) > 0) {
                            w.max = Number(m[2]);
                            // Le premier écran donne la valeur affichée
                            if (root.ddcDisplays.length > 0 && root.ddcDisplays[0].bus === w.bus
                                    && Date.now() - root.lastWrite >= 2000)
                                root.value = Number(m[1]) / w.max;
                        }
                        root.screenRefreshed();
                    }
                }
            }
        }
    }

    Component.onCompleted: refresh()
}
