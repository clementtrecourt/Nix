import QtQuick
import Quickshell
import qs.common

// General > About (Tahoe 26) : image de la machine, nom du modèle en gras,
// sous-titre, puis Name (nom d'hôte, modifiable), Chip/Processor, Graphics,
// Memory, Serial number, la ligne du système (NixOS + version), Displays,
// Storage, System Report… — avec les vraies informations de la machine.
PaneBase {
    id: root

    property var monitors: []
    Component.onCompleted: { Machine.refresh(); mon.running = true; }
    ProcessText {
        id: mon
        command: ["hyprctl", "monitors", "-j"]
        onDone: (t) => { try { root.monitors = JSON.parse(t); } catch (e) {} }
    }
    ProcessText { id: rename }

    Item {
        width: parent.width
        height: 182
        MacImage {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            laptop: Machine.laptop
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 120
            text: Machine.modelName
            font.family: Theme.font
            font.pixelSize: 20
            font.weight: Font.Bold
            color: SStyle.label
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 147
            text: Machine.subtitle
            font.family: Theme.font
            font.pixelSize: SStyle.small
            color: SStyle.secondary
        }
    }
    SGroup {
        SRow {
            title: "Name"
            STextField {
                id: nameField
                framed: false
                fieldWidth: 220
                text: Machine.hostName
                onAccepted: (t) => {
                    if (!t.trim()) return;
                    rename.command = ["hostnamectl", "set-hostname", "--pretty", t.trim()];
                    rename.running = true;
                    Qt.callLater(Machine.refresh);
                }
            }
        }
        SRow { title: Machine.x86 ? "Processor" : "Chip"; detail: Machine.cpu }
        SRow { visible: Machine.gpu !== ""; title: "Graphics"; detail: Machine.gpu }
        SRow { title: "Memory"; detail: Machine.memory }
        SRow { title: "Serial number"; detail: Machine.info.host ?? "—" }
    }
    SGroup {
        SRow {
            title: "NixOS " + Machine.codename
            pane: ({ icon: "nixos", c: ["#7EBAE4", "#4C79C7"] })
            minHeight: 42
            detail: "Version " + (Machine.info.version ?? "")
        }
    }
    SSection { text: "Displays" }
    SGroup {
        Repeater {
            model: root.monitors
            SRow {
                required property var modelData
                title: modelData.description ? modelData.description.replace(/\s+0x[0-9A-F]+$/i, "").replace(/\s+[A-Z0-9]{6,}$/, "") : modelData.name
                subtitle: modelData.width + " × " + modelData.height + (modelData.focused ? "  ·  Main display" : "")
                pane: Nav.info("displays")
                minHeight: 48
            }
        }
        SRow {
            title: ""
            SButton { text: "Display Settings…"; onClicked: Nav.go("displays") }
        }
    }
    SSection { text: "Storage" }
    SGroup {
        SRow {
            title: Machine.diskName
            subtitle: Machine.size(Machine.disk.avail) + " available of " + Machine.size(Machine.disk.total)
            pane: Nav.info("storage")
            minHeight: 48
            SButton { text: "Storage Settings…"; onClicked: Nav.go("storage") }
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
                text: "System Report…"
                onClicked: Quickshell.execDetached(["sh", "-c", "command -v hardinfo2 >/dev/null && exec hardinfo2; command -v hardinfo >/dev/null && exec hardinfo; exec kitty -e sh -c 'fastfetch || neofetch; read'"])
            }
            HelpButton {}
        }
    }
}
