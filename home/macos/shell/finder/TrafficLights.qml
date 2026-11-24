import QtQuick
import QtQuick.Shapes
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
    // Couleurs canoniques de Tahoe (common/Theme : mêmes feux que toutes les fenêtres)
    readonly property color off: Theme.trafficInactive
    readonly property color offStroke: Theme.trafficInactiveRing

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
        border.width: Theme.trafficRingWidth
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
        fill: Theme.trafficRed
        stroke: Theme.trafficRedRing
        onClicked: root.closeClicked()
        // × fin et net en 1x : deux traits de 1,2 px tournés (lissés par Qt)
        Repeater {
            model: [45, -45]
            Rectangle {
                required property real modelData
                anchors.centerIn: parent
                width: root.size * 0.5
                height: 1.25
                radius: 0.6
                rotation: modelData
                antialiasing: true
                color: Qt.rgba(0.30, 0, 0, 0.88)
            }
        }
    }
    Light {
        id: minBtn
        fill: Theme.trafficYellow
        stroke: Theme.trafficYellowRing
        onClicked: root.minimizeClicked()
        Rectangle {
            // Sur une rangée de pixels entière (net en 1x)
            x: Math.round((parent.width - width) / 2)
            y: Math.floor(parent.height / 2) - 1
            width: Math.round(parent.width * 0.52)
            height: 1.2
            radius: 0.7
            color: Qt.rgba(0.6, 0.34, 0, 0.9)
        }
    }
    Light {
        id: zoomBtn
        fill: Theme.trafficGreen
        stroke: Theme.trafficGreenRing
        onClicked: root.zoomClicked()
        // Flèches du plein écran : deux petits triangles opposés (tracé
        // vectoriel lissé, net en 1x)
        Shape {
            id: zs
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property real k: root.size / 14
            ShapePath {
                strokeWidth: -1
                fillColor: Qt.rgba(0, 0.30, 0, 0.88)
                startX: 4.3 * zs.k; startY: 4.3 * zs.k
                PathLine { x: 8.1 * zs.k; y: 4.3 * zs.k }
                PathLine { x: 4.3 * zs.k; y: 8.1 * zs.k }
                PathLine { x: 4.3 * zs.k; y: 4.3 * zs.k }
            }
            ShapePath {
                strokeWidth: -1
                fillColor: Qt.rgba(0, 0.30, 0, 0.88)
                startX: 9.7 * zs.k; startY: 9.7 * zs.k
                PathLine { x: 5.9 * zs.k; y: 9.7 * zs.k }
                PathLine { x: 9.7 * zs.k; y: 5.9 * zs.k }
                PathLine { x: 9.7 * zs.k; y: 9.7 * zs.k }
            }
        }
    }
}
