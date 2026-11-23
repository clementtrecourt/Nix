import QtQuick

// Curseur Tahoe du Control Center : piste fine arrondie, remplissage blanc,
// sans bouton. Option `showTicks` : points de graduation (16 crans) sous la
// piste, comme sur le HUD volume de Tahoe.
Item {
    id: s

    property real value: 0                 // 0..1
    property bool showTicks: false
    property int steps: 16
    property bool interactive: true
    readonly property bool dragging: ma.pressed
    signal moved(real v)

    implicitHeight: 22

    function valueAt(x) { return Math.max(0, Math.min(1, x / width)); }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: s.showTicks ? -3 : 0
        width: parent.width
        height: CCStyle.trackHeight
        radius: height / 2
        color: CCStyle.trackEmpty
    }

    Rectangle {
        anchors.left: track.left
        anchors.verticalCenter: track.verticalCenter
        height: track.height
        radius: height / 2
        width: Math.max(s.value > 0 ? height : 0, track.width * Math.max(0, Math.min(1, s.value)))
        color: CCStyle.trackFill
        Behavior on width {
            enabled: !ma.pressed
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    // Graduations (HUD)
    Repeater {
        model: s.showTicks ? s.steps + 1 : 0
        Rectangle {
            required property int index
            width: 2
            height: 2
            radius: 1
            color: CCStyle.tick
            x: 3 + index * (s.width - 8) / s.steps
            y: track.y + track.height + 4
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        enabled: s.interactive
        preventStealing: true
        onPressed: mouse => s.moved(s.valueAt(mouse.x))
        onPositionChanged: mouse => { if (pressed) s.moved(s.valueAt(mouse.x)); }
        onWheel: wheel => s.moved(Math.max(0, Math.min(1, s.value + (wheel.angleDelta.y > 0 ? 1 : -1) / s.steps)))
    }
}
