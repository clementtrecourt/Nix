import QtQuick
import qs.common

// Case à cocher de Tahoe : 14 pt, coins de 4 pt, accent + coche blanche.
Item {
    id: root

    property bool checked: false
    property string text
    property bool enabledBox: true
    signal toggled(bool on)

    implicitWidth: box.width + (text ? label.implicitWidth + 7 : 0)
    implicitHeight: 16
    opacity: enabledBox ? 1 : 0.45

    Rectangle {
        id: box
        width: 14
        height: 14
        anchors.verticalCenter: parent.verticalCenter
        radius: 4
        color: root.checked ? SStyle.accent : (Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : "#FFFFFF")
        border.width: root.checked ? 0 : 0.5
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.22)
        Symbol {
            anchors.centerIn: parent
            visible: root.checked
            name: "checkmark"
            size: 10
            color: "#FFFFFF"
        }
    }
    Text {
        id: label
        visible: root.text !== ""
        x: box.width + 7
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        font.family: Theme.font
        font.pixelSize: SStyle.body
        color: SStyle.label
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -3
        enabled: root.enabledBox
        onClicked: { root.checked = !root.checked; root.toggled(root.checked); }
    }
}
