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
        anchors.verticalCenterOffset: s.showTicks ? -3 : 0   // HUD : piste au centre de la ligne, crans dessous
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
            // 17 points de 2 pt, de 4 à width - 4, centrés 6 pt sous la piste
            x: 3 + index * (s.width - 8) / s.steps
            y: track.y + track.height / 2 + 5
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
        // Molette : un cran (120) = un pas de 1/16 ; un pavé tactile envoie de
        // petits deltas, appliqués proportionnellement (pas un pas par événement).
        onWheel: wheel => {
            const d = (wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x) / 120 / s.steps;
            if (d !== 0) s.moved(Math.max(0, Math.min(1, s.value + d)));
        }
    }
}
