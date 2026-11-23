pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Luminosité de l'écran et du rétroéclairage clavier, via brightnessctl.
// `brightnessctl -m` répond "device,class,courant,pourcentage%,max".
//
// MACOS_SHELL_DEV=1 : n'écrit jamais la luminosité (banc de test imbriqué),
// seule la valeur affichée change.
Singleton {
    id: root

    readonly property bool devMode: (Quickshell.env("MACOS_SHELL_DEV") ?? "") !== ""

    // Écran
    property bool available: false
    property real value: 0.5            // 0..1
    // Clavier
    property bool kbdAvailable: false
    property real kbdValue: 0

    signal screenRefreshed()
    signal keyboardRefreshed()

    function parse(line) {
        const f = line.trim().split(",");
        if (f.length < 5) return -1;
        const cur = Number(f[2]), max = Number(f[4]);
        return max > 0 ? cur / max : -1;
    }

    function refresh() { screenProbe.running = true; kbdProbe.running = true; }

    // Écriture débouncée : le curseur envoie beaucoup de valeurs.
    function set(v) {
        value = Math.max(0, Math.min(1, v));
        if (!devMode && available) writeTimer.restart();
    }
    function setKeyboard(v) {
        kbdValue = Math.max(0, Math.min(1, v));
        if (!devMode && kbdAvailable)
            Quickshell.execDetached(["brightnessctl", "-q", "-d", "*kbd_backlight*", "set", Math.round(kbdValue * 100) + "%"]);
    }

    Timer {
        id: writeTimer
        interval: 30
        onTriggered: Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "set",
                                              Math.max(1, Math.round(root.value * 100)) + "%"])
    }

    Process {
        id: screenProbe
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = root.parse(text);
                root.available = v >= 0;
                if (v >= 0) root.value = v;
                root.screenRefreshed();
            }
        }
    }
    Process {
        id: kbdProbe
        command: ["brightnessctl", "-m", "-d", "*kbd_backlight*"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = root.parse(text);
                root.kbdAvailable = v >= 0;
                if (v >= 0) root.kbdValue = v;
                root.keyboardRefreshed();
            }
        }
    }

    Component.onCompleted: refresh()
}
