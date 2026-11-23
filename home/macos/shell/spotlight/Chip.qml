import QtQuick
import qs.common

// Pastille de filtre sous le champ (Tahoe) : groupes de résultats, catégories
// de la vue Applications, types de fichiers. Capsule grise discrète au texte
// secondaire ; choisie, elle prend la couleur d'accent.
Item {
    id: root

    property string text
    property bool checked: false
    property bool focusRing: false

    signal clicked()

    implicitWidth: label.implicitWidth + 22
    implicitHeight: Metrics.chipHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : (mouse.containsMouse ? Theme.fillHover : Theme.fill)
        border.width: root.focusRing ? 2 : 0
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.font
        font.pixelSize: Metrics.chipFontSize
        color: root.checked ? "white" : (mouse.containsMouse ? Theme.label : Theme.labelSecondary)
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
