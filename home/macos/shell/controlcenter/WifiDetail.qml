import QtQuick
import Quickshell
import Quickshell.Networking
import qs.common
import qs.services

// Module Wi-Fi déplié : interrupteur, réseaux connus, autres réseaux (repliable),
// saisie du mot de passe pour un réseau protégé inconnu, lien vers les réglages.
Column {
    id: root

    width: CCStyle.width

    readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var networks: device ? device.networks.values.filter(n => (n.name ?? "") !== "") : []
    readonly property var known: networks.filter(n => n.known || n.connected)
        .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
    readonly property var others: networks.filter(n => !n.known && !n.connected)
        .sort((a, b) => b.signalStrength - a.signalStrength)
    property bool othersOpen: known.length === 0
    property var pskTarget: null

    function strengthSymbol(n) {
        const s = n.signalStrength ?? 1;
        return s > 0.6 ? "wifi" : s > 0.3 ? "wifi.2" : "wifi.1";
    }
    function secured(n) { return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe; }
    function activate(n) {
        if (n.connected) { n.disconnect(); return; }
        if (!n.known && secured(n)) { pskTarget = n; pskField.text = ""; pskField.forceActiveFocus(); return; }
        n.connect();
    }

    // Recherche des réseaux tant que le module est déplié
    Component.onCompleted: if (device) device.scannerEnabled = true
    Component.onDestruction: if (device) device.scannerEnabled = false

    DetailHeader {
        title: "Wi-Fi"
        hasSwitch: true
        checked: Networking.wifiEnabled
        onToggled: on => Networking.wifiEnabled = on
    }

    DetailCaption {
        visible: Networking.wifiEnabled && root.known.length > 0
        text: root.known.length > 1 ? "Réseaux connus" : "Réseau connu"
    }
    Repeater {
        model: Networking.wifiEnabled ? root.known : []
        DetailRow {
            required property var modelData
            symbol: root.strengthSymbol(modelData)
            text: modelData.name
            active: modelData.connected
            busy: modelData.stateChanging
            trailingSymbol: root.secured(modelData) ? "lock.fill" : ""
            onClicked: root.activate(modelData)
        }
    }

    DetailCaption {
        visible: Networking.wifiEnabled
        text: "Autres réseaux"
        collapsible: true
        expanded: root.othersOpen
        onToggled: root.othersOpen = !root.othersOpen
    }
    Repeater {
        model: Networking.wifiEnabled && root.othersOpen ? root.others : []
        DetailRow {
            required property var modelData
            symbol: root.strengthSymbol(modelData)
            text: modelData.name
            busy: modelData.stateChanging
            trailingSymbol: root.secured(modelData) ? "lock.fill" : ""
            onClicked: root.activate(modelData)
        }
    }

    // Mot de passe d'un réseau protégé
    Item {
        visible: root.pskTarget !== null
        width: parent.width
        height: visible ? 64 : 0

        Text {
            x: 16
            y: 4
            width: parent.width - 32
            text: "Mot de passe pour « " + (root.pskTarget?.name ?? "") + " »"
            color: CCStyle.textSecondary
            font.family: Theme.font
            font.pixelSize: CCStyle.captionSize
            elide: Text.ElideRight
        }
        Rectangle {
            x: 14
            y: 24
            width: parent.width - 28
            height: 28
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.12)
            border.width: pskField.activeFocus ? 2 : 0
            border.color: Qt.rgba(0.04, 0.52, 1, 0.8)

            TextInput {
                id: pskField
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: CCStyle.text
                font.family: Theme.font
                font.pixelSize: 13
                clip: true
                Keys.onReturnPressed: {
                    if (root.pskTarget && text.length > 0) root.pskTarget.connectWithPsk(text);
                    root.pskTarget = null;
                }
                Keys.onEscapePressed: event => { root.pskTarget = null; event.accepted = true; }
            }
        }
    }

    DetailFooter {
        text: "Réglages Wi-Fi…"
        onClicked: {
            Quickshell.execDetached(["gnome-control-center", "wifi"]);
            ShellState.close();
        }
    }
}
