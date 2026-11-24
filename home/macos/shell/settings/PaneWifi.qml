import QtQuick
import Quickshell
import Quickshell.Networking
import qs.common

// Wi‑Fi (Tahoe 26, Apple mh11935) : carte d'en-tête avec interrupteur, réseau
// connecté (point vert « Connected », Details…), Personal Hotspots, Known
// Networks (… : Auto-Join, Copy Password, Forget This Network), Other
// Networks (Connect au survol, mot de passe dans une feuille), Ask to join
// networks / hotspots, Advanced… — via Quickshell.Networking (NetworkManager).
PaneBase {
    id: root

    readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool wifiOn: !!device && Networking.wifiEnabled
    readonly property var networks: device ? device.networks.values.filter(n => (n.name ?? "") !== "") : []
    readonly property var current: networks.find(n => n.connected) ?? null
    readonly property var known: networks.filter(n => n.known && !n.connected).sort((a, b) => b.signalStrength - a.signalStrength)
    readonly property var others: networks.filter(n => !n.known && !n.connected).sort((a, b) => b.signalStrength - a.signalStrength)
    property var pskTarget: null
    property var detailNet: null

    function secured(n) { return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe; }
    function bars(n) { const s = n.signalStrength ?? 1; return s > 0.66 ? "wifi" : s > 0.33 ? "wifi.2" : "wifi.1"; }
    function join(n) {
        if (n.known || !secured(n)) { n.connect(); return; }
        pskTarget = n;
        pskSheet.pskText = "";
        pskSheet.ssidText = "";
        pskSheet.shown = true;
    }

    Component.onCompleted: if (device) device.scannerEnabled = true
    Component.onDestruction: if (device) device.scannerEnabled = false

    // ---- Ligne de réseau (icônes cadenas + force du signal à droite) ----
    component NetRow: SRow {
        id: nr
        property var net
        title: net?.name ?? ""
        clickable: true
        onClicked: if (!net.connected) root.join(net)
        Symbol { visible: root.secured(nr.net); name: "lock.fill"; size: 12; color: SStyle.secondary; anchors.verticalCenter: parent.verticalCenter }
        Symbol { name: root.bars(nr.net); size: 15; color: SStyle.label; anchors.verticalCenter: parent.verticalCenter }
        SButton {
            visible: !nr.net.connected && nr.hovered
            text: nr.net.stateChanging ? "Connecting…" : "Connect"
            onClicked: root.join(nr.net)
        }
        Item {
            visible: nr.net.known
            width: 20; height: 20
            anchors.verticalCenter: parent.verticalCenter
            Symbol { anchors.centerIn: parent; name: "ellipsis.circle"; size: 17; color: SStyle.secondary }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    const n = nr.net;
                    const p = mapToItem(null, 0, height + 4);
                    root.sw.showMenu(Qt.point(p.x - 6, p.y), [
                        { text: "Network Settings…", action: () => { root.detailNet = n; details.shown = true; } },
                        { text: "Copy Password", action: () => root.copyPassword(n.name) },
                        { separator: true },
                        { text: "Forget This Network…", action: () => n.forget() }
                    ]);
                }
            }
        }
    }

    function copyPassword(ssid) {
        Quickshell.execDetached(["sh", "-c", 'nmcli -s -g 802-11-wireless-security.psk connection show "$1" 2>/dev/null | wl-copy', "sh", ssid]);
    }

    SHeaderCard {
        pane: root.spec
        description: "Set up Wi‑Fi to wirelessly connect your Mac to the internet. Turn on Wi‑Fi, then choose a network to join."
        SSwitch {
            checked: root.wifiOn
            enabledSwitch: !!root.device
            onToggled: (on) => Networking.wifiEnabled = on
        }
    }

    SGroup {
        visible: root.wifiOn && !!root.current
        SRow {
            title: root.current?.name ?? ""
            subtitle: "Connected"
            minHeight: 52
            dotColor: SStyle.green
            Symbol { visible: root.current ? root.secured(root.current) : false; name: "lock.fill"; size: 12; color: SStyle.secondary; anchors.verticalCenter: parent.verticalCenter }
            Symbol { name: root.current ? root.bars(root.current) : "wifi"; size: 15; color: SStyle.label; anchors.verticalCenter: parent.verticalCenter }
            SButton { text: "Details…"; onClicked: { root.detailNet = root.current; details.shown = true; } }
        }
    }

    SSection { visible: root.wifiOn && root.known.length > 0; text: "Known Networks" }
    SGroup {
        visible: root.wifiOn && root.known.length > 0
        Repeater { model: root.known; NetRow { required property var modelData; net: modelData } }
    }

    SSection { visible: root.wifiOn; text: "Other Networks" }
    SGroup {
        visible: root.wifiOn
        Repeater { model: root.others; NetRow { required property var modelData; net: modelData } }
        SRow {
            visible: root.others.length === 0
            title: "Searching for networks…"
            dimmed: true
        }
        SRow {
            title: "Other…"
            clickable: true
            onClicked: { root.pskTarget = null; pskSheet.ssidText = ""; pskSheet.pskText = ""; pskSheet.shown = true; }
        }
    }

    SGroup {
        SRow {
            title: "Ask to join networks"
            subtitle: "Known networks will be joined automatically. If no known networks are available, you will be notified of available networks."
            SPopUp {
                options: [{ text: "Off", value: "off" }, { text: "Notify", value: "notify" }, { text: "Ask", value: "ask" }]
                value: Prefs.v.askToJoin
                onActivated: (v) => Prefs.set("askToJoin", v)
            }
        }
        SRow {
            title: "Ask to join hotspots"
            subtitle: "Allow this Mac to automatically discover nearby personal hotspots when no Wi‑Fi network is available."
            SPopUp {
                options: [{ text: "Never", value: "never" }, { text: "Ask to Join", value: "ask" }, { text: "Automatic", value: "auto" }]
                value: Prefs.v.askToJoinHotspots
                onActivated: (v) => Prefs.set("askToJoinHotspots", v)
            }
        }
    }
    Item {
        width: parent.width
        height: 28
        Row {
            anchors.right: parent.right
            y: 4
            spacing: 10
            SButton { text: "Advanced…"; onClicked: advanced.shown = true }
            HelpButton {}
        }
    }

    // ---- Feuilles ----
    SSheet {
        id: pskSheet
        sheetWidth: 400
        doneText: "OK"
        cancelText: "Cancel"
        property string pskText: ""
        property string ssidText: ""
        doneEnabled: pskText.length >= 8 || (!root.pskTarget && ssidText.length > 0)
        onDone: {
            if (root.pskTarget) root.pskTarget.connectWithPsk(pskSheet.pskText);
            else Quickshell.execDetached(["nmcli", "device", "wifi", "connect", pskSheet.ssidText, "password", pskSheet.pskText, "hidden", "yes"]);
        }
        body: Component {
            Column {
                width: parent ? parent.width : 0
                spacing: SStyle.groupSpacing
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: root.pskTarget ? "The Wi‑Fi network “" + root.pskTarget.name + "” requires a WPA2 password."
                                         : "Find and join a Wi‑Fi network."
                    font.family: Theme.font
                    font.pixelSize: SStyle.body
                    font.weight: Font.Bold
                    color: SStyle.label
                }
                SGroup {
                    SRow {
                        visible: !root.pskTarget
                        title: "Network Name"
                        STextField { fieldWidth: 200; onTextChanged: pskSheet.ssidText = text; Component.onCompleted: if (!root.pskTarget) focusField() }
                    }
                    SRow {
                        title: "Password"
                        STextField { secret: true; fieldWidth: 200; onTextChanged: pskSheet.pskText = text; Component.onCompleted: if (root.pskTarget) focusField(); onAccepted: if (pskSheet.doneEnabled) { pskSheet.shown = false; pskSheet.done(); } }
                    }
                }
            }
        }
    }
    SSheet {
        id: details
        sheetWidth: 460
        doneText: "OK"
        body: Component {
            Column {
                width: parent ? parent.width : 0
                spacing: SStyle.groupSpacing
                SHeaderCard {
                    pane: root.spec
                    title: root.detailNet?.name ?? ""
                    description: root.detailNet?.connected ? "Connected" : "Not Connected"
                }
                SGroup {
                    SRow { title: "Automatically join this network"; SSwitch { checked: true; enabledSwitch: false } }
                    SRow { title: "Low data mode"; SSwitch { checked: false; enabledSwitch: false } }
                    SRow { title: "IP address"; detail: ipProc.ip || "—" }
                    SRow { title: "Router"; detail: ipProc.router || "—" }
                    SRow { title: "Wi‑Fi address"; detail: root.device?.address ?? "—" }
                }
                SButton {
                    text: "Forget This Network…"
                    visible: !!root.detailNet && root.detailNet.known
                    onClicked: { details.shown = false; root.detailNet.forget(); }
                }
            }
        }
    }
    SSheet {
        id: advanced
        sheetWidth: 460
        body: Component {
            Column {
                width: parent ? parent.width : 0
                spacing: SStyle.groupSpacing
                SSection { text: "Known Networks" }
                SGroup {
                    Repeater {
                        model: root.networks.filter(n => n.known)
                        SRow { required property var modelData; title: modelData.name; symbol: root.secured(modelData) ? "lock.fill" : "" }
                    }
                }
                SGroup {
                    SRow { title: "Wi‑Fi MAC address"; detail: root.device?.address ?? "—" }
                }
            }
        }
    }
    QtObject {
        id: ipProc
        property string ip: ""
        property string router: ""
    }
    Timer {
        running: details.shown
        triggeredOnStart: true
        interval: 3000
        onTriggered: ipProbe.running = true
    }
    ProcessText {
        id: ipProbe
        command: ["sh", "-c", 'd=$(nmcli -t -f DEVICE,TYPE device | awk -F: \'$2=="wifi"{print $1; exit}\'); ' +
                              'nmcli -g IP4.ADDRESS,IP4.GATEWAY device show "$d" 2>/dev/null']
        onDone: (t) => { const l = t.trim().split("\n"); ipProc.ip = (l[0] ?? "").split("/")[0].split(" | ")[0]; ipProc.router = l[1] ?? ""; }
    }
}
