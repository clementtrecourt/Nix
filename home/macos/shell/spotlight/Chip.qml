import QtQuick
import qs.common

// Pastille de filtre sous le champ (Tahoe) : groupes de résultats, catégories
// de la vue Applications, types de fichiers. Capsule discrète (voile blanc
// léger) au texte secondaire, 24 pt de haut, texte ≈ 16 px (captures Cult of
// Mac « Spotlight-Applications » en clair, MacRumors « spotlight-categories »
// en sombre) ; choisie, elle prend la couleur d'accent.
Item {
    id: root

    property string text
    property bool checked: false
    property bool focusRing: false

    signal clicked()

    implicitWidth: label.implicitWidth + 18
    implicitHeight: Metrics.chipHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent
             : Theme.dark ? Qt.rgba(1, 1, 1, mouse.containsMouse ? 0.14 : 0.08)
                          : Qt.rgba(1, 1, 1, mouse.containsMouse ? 0.55 : 0.36)
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
        color: root.checked ? "white"
             : mouse.containsMouse ? Theme.label
             : Theme.dark ? Qt.rgba(1, 1, 1, 0.62) : Qt.rgba(0.24, 0.24, 0.26, 0.55)
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
