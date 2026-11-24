import QtQuick
import Quickshell
import Quickshell.Networking
import qs.common

// Network (Tahoe 26) : services réseau avec pastille et point d'état
// (Connected vert, Not Connected rouge, Inactive gris), puis Firewall ; un
// clic ouvre le détail (Wi‑Fi -> panneau Wi‑Fi, Ethernet -> feuille IP / DNS).
PaneBase {
    id: root

    readonly property var devs: Networking.devices.values.filter(d => d.type === DeviceType.Wifi || d.type === DeviceType.Wired)
    property var info: ({})          // nmcli : { <iface>: { ip, gw, dns, mac } }
    property string firewall: ""
    property var sheetDev: null

    function nameOf(d) { return d.type === DeviceType.Wifi ? "Wi‑Fi" : (root.devs.filter(x => x.type === DeviceType.Wired).length > 1 ? "Ethernet (" + d.name + ")" : "Ethernet"); }
    function stateOf(d) {
        if (d.type === DeviceType.Wifi && !Networking.wifiEnabled) return ["Off", SStyle.gray];
        if (d.connected) return ["Connected", SStyle.green];
        return [d.type === DeviceType.Wifi ? "Not Connected" : "Not Connected", SStyle.red];
    }

    Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: probe.running = true }
    ProcessText {
        id: probe
        command: ["sh", "-c", 'for d in $(nmcli -t -f DEVICE device 2>/dev/null); do printf "@%s\\n" "$d"; nmcli -t -g IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,GENERAL.HWADDR device show "$d" 2>/dev/null; done; ' +
                              'printf "#fw\\n"; systemctl is-active firewall 2>/dev/null || true']
        onDone: (t) => {
            const o = {};
            let cur = null, k = 0;
            const parts = t.split("#fw\n");
            for (const l of parts[0].split("\n")) {
                if (l.startsWith("@")) { cur = l.slice(1); o[cur] = { ip: "", gw: "", dns: "", mac: "" }; k = 0; continue; }
                if (!cur) continue;
                const v = l.replace(/\\:/g, ":");
                if (k === 0) o[cur].ip = v.split("/")[0].split(" | ")[0];
                else if (k === 1) o[cur].gw = v;
                else if (k === 2) o[cur].dns = v.split(" | ").join(", ");
                else if (k === 3) o[cur].mac = v;
                k++;
            }
            root.info = o;
            root.firewall = (parts[1] ?? "").trim();
        }
    }

    SGroup {
        Repeater {
            model: root.devs
            SRow {
                required property var modelData
                readonly property var st: root.stateOf(modelData)
                title: root.nameOf(modelData)
                subtitle: modelData.type === DeviceType.Wifi && modelData.connected
                          ? (modelData.networks.values.find(n => n.connected)?.name ?? "") : ""
                pane: modelData.type === DeviceType.Wifi ? Nav.info("wifi") : ({ icon: "dot.radiowaves.forward", c: Nav.blue })
                minHeight: 42
                chevron: true
                Row {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 8; height: 8; radius: 4; color: st[1]; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: st[0]; font.family: Theme.font; font.pixelSize: SStyle.body; color: SStyle.secondary }
                }
                onClicked: {
                    if (modelData.type === DeviceType.Wifi) Nav.go("wifi");
                    else { root.sheetDev = modelData; sheet.shown = true; }
                }
            }
        }
        SRow {
            visible: root.devs.length === 0
            title: "No network services"
            dimmed: true
        }
    }
    SGroup {
        SRow {
            title: "Firewall"
            pane: ({ icon: "checkmark.shield", c: Nav.blue })
            minHeight: 42
            chevron: true
            Row {
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { width: 8; height: 8; radius: 4; color: root.firewall === "active" ? SStyle.green : SStyle.gray; anchors.verticalCenter: parent.verticalCenter }
                Text { text: root.firewall === "active" ? "Active" : "Inactive"; font.family: Theme.font; font.pixelSize: SStyle.body; color: SStyle.secondary }
            }
            onClicked: fwSheet.shown = true
        }
    }
    Item {
        width: parent.width
        height: 28
        Row {
            anchors.right: parent.right
            y: 4
            spacing: 10
            SButton {
                text: "…"
                minWidth: 34
                onClicked: {
                    const p = mapToItem(null, 0, height + 4);
                    root.sw.showMenu(Qt.point(p.x - 6, p.y), [
                        { text: "Add Service…", enabled: false },
                        { text: "Set Service Order…", enabled: false },
                        { separator: true },
                        { text: "Open Network Connections…", action: () => Quickshell.execDetached(["sh", "-c", "nm-connection-editor || nmtui"]) }
                    ]);
                }
            }
            HelpButton {}
        }
    }

    SSheet {
        id: sheet
        sheetWidth: 460
        doneText: "OK"
        readonly property var i: root.sheetDev ? (root.info[root.sheetDev.name] ?? {}) : {}
        body: Component {
            Column {
                width: parent ? parent.width : 0
                spacing: SStyle.groupSpacing
                SHeaderCard {
                    pane: ({ icon: "dot.radiowaves.forward", c: Nav.blue })
                    title: root.sheetDev ? root.nameOf(root.sheetDev) : ""
                    description: root.sheetDev ? root.stateOf(root.sheetDev)[0] : ""
                }
                SGroup {
                    SRow { title: "IP address"; detail: sheet.i.ip || "—" }
                    SRow { title: "Subnet mask"; detail: sheet.i.ip ? "255.255.255.0" : "—" }
                    SRow { title: "Router"; detail: sheet.i.gw || "—" }
                    SRow { title: "DNS Servers"; detail: sheet.i.dns || "—" }
                    SRow { title: "MAC address"; detail: sheet.i.mac || (root.sheetDev?.address ?? "—") }
                    SRow { title: "Speed"; detail: root.sheetDev && root.sheetDev.linkSpeed ? root.sheetDev.linkSpeed + " Mb/s" : "—" }
                }
            }
        }
    }
    SSheet {
        id: fwSheet
        sheetWidth: 460
        doneText: "OK"
        body: Component {
            Column {
                width: parent ? parent.width : 0
                spacing: SStyle.groupSpacing
                SHeaderCard {
                    pane: ({ icon: "checkmark.shield", c: Nav.blue })
                    title: "Firewall"
                    description: "The firewall is managed by your NixOS configuration (networking.firewall). It prevents unwanted incoming network connections."
                }
                SGroup {
                    SRow { title: "Firewall"; detail: root.firewall === "active" ? "Active" : "Inactive" }
                }
            }
        }
    }
}
