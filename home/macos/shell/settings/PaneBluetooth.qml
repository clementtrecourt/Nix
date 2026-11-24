import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.common
import qs.controlcenter as CC

// Bluetooth (Tahoe 26) : carte d'en-tête + interrupteur (« Now discoverable
// as “…”. »), My Devices (Connected / Not Connected, ⓘ : Connect, Disconnect,
// Forget This Device…), Nearby Devices (Connect au survol ; recherche tant que
// le panneau est affiché). Via Quickshell.Bluetooth (BlueZ), contrôleur
// détecté par controlcenter/Bt.
PaneBase {
    id: root

    readonly property var adapter: CC.Bt.adapter
    readonly property bool on: !!adapter && adapter.enabled
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var mine: devices.filter(d => d.paired || d.connected).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var nearby: devices.filter(d => !d.paired && !d.connected && (d.deviceName ?? "") !== "")

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

    Binding {
        when: root.on
        target: root.adapter
        property: "discovering"
        value: true
    }

    SHeaderCard {
        pane: root.spec
        description: !root.adapter ? "No Bluetooth hardware was found on this Mac."
                     : root.on ? "This Mac is discoverable as “" + (root.adapter.name || "Mac") + "” while Bluetooth settings are open."
                     : "Connect to accessories you can use for activities such as streaming music, typing, and gaming."
        SSwitch {
            checked: root.on
            enabledSwitch: !!root.adapter
            onToggled: (on) => { if (root.adapter) root.adapter.enabled = on; }
        }
    }

    SSection { visible: root.on && root.mine.length > 0; text: "My Devices" }
    SGroup {
        visible: root.on && root.mine.length > 0
        Repeater {
            model: root.mine
            SRow {
                id: dr
                required property var modelData
                title: modelData.name
                symbol: root.symbolFor(modelData)
                symbolColor: SStyle.label
                minHeight: 42
                detail: root.busy(modelData) ? (modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…" : "Connecting…")
                        : modelData.connected ? (modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%  ·  Connected" : "Connected")
                        : "Not Connected"
                Item {
                    width: 20; height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    Symbol { anchors.centerIn: parent; name: "info.circle"; size: 16; color: SStyle.secondary }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            const d = dr.modelData;
                            const p = mapToItem(null, 0, height + 4);
                            root.sw.showMenu(Qt.point(p.x - 6, p.y), [
                                d.connected ? { text: "Disconnect", action: () => d.disconnect() } : { text: "Connect", action: () => d.connect() },
                                { separator: true },
                                { text: "Forget This Device…", action: () => d.forget() }
                            ]);
                        }
                    }
                }
            }
        }
    }

    SSection { visible: root.on; text: "Nearby Devices" }
    SGroup {
        visible: root.on
        Repeater {
            model: root.nearby
            SRow {
                id: nr
                required property var modelData
                title: modelData.name
                symbol: root.symbolFor(modelData)
                symbolColor: SStyle.label
                minHeight: 42
                clickable: true
                SButton {
                    visible: nr.hovered || root.busy(nr.modelData)
                    text: root.busy(nr.modelData) ? "Connecting…" : "Connect"
                    onClicked: nr.modelData.pair()
                }
            }
        }
        SRow {
            visible: root.nearby.length === 0
            title: "Searching…"
            dimmed: true
        }
    }
    Item {
        width: parent.width
        height: 28
        Row {
            anchors.right: parent.right
            y: 4
            spacing: 10
            SButton { text: "Advanced…"; enabledButton: false }
            HelpButton {}
        }
    }
}
