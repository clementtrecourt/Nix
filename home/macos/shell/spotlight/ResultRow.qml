import QtQuick
import qs.common

// Ligne de la liste de résultats : en-tête de section, ou résultat (icône,
// titre, détail à droite). La ligne sélectionnée prend la couleur d'accent.
Item {
    id: root

    required property var modelData
    required property int index
    property bool selected: false
    // ⌘ maintenu : affiche l'emplacement des fichiers (comme Tahoe)
    property bool cmdHeld: false

    signal clicked()
    signal doubleClicked()
    signal hovered()
    signal secondaryAction()   // bouton « copier » du presse-papiers

    readonly property bool isHeader: !!modelData.header
    readonly property bool isTop: !!modelData.top

    width: ListView.view ? ListView.view.width : 0
    height: isHeader ? Metrics.headerHeight : (isTop ? Metrics.topRowHeight : Metrics.rowHeight)

    // ---- En-tête de section ----
    Text {
        visible: root.isHeader
        anchors.left: parent.left
        anchors.leftMargin: Metrics.rowInset + 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        text: root.modelData.title ?? ""
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: Theme.labelSecondary
    }

    // ---- Résultat ----
    Rectangle {
        id: bg
        visible: !root.isHeader
        anchors.fill: parent
        anchors.leftMargin: Metrics.rowInset
        anchors.rightMargin: Metrics.rowInset
        radius: Metrics.rowRadius
        color: root.selected ? Theme.accent : (mouse.containsMouse ? Theme.fill : "transparent")
        Behavior on color { ColorAnimation { duration: 80 } }

        ItemIcon {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            size: root.isTop ? 36 : 26
            item: root.modelData
        }

        Column {
            anchors.left: icon.right
            anchors.leftMargin: 10
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
                font.pixelSize: root.isTop ? 16 : 14
                font.weight: root.isTop ? Font.Medium : Font.Normal
                color: root.selected ? "white" : Theme.label
            }
            // Emplacement du fichier : sous le titre quand ⌘ est maintenu
            Text {
                width: parent.width
                visible: root.modelData.kind === "file" && (root.cmdHeld && root.selected || root.isTop)
                text: root.modelData.location ?? ""
                elide: Text.ElideMiddle
                font.family: Theme.font
                font.pixelSize: 11
                color: root.selected ? Qt.rgba(1, 1, 1, 0.75) : Theme.labelSecondary
            }
            Text {
                width: parent.width
                visible: root.isTop && root.modelData.kind !== "file"
                text: root.modelData.subtitle ?? ""
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 12
                color: root.selected ? Qt.rgba(1, 1, 1, 0.75) : Theme.labelSecondary
            }
        }

        // Détail à droite : type / dossier, ou bouton copier (presse-papiers)
        Row {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.isTop && root.modelData.kind !== "clip"
                text: root.modelData.subtitle ?? ""
                font.family: Theme.font
                font.pixelSize: 12
                color: root.selected ? Qt.rgba(1, 1, 1, 0.75) : Theme.labelSecondary
                width: Math.min(implicitWidth, 220)
                elide: Text.ElideRight
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.modelData.kind === "clip"
                text: root.modelData.subtitle ?? ""
                font.family: Theme.font
                font.pixelSize: 11
                color: root.selected ? Qt.rgba(1, 1, 1, 0.7) : Theme.labelTertiary
            }
            // Bouton copier (presse-papiers) visible au survol / à la sélection
            Item {
                visible: root.modelData.kind === "clip" && (root.selected || mouse.containsMouse)
                width: 22; height: 22
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: copyMouse.containsMouse ? (root.selected ? Qt.rgba(1, 1, 1, 0.2) : Theme.fillHover) : "transparent"
                }
                Symbol {
                    anchors.centerIn: parent
                    name: "doc.on.doc"
                    size: 14
                    color: root.selected ? "white" : Theme.labelSecondary
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
