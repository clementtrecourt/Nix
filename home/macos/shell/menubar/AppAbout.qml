import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common
import qs.services

// Panneau « À propos de <App> » (orderFrontStandardAboutPanel) : petite fenêtre
// centrée avec le bouton de fermeture rouge, l'icône, le nom en gras, la
// description et l'identifiant de l'app. Échap ou clic à côté pour fermer.
Scope {
    id: root

    property string cls: ""
    property bool open: false

    readonly property var entry: Apps.entryFor(cls)

    function show(c) {
        cls = c;
        open = true;
    }

    PanelWindow {
        id: win
        visible: root.open
        color: "transparent"
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "macos-about-app"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Normal
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            onPressed: root.open = false
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape || ((event.modifiers & Qt.MetaModifier) && event.key === Qt.Key_W)) {
                    root.open = false;
                    event.accepted = true;
                }
            }
        }

        Glass {
            id: card
            width: 280
            height: col.implicitHeight + 64
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.28)
            radius: Theme.radiusWindow
            thick: true

            MouseArea { anchors.fill: parent }

            // Bouton de fermeture (feu rouge), seul actif dans ce panneau
            Row {
                x: 14
                y: 14
                spacing: 8
                Rectangle {
                    width: 12; height: 12; radius: 6
                    color: "#FF5F57"
                    border.width: 0.5
                    border.color: Qt.rgba(0, 0, 0, 0.18)
                    Text {
                        anchors.centerIn: parent
                        visible: closeArea.containsMouse
                        text: "×"
                        font.pixelSize: 11
                        font.bold: true
                        color: Qt.rgba(0.3, 0, 0, 0.75)
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.open = false
                    }
                }
                Repeater {
                    model: 2
                    Rectangle {
                        width: 12; height: 12; radius: 6
                        color: Theme.fill
                    }
                }
            }

            Column {
                id: col
                anchors.horizontalCenter: parent.horizontalCenter
                y: 40
                width: parent.width - 48
                spacing: 6

                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitSize: 72
                    source: root.cls ? Apps.icon(root.cls) : Quickshell.iconPath("system-file-manager", "folder")
                }
                Item { width: 1; height: 4 }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.cls ? Apps.name(root.cls) : "Finder"
                    font.family: Theme.font
                    renderType: Text.CurveRendering
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: Theme.label
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: text !== ""
                    text: root.entry?.genericName || root.entry?.comment || ""
                    wrapMode: Text.WordWrap
                    font.family: Theme.font
                    renderType: Text.CurveRendering
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.labelSecondary
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.entry?.id ?? root.cls
                    font.family: Theme.font
                    renderType: Text.CurveRendering
                    font.pixelSize: 10
                    color: Theme.labelTertiary
                    elide: Text.ElideMiddle
                }
            }
        }
    }
}
