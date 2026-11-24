import QtQuick
import qs.common

// Feux tricolores de Tahoe (fermer / réduire / plein écran) : pastilles de
// 14 pt au pas de 23 pt (capture 2x de Daring Fireball), glyphes visibles au
// survol du groupe, gris quand la fenêtre n'est pas au premier plan.
Row {
    id: root

    property bool active: true
    property int size: FStyle.lightSize
    signal closeClicked()
    signal minimizeClicked()
    signal zoomClicked()

    spacing: FStyle.lightGap

    readonly property bool groupHovered: closeBtn.hovered || minBtn.hovered || zoomBtn.hovered
    readonly property color off: Theme.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.13)
    readonly property color offStroke: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)

    component Light: Rectangle {
        id: light
        property color fill
        property color stroke
        property alias hovered: ma.containsMouse
        default property alias glyph: glyphItem.data
        signal clicked()
        width: root.size
        height: root.size
        radius: root.size / 2
        readonly property bool lit: root.active || root.groupHovered
        color: lit ? fill : root.off
        border.width: 0.5
        border.color: lit ? stroke : root.offStroke
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "black"
            opacity: ma.pressed ? 0.22 : 0
        }
        Item {
            id: glyphItem
            anchors.fill: parent
            visible: root.groupHovered
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: light.clicked()
        }
    }

    Light {
        id: closeBtn
        fill: "#FF5F57"
        stroke: "#E2463F"
        onClicked: root.closeClicked()
        Canvas {
            anchors.fill: parent
            onPaint: {
                const c = getContext("2d");
                const s = width;
                c.reset();
                c.strokeStyle = "rgba(77,0,0,0.85)";
                c.lineWidth = 1.3;
                c.lineCap = "round";
                c.beginPath();
                c.moveTo(s * 0.32, s * 0.32); c.lineTo(s * 0.68, s * 0.68);
                c.moveTo(s * 0.68, s * 0.32); c.lineTo(s * 0.32, s * 0.68);
                c.stroke();
            }
        }
    }
    Light {
        id: minBtn
        fill: "#FEBC2E"
        stroke: "#E1A116"
        onClicked: root.minimizeClicked()
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.52
            height: 1.4
            radius: 0.7
            color: Qt.rgba(0.6, 0.34, 0, 0.9)
        }
    }
    Light {
        id: zoomBtn
        fill: "#28C840"
        stroke: "#14AE2B"
        onClicked: root.zoomClicked()
        Canvas {
            anchors.fill: parent
            onPaint: {
                const c = getContext("2d");
                const s = width;
                c.reset();
                c.fillStyle = "rgba(0,80,0,0.85)";
                c.beginPath(); c.moveTo(s * 0.29, s * 0.29); c.lineTo(s * 0.62, s * 0.29); c.lineTo(s * 0.29, s * 0.62); c.closePath(); c.fill();
                c.beginPath(); c.moveTo(s * 0.71, s * 0.71); c.lineTo(s * 0.38, s * 0.71); c.lineTo(s * 0.71, s * 0.38); c.closePath(); c.fill();
            }
        }
    }
}
