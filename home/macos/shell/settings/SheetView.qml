import QtQuick
import qs.common

// Rendu d'une SSheet dans la couche overlay de la fenêtre : voile sur la
// fenêtre, plaque arrondie de 22 pt centrée sous la barre de titre, contenu
// en formulaire, boutons en bas à droite.
Item {
    id: root

    required property var sheet

    anchors.fill: parent
    z: 100
    visible: opacity > 0
    enabled: sheet.shown
    opacity: sheet.shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Rectangle {
        anchors.fill: parent
        radius: SStyle.windowRadius
        color: Qt.rgba(0, 0, 0, Theme.dark ? 0.35 : 0.18)
        MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: (w) => w.accepted = true }
    }
    Rectangle {
        id: plate
        width: root.sheet.sheetWidth
        height: Math.min(root.height - 60, (body.item ? body.item.implicitHeight : 0) + 20 + 52)
        x: Math.round((root.width - width) / 2)
        y: 40
        radius: 22
        color: Theme.dark ? "#2C2C2E" : "#FFFFFF"
        border.width: 0.5
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            z: -1
            radius: parent.radius + 1
            color: Qt.rgba(0, 0, 0, Theme.dark ? 0.4 : 0.12)
        }
        Flickable {
            x: 20
            y: 20
            width: parent.width - 40
            height: parent.height - 72
            contentHeight: body.item ? body.item.implicitHeight : 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Loader {
                id: body
                width: parent.width
                active: root.sheet.shown || root.visible
                sourceComponent: root.sheet.body
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            spacing: 10
            SButton {
                visible: root.sheet.cancelText !== ""
                text: root.sheet.cancelText
                minWidth: 70
                onClicked: { root.sheet.shown = false; root.sheet.cancelled(); }
            }
            SButton {
                text: root.sheet.doneText
                prominent: true
                minWidth: 70
                enabledButton: root.sheet.doneEnabled
                onClicked: { root.sheet.shown = false; root.sheet.done(); }
            }
        }
    }
    Keys.onEscapePressed: { sheet.shown = false; sheet.cancelled(); }
}
