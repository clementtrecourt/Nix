import QtQuick
import qs.common

// Ligne de résultat de Spotlight (Tahoe) : icône 32 pt, titre et détail sur
// deux lignes, information à droite (raccourci, date) ou bouton « copier »
// rond (presse-papiers). La ligne sélectionnée prend la couleur d'accent,
// dans une capsule arrondie en retrait des bords du panneau.
Item {
    id: root

    required property var modelData
    required property int index
    property bool selected: false
    // ⌘ maintenu : affiche le chemin complet des fichiers (comme Tahoe)
    property bool cmdHeld: false

    signal clicked()
    signal doubleClicked()
    signal secondaryAction()   // bouton « copier » du presse-papiers

    readonly property bool isClip: modelData.kind === "clip"
    readonly property string detail: {
        if (modelData.kind === "file" && cmdHeld && selected) return modelData.location ?? "";
        return modelData.subtitle ?? "";
    }

    width: ListView.view ? ListView.view.width : 0
    height: Metrics.rowHeight

    Rectangle {
        id: bg
        anchors.fill: parent
        anchors.leftMargin: Metrics.rowInset
        anchors.rightMargin: Metrics.rowInset
        radius: Metrics.rowRadius
        color: root.selected ? Theme.accent : (mouse.containsMouse ? Theme.fill : "transparent")
        Behavior on color { ColorAnimation { duration: 80 } }

        // Icône : à 19 pt du bord du panneau
        ItemIcon {
            id: icon
            x: 19 - Metrics.rowInset
            anchors.verticalCenter: parent.verticalCenter
            size: Metrics.rowIcon
            item: root.modelData
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 70 - Metrics.rowInset
            anchors.right: trailing.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: root.modelData.title ?? ""
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
                font.family: Theme.font
                font.pixelSize: Metrics.titleSize
                color: root.selected ? "white" : Theme.label
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: root.detail
                elide: root.modelData.kind === "file" ? Text.ElideMiddle : Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
                font.family: Theme.font
                font.pixelSize: Metrics.detailSize
                color: root.selected ? Qt.rgba(1, 1, 1, 0.72) : Theme.labelSecondary
            }
        }

        // À droite : information courte, ou bouton copier (presse-papiers)
        Item {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            width: root.isClip ? 26 : trailText.implicitWidth
            height: 26

            Text {
                id: trailText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.isClip && text.length > 0
                text: root.modelData.trailing ?? ""
                font.family: Theme.font
                font.pixelSize: 12
                color: root.selected ? Qt.rgba(1, 1, 1, 0.72) : Theme.labelSecondary
            }

            // Bouton copier rond (Tahoe : toujours visible sur chaque élément)
            Rectangle {
                anchors.fill: parent
                visible: root.isClip
                radius: width / 2
                color: root.selected ? Qt.rgba(1, 1, 1, copyMouse.containsMouse ? 0.32 : 0.2)
                                     : (copyMouse.containsMouse ? Theme.fillHover : Theme.fill)
                Symbol {
                    anchors.centerIn: parent
                    name: "doc.on.doc"
                    size: 14
                    // (couleur opaque : Symbol recolore mal l'alpha)
                    color: root.selected ? "white" : (Theme.dark ? "#a8a8ad" : "#6e6e73")
                }
                MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.secondaryAction()
                }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            z: -1
            onClicked: root.clicked()
            onDoubleClicked: root.doubleClicked()
        }
    }
}
