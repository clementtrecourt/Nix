import QtQuick
import QtQuick.Effects

// Nuage « pouf » de macOS quand on retire une icône du Dock : quelques volutes
// blanches qui gonflent et se dissipent (≈ 0,35 s).
Item {
    id: root

    readonly property bool running: anim.running
    property real progress: 0
    width: 64
    height: 64
    visible: running

    function at(x, y) {
        root.x = x - width / 2;
        root.y = y - height / 2;
        anim.restart();
    }

    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: 360
        easing.type: Easing.OutQuad
    }

    Item {
        id: puffs
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Repeater {
            model: 7
            Rectangle {
                required property int index
                readonly property real a: index / 7 * Math.PI * 2 + 0.4
                readonly property real d: index === 6 ? 0 : 14 * root.progress + 4
                readonly property real s: (index === 6 ? 30 : 20) * (0.55 + 0.6 * root.progress)
                width: s
                height: s
                radius: s / 2
                x: root.width / 2 + Math.cos(a) * d - s / 2
                y: root.height / 2 + Math.sin(a) * d - s / 2
                color: "#f4f4f6"
            }
        }
    }
    MultiEffect {
        anchors.fill: puffs
        source: puffs
        blurEnabled: true
        blur: 0.35
        blurMax: 16
        opacity: 1 - root.progress * root.progress
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.25)
        shadowBlur: 0.6
        shadowVerticalOffset: 2
    }
}
