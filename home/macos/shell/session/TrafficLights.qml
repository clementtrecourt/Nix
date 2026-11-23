import QtQuick
import qs.common

// Boutons de fenêtre macOS (fermer / réduire / plein écran), 12 px, espacés de
// 8 px. Les glyphes (×, −, flèches) n'apparaissent qu'au survol du groupe,
// comme dans AppKit. Un bouton désactivé est gris.
Row {
    id: root

    property bool closeEnabled: true
    property bool minimizeEnabled: false
    property bool zoomEnabled: false
    // Fenêtre au premier plan : sinon les trois pastilles sont grises
    property bool active: true

    signal closeClicked()
    signal minimizeClicked()
    signal zoomClicked()

    spacing: 8

    readonly property bool groupHovered: h1.containsMouse || h2.containsMouse || h3.containsMouse
    readonly property color off: Theme.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
    readonly property color offStroke: Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)

    component Light: Rectangle {
        id: light
        property color fill
        property color stroke
        property bool enabledButton: true
        property alias hovered: ma.containsMouse
        property alias mouse: ma
        default property alias glyph: glyphItem.data
        signal clicked()
        width: 12
        height: 12
        radius: 6
        color: enabledButton && root.active ? fill : root.off
        border.width: 0.5
        border.color: enabledButton && root.active ? stroke : root.offStroke
        // Assombri à l'appui
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "black"
            opacity: ma.pressed && light.enabledButton ? 0.25 : 0
        }
        Item {
            id: glyphItem
            anchors.fill: parent
            visible: root.groupHovered && light.enabledButton
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            enabled: light.enabledButton
            onClicked: light.clicked()
        }
    }

    Light {
        id: closeBtn
        fill: "#FF5F57"
        stroke: "#E2463F"
        enabledButton: root.closeEnabled
        onClicked: root.closeClicked()
        Canvas {
            anchors.fill: parent
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.strokeStyle = "rgba(77,0,0,0.85)";
                c.lineWidth = 1.2;
                c.lineCap = "round";
                c.beginPath();
                c.moveTo(3.6, 3.6); c.lineTo(8.4, 8.4);
                c.moveTo(8.4, 3.6); c.lineTo(3.6, 8.4);
                c.stroke();
            }
        }
    }
    Light {
        id: minBtn
        fill: "#FEBC2E"
        stroke: "#E1A116"
        enabledButton: root.minimizeEnabled
        onClicked: root.minimizeClicked()
        Rectangle {
            anchors.centerIn: parent
            width: 6.4
            height: 1.3
            radius: 0.6
            color: Qt.rgba(0.6, 0.34, 0, 0.9)
        }
    }
    Light {
        id: zoomBtn
        fill: "#28C840"
        stroke: "#14AE2B"
        enabledButton: root.zoomEnabled
        onClicked: root.zoomClicked()
        Canvas {
            anchors.fill: parent
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.fillStyle = "rgba(0,80,0,0.85)";
                // deux triangles opposés (plein écran)
                c.beginPath(); c.moveTo(3.4, 3.4); c.lineTo(7.4, 3.4); c.lineTo(3.4, 7.4); c.closePath(); c.fill();
                c.beginPath(); c.moveTo(8.6, 8.6); c.lineTo(4.6, 8.6); c.lineTo(8.6, 4.6); c.closePath(); c.fill();
            }
        }
    }

    // Survol du groupe (alias vers les MouseArea des pastilles)
    readonly property var h1: closeBtn.mouse
    readonly property var h2: minBtn.mouse
    readonly property var h3: zoomBtn.mouse
}
