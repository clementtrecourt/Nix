import QtQuick
import qs.common

// Interrupteur de Tahoe (formulaires) : piste de 36 × 16 pt, bouton en
// pilule blanche de 21 × 13 pt (inset 1,5 pt), accent quand il est activé.
// Mesures : capture 2x MacStories (Spotlight, « Show Related Content »).
Item {
    id: root

    property bool checked: false
    property bool enabledSwitch: true
    signal toggled(bool on)

    implicitWidth: 36
    implicitHeight: 16
    width: implicitWidth
    height: implicitHeight
    opacity: enabledSwitch ? 1 : 0.45

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? SStyle.accent : SStyle.switchOff
        Behavior on color { ColorAnimation { duration: 160 } }
    }
    Rectangle {
        id: knob
        width: ma.pressed ? 24 : 21
        height: 13
        radius: height / 2
        y: 1.5
        x: root.checked ? parent.width - width - 1.5 : 1.5
        color: "#FFFFFF"
        border.width: 0.5
        border.color: Qt.rgba(0, 0, 0, root.checked ? 0 : 0.06)
        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 120 } }
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 1
            anchors.bottomMargin: -1
            z: -1
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.12)
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -4
        enabled: root.enabledSwitch
        onClicked: { root.checked = !root.checked; root.toggled(root.checked); }
    }
}
