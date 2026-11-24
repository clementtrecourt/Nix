import QtQuick
import qs.common

// Bouton radio de Tahoe : disque de 14 pt, point blanc sur accent.
Item {
    id: root

    property bool checked: false
    property string text
    signal clicked()

    implicitWidth: dot.width + label.implicitWidth + 7
    implicitHeight: 18

    Rectangle {
        id: dot
        width: 14
        height: 14
        radius: 7
        anchors.verticalCenter: parent.verticalCenter
        color: root.checked ? SStyle.accent : (Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : "#FFFFFF")
        border.width: root.checked ? 0 : 0.5
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.22)
        Rectangle {
            anchors.centerIn: parent
            visible: root.checked
            width: 5
            height: 5
            radius: 2.5
            color: "#FFFFFF"
        }
    }
    Text {
        id: label
        x: dot.width + 7
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        font.family: Theme.font
        font.pixelSize: SStyle.body
        color: SStyle.label
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
