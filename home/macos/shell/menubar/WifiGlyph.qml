import QtQuick
import QtQuick.Shapes

// Picto Wi-Fi façon SF Symbol "wifi" : éventail de 3 arcs + pointe, les arcs
// au-delà du niveau de signal sont estompés. `off` : Wi-Fi désactivé (barré).
Item {
    id: root

    property color color: "white"
    // 0 (aucun réseau) .. 3 (signal fort)
    property int level: 3
    property bool off: false

    implicitWidth: 17
    implicitHeight: 13

    readonly property real cx: width / 2
    readonly property real cy: height - 1.4
    readonly property real stroke: 1.85
    readonly property real dim: 0.28

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: root.off ? root.dim : 1

        // Pointe : petit secteur plein
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.level >= 1 || root.off ? 1 : root.dim)
            startX: root.cx; startY: root.cy + 0.4
            PathLine { x: root.cx - 2.45; y: root.cy - 2.05 }
            PathArc {
                x: root.cx + 2.45; y: root.cy - 2.05
                radiusX: 3.2; radiusY: 3.2
            }
            PathLine { x: root.cx; y: root.cy + 0.4 }
        }
        // Arcs (45° de part et d'autre de la verticale)
        ShapePath {
            strokeWidth: root.stroke
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.level >= 2 || root.off ? 1 : root.dim)
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: 6.2; radiusY: 6.2; startAngle: -136; sweepAngle: 92 }
        }
        ShapePath {
            strokeWidth: root.stroke
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.level >= 3 || root.off ? 1 : root.dim)
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: 10.2; radiusY: 10.2; startAngle: -136; sweepAngle: 92 }
        }
    }

    // Barre oblique (Wi-Fi coupé)
    Rectangle {
        visible: root.off
        anchors.centerIn: parent
        width: 1.7
        height: 17
        radius: 1
        rotation: -42
        color: root.color
        antialiasing: true
    }
}
