pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night Shift (Control Center > Écran) : couleurs plus chaudes via hyprsunset
// (protocole hyprland-ctm). Tant que `on` est vrai, un processus hyprsunset
// tient la température ; l'arrêter rend les couleurs normales.
// Sans hyprsunset installé, l'option reste grisée (available = false).
//
// MACOS_SHELL_DEV=1 : jamais lancé (banc de test imbriqué), seul l'état change.
Singleton {
    id: root

    readonly property bool devMode: (Quickshell.env("MACOS_SHELL_DEV") ?? "") !== ""
    property bool available: false
    property bool on: false
    // Température "Plus chaude" de macOS (~3400 K)
    property int temperature: 3400

    function toggle() { if (available) on = !on; }

    Process {
        command: ["sh", "-c", "command -v hyprsunset"]
        running: true
        onExited: code => root.available = code === 0
    }

    Process {
        running: root.on && root.available && !root.devMode
        command: ["hyprsunset", "-t", String(root.temperature)]
    }
}
