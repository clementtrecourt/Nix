import QtQuick
import qs.common

// Pastille de filtre (catégories de la vue Applications, types de fichiers).
Item {
    id: root

    property string text
    property bool checked: false
    property bool focusRing: false

    signal clicked()

    implicitWidth: label.implicitWidth + 24
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
        font.pixelSize: 12
        font.weight: Font.Medium
        color: root.checked ? "white" : Theme.label
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
