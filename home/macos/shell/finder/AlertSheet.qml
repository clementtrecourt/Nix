import QtQuick
import qs.common

// Alerte du Finder (nom déjà pris, dossier introuvable…) : feuille centrée
// façon Tahoe, grande plaque arrondie, icône du Finder, texte en gras,
// bouton « OK » d'accent en capsule.
Item {
    id: root

    required property var fw
    anchors.fill: parent
    visible: fw.alertText !== ""

    function dismiss() { fw.alertText = ""; fw.alertInfo = ""; fw.alertButtons = []; fw.focusStage(); }
    function press(b) { const a = b.action; dismiss(); if (a) a(); }
    // Boutons (Tahoe : capsules pleine largeur, l'action principale en accent)
    readonly property var buttons: fw.alertButtons.length ? fw.alertButtons : [{ text: "OK", primary: true }]
    onVisibleChanged: if (visible) ok.forceActiveFocus()

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.10) }
    MouseArea { anchors.fill: parent }

    Item {
        width: 260
        height: col.implicitHeight + 32
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(60, (parent.height - height) * 0.38)

        Glass {
            anchors.fill: parent
            radius: 26
            tint: Theme.dark ? Qt.rgba(0.17, 0.17, 0.18, 0.98) : Qt.rgba(0.97, 0.97, 0.975, 0.98)
            shadowBlur: 1.2
            shadowOffset: 14
            shadowMax: 1.0
            shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.55 : 0.28)
            glowWidth: 0
        }
        Column {
            id: col
            x: 16
            y: 18
            width: parent.width - 32
            spacing: 10
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64
                height: 64
                source: Fs.themeIcon("system-file-manager", "folder")
                sourceSize: Qt.size(128, 128)
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.fw.alertText
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.Bold
                color: Theme.label
            }
            Text {
                visible: root.fw.alertInfo !== ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.fw.alertInfo
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.label
            }
            Item { width: 1; height: 4 }
            Item {
                id: ok
                width: parent.width
                height: btns.implicitHeight
                focus: true
                Keys.onReturnPressed: root.press(root.buttons.find(b => b.primary) ?? root.buttons[0])
                Keys.onEscapePressed: root.press(root.buttons.find(b => b.cancel) ?? root.buttons[root.buttons.length - 1])
                Column {
                    id: btns
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: root.buttons
                        Rectangle {
                            required property var modelData
                            width: btns.width
                            height: 28
                            radius: 14
                            color: modelData.primary ? (modelData.destructive ? Theme.red : Theme.accent)
                                   : (Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.07))
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.text
                                font.family: Theme.font
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: parent.modelData.primary ? "white" : Theme.label
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.press(parent.modelData) }
                        }
                    }
                }
            }
        }
    }
}
