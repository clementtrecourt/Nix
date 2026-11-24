import QtQuick
import Quickshell
import qs.common

// General > Storage (Tahoe 26) : nom du disque, « X GB of Y GB used », barre
// segmentée (couleurs des catégories), légende, puis Recommendations et la
// liste des catégories (taille à droite, ⓘ).
PaneBase {
    id: root

    readonly property var d: Machine.disk
    readonly property real other: Math.max(0, d.used - Math.max(0, d.home) - Math.max(0, d.nix))
    readonly property var cats: [
        { name: "Documents", color: "#FF9F0A", bytes: d.home, symbol: "doc" },
        { name: "NixOS", color: "#5E5CE6", bytes: d.nix, symbol: "nixos" },
        { name: "System Data", color: "#8E8E93", bytes: d.home >= 0 && d.nix >= 0 ? other : -1, symbol: "gearshape" }
    ]
    Component.onCompleted: { Machine.refresh(); Machine.measure(); }

    SGroup {
        Item {
            width: parent.width
            height: 104
            Text {
                x: SStyle.pad; y: 12
                text: Machine.diskName
                font.family: Theme.font; font.pixelSize: SStyle.body; font.weight: Font.DemiBold
                color: SStyle.label
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: SStyle.pad; y: 12
                text: Machine.size(root.d.used) + " of " + Machine.size(root.d.total) + " used"
                font.family: Theme.font; font.pixelSize: SStyle.body
                color: SStyle.secondary
            }
            Rectangle {
                id: bar
                x: SStyle.pad; y: 38
                width: parent.width - 2 * SStyle.pad
                height: 22
                radius: 5
                color: SStyle.sliderTrack
                clip: true
                Row {
                    height: parent.height
                    Repeater {
                        model: root.cats
                        Rectangle {
                            required property var modelData
                            height: bar.height
                            width: modelData.bytes > 0 && root.d.total > 0 ? Math.max(2, bar.width * modelData.bytes / root.d.total) : 0
                            color: modelData.color
                            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: SStyle.contentBg; opacity: 0.6 }
                        }
                    }
                    Rectangle {
                        height: bar.height
                        visible: root.d.home < 0 || root.d.nix < 0
                        width: root.d.total > 0 ? bar.width * root.d.used / root.d.total : 0
                        color: "#8E8E93"
                    }
                }
            }
            Row {
                x: SStyle.pad; y: 72
                spacing: 16
                Repeater {
                    model: root.cats
                    Row {
                        required property var modelData
                        spacing: 5
                        Rectangle { width: 8; height: 8; radius: 4; color: modelData.color; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.name; font.family: Theme.font; font.pixelSize: SStyle.small; color: SStyle.secondary }
                    }
                }
            }
        }
    }
    SSection { text: "Recommendations" }
    SGroup {
        SRow {
            title: "Optimize Storage"
            subtitle: "Remove old NixOS generations and unused store paths (nix-collect-garbage --delete-older-than 14d)."
            SButton { text: "Optimize…"; onClicked: Quickshell.execDetached(["kitty", "-e", "sh", "-c", "nix-collect-garbage --delete-older-than 14d; echo; echo 'Press Return to close.'; read _"]) }
        }
    }
    SGroup {
        Repeater {
            model: root.cats
            SRow {
                required property var modelData
                title: modelData.name
                symbol: modelData.symbol
                symbolColor: modelData.color
                detail: modelData.bytes >= 0 ? Machine.size(modelData.bytes) : "Calculating…"
            }
        }
    }
}
