pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Accès paresseux à Quickshell.Bluetooth : le service BlueZ n'est contacté que
// si la machine a un contrôleur (/sys/class/bluetooth/hci*). Sans matériel,
// `adapter` reste null et le module Bluetooth est grisé (pas d'avertissement
// D-Bus "org.bluez" dans le journal).
Singleton {
    id: root

    property bool hardware: false
    readonly property var adapter: loader.item ? loader.item.adapter : null

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/bluetooth 2>/dev/null | grep -q '^hci'"]
        onExited: code => root.hardware = code === 0
    }

    LazyLoader {
        id: loader
        active: root.hardware
        BtBinding {}
    }
}
