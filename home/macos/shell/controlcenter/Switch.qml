import QtQuick
import qs.common

// Interrupteur Tahoe (en-têtes des modules dépliés) : piste capsule, bouton
// capsule blanc qui s'étire pendant la pression (Liquid Glass) puis glisse.
Item {
    id: sw

    property bool checked: false
    signal toggled(bool on)

    implicitWidth: 32
    implicitHeight: 18

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? CCStyle.blue : Qt.rgba(1, 1, 1, 0.22)
        Behavior on color { ColorAnimation { duration: 180 } }
    }

    Rectangle {
        id: knob
        readonly property real baseW: 20
        width: ma.pressed ? baseW + 4 : baseW
        height: parent.height - 2
        radius: height / 2
        y: 1
        x: sw.checked ? sw.width - width - 1 : 1
        color: "white"
        Behavior on x { SpringAnimation { spring: 5; damping: 0.42; epsilon: 0.05 } }
        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -4
        onClicked: sw.toggled(!sw.checked)
    }
}
