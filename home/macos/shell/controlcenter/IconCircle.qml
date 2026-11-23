import QtQuick
import qs.common

// Pastille ronde d'un contrôle (Wi-Fi, Bluetooth, Concentration...) :
// allumée = disque blanc + glyphe coloré ; éteinte = disque translucide + glyphe blanc.
Item {
    id: c

    property int size: 35
    property bool on: false
    property string symbol
    property int glyphSize: Math.round(size * 0.62)
    property color onColor: CCStyle.circleOn
    property color onGlyph: CCStyle.blue
    property bool interactive: true
    readonly property alias hovered: ma.containsMouse
    signal clicked()

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: c.on ? c.onColor : (ma.containsMouse && c.interactive ? CCStyle.circleOffHover : CCStyle.circleOff)
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Symbol {
        anchors.centerIn: parent
        name: c.symbol
        size: c.glyphSize
        color: c.on ? c.onGlyph : CCStyle.text
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: c.interactive
        onClicked: c.clicked()
    }

    scale: ma.pressed ? 0.9 : 1
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.4; epsilon: 0.0005 } }
}
