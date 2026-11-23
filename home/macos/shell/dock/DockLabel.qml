import QtQuick
import QtQuick.Shapes
import qs.common

// Bulle du nom d'app au survol (Tahoe) : rectangle arrondi en verre sombre/clair,
// liseré fin, petite pointe vers l'icône. Positionnée par le Dock : (tipX, tipY)
// est la pointe.
Item {
    id: root

    property string text
    property real tipX: 0
    property real tipY: 0
    property bool shown: false

    readonly property int bodyH: 24
    readonly property int tailW: 14
    readonly property int tailH: 6
    readonly property int r: 7

    width: Math.ceil(label.implicitWidth) + 22
    height: bodyH + tailH
    x: Math.round(tipX - width / 2)
    y: Math.round(tipY - height)

    opacity: shown && text !== "" ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: root.shown ? 60 : 90 } }

    readonly property color fill: Theme.dark ? Qt.rgba(0.17, 0.17, 0.18, 0.80) : Qt.rgba(0.96, 0.96, 0.97, 0.84)
    readonly property color stroke: Theme.dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.10)

    Shape {
        id: shape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Ombre très douce
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: root.fill
            strokeColor: root.stroke
            strokeWidth: 1
            joinStyle: ShapePath.RoundJoin
            startX: root.r + 0.5; startY: 0.5
            PathLine { x: shape.width - root.r - 0.5; y: 0.5 }
            PathArc { x: shape.width - 0.5; y: root.r + 0.5; radiusX: root.r; radiusY: root.r }
            PathLine { x: shape.width - 0.5; y: root.bodyH - root.r }
            PathArc { x: shape.width - root.r - 0.5; y: root.bodyH; radiusX: root.r; radiusY: root.r }
            // Pointe : flancs légèrement incurvés, sommet arrondi
            PathLine { x: shape.width / 2 + root.tailW / 2; y: root.bodyH }
            PathQuad { x: shape.width / 2 + 1.2; y: root.bodyH + root.tailH - 0.8; controlX: shape.width / 2 + 2.5; controlY: root.bodyH + 1 }
            PathQuad { x: shape.width / 2 - 1.2; y: root.bodyH + root.tailH - 0.8; controlX: shape.width / 2; controlY: root.bodyH + root.tailH + 0.6 }
            PathQuad { x: shape.width / 2 - root.tailW / 2; y: root.bodyH; controlX: shape.width / 2 - 2.5; controlY: root.bodyH + 1 }
            PathLine { x: root.r + 0.5; y: root.bodyH }
            PathArc { x: 0.5; y: root.bodyH - root.r; radiusX: root.r; radiusY: root.r }
            PathLine { x: 0.5; y: root.r + 0.5 }
            PathArc { x: root.r + 0.5; y: 0.5; radiusX: root.r; radiusY: root.r }
        }
    }

    Text {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        y: (root.bodyH - height) / 2
        text: root.text
        color: Theme.label
        font.family: Theme.font
        font.pixelSize: 14
        renderType: Text.NativeRendering
    }
}
