import QtQuick
import Quickshell.Bluetooth

// Instancié par Bt.qml seulement si un contrôleur Bluetooth existe.
QtObject {
    readonly property var adapter: Bluetooth.defaultAdapter
}
