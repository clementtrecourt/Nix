import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.common
import qs.services

// Module Bluetooth déplié : interrupteur, appareils appairés (connexion au clic),
// appareils à proximité (recherche active tant que le module est ouvert).
Column {
    id: root

    width: CCStyle.width

    readonly property var adapter: Bt.adapter
    readonly property bool enabled_: !!adapter && adapter.enabled
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var paired: devices.filter(d => d.paired || d.connected)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var nearby: devices.filter(d => !d.paired && !d.connected && (d.deviceName ?? "") !== "")
    property bool nearbyOpen: false

    function symbolFor(d) {
        const i = (d.icon ?? "").toLowerCase();
        if (i.includes("headset") || i.includes("headphone") || i.includes("audio")) return "headphones";
        if (i.includes("keyboard")) return "keyboard";
        if (i.includes("mouse") || i.includes("tablet")) return "computermouse";
        if (i.includes("gaming") || i.includes("joystick")) return "gamecontroller";
        if (i.includes("phone")) return "iphone";
        if (i.includes("computer")) return "laptopcomputer";
        if (i.includes("speaker")) return "hifispeaker.fill";
        return "bluetooth";
    }
    function busy(d) { return d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting; }

    // Recherche tant que la liste des autres appareils est ouverte
    Binding {
        when: root.nearbyOpen && root.enabled_
        target: root.adapter
        property: "discovering"
        value: true
        restoreMode: Binding.RestoreValue
    }

    DetailHeader {
        title: "Bluetooth"
        hasSwitch: true
        checked: root.enabled_
        onToggled: on => { if (root.adapter) root.adapter.enabled = on; }
    }

    DetailCaption {
        visible: root.enabled_ && root.paired.length > 0
        text: "Appareils"
    }
    Repeater {
        model: root.enabled_ ? root.paired : []
        DetailRow {
            required property var modelData
            symbol: root.symbolFor(modelData)
            glyphSize: modelData && root.symbolFor(modelData) === "bluetooth" ? 15 : 16
            text: modelData.name
            active: modelData.connected
            busy: root.busy(modelData)
            detail: modelData.connected && modelData.batteryAvailable ? Math.round(modelData.battery * 100) + " %" : ""
            onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
        }
    }

    DetailCaption {
        visible: root.enabled_
        text: "Autres appareils"
        collapsible: true
        expanded: root.nearbyOpen
        onToggled: root.nearbyOpen = !root.nearbyOpen
    }
    Repeater {
        model: root.enabled_ && root.nearbyOpen ? root.nearby : []
        DetailRow {
            required property var modelData
            symbol: root.symbolFor(modelData)
            text: modelData.deviceName
            busy: root.busy(modelData)
            onClicked: modelData.pair()
        }
    }

    DetailFooter {
        text: "Réglages Bluetooth…"
        onClicked: {
            CCActions.openSettings("bluetooth");
            ShellState.close();
        }
    }
}
