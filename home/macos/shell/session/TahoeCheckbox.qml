import QtQuick
import qs.common

// Case à cocher macOS : carré 14 px aux coins de 4 px, accent + coche blanche
// quand cochée, libellé à droite (11 px dans une alerte).
Item {
    id: root

    property string text
    property bool checked: false
    property int fontSize: 11

    implicitWidth: box.width + 7 + label.implicitWidth
    implicitHeight: Math.max(box.height, label.implicitHeight)

    Rectangle {
        id: box
        width: 14
        height: 14
        radius: 4
        anchors.top: parent.top
        anchors.topMargin: Math.max(0, (label.implicitHeight - height) / 2)
        color: root.checked ? Theme.accent : (Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : "white")
        border.width: root.checked ? 0 : 0.5
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.25)
        Behavior on color { ColorAnimation { duration: 90 } }

        Symbol {
            anchors.centerIn: parent
            name: "checkmark"
            size: 10
            color: "white"
            visible: root.checked
        }
    }

    Text {
        id: label
        x: box.width + 7
        width: root.width - x
        text: root.text
        wrapMode: Text.Wrap
        font.family: Theme.font
        font.pixelSize: root.fontSize
        color: Theme.label
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.checked = !root.checked
    }
}
