import QtQuick
import QtQuick.Shapes

// Picto du Centre de contrôle (SF Symbol "switch.2"), d'après la barre de
// Tahoe (image Apple Newsroom, macOS 26 Control Center) : deux capsules
// empilées d'environ 12,6 x 5,6 pt, séparées de 1,6 pt.
//   - en haut : interrupteur « éteint », capsule au trait, pastille pleine à GAUCHE ;
//   - en bas : interrupteur « allumé », capsule pleine, pastille évidée à DROITE
//     (on voit le fond à travers).
// Tracé vectoriel : le SVG générique assets/symbols/switch.2.svg, réduit à
// 16 px, s'empâte et devient illisible à 1x.
Item {
    id: root

    property color color: "white"

    implicitWidth: 13
    implicitHeight: 13

    readonly property real capW: 12.6
    readonly property real capH: 5.6
    readonly property real gap: 1.6
    readonly property real sw: 1.25                 // trait de la capsule du haut
    readonly property real x0: (width - capW) / 2
    readonly property real y0: (height - 2 * capH - gap) / 2
    readonly property real y1: y0 + capH + gap
    readonly property real rr: capH / 2
    readonly property real knobR: 1.55             // pastille pleine (haut)
    // Pastille évidée (bas) : légèrement ovale sur la référence Apple
    readonly property real holeRx: 2.05
    readonly property real holeRy: 1.7
    readonly property real holeCx: x0 + capW - rr - 0.3

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Capsule du haut, au trait (tracée à mi-épaisseur à l'intérieur)
        ShapePath {
            strokeWidth: root.sw
            strokeColor: root.color
            fillColor: "transparent"
            startX: root.x0 + root.rr; startY: root.y0 + root.sw / 2
            PathLine { x: root.x0 + root.capW - root.rr; y: root.y0 + root.sw / 2 }
            PathArc { x: root.x0 + root.capW - root.rr; y: root.y0 + root.capH - root.sw / 2; radiusX: root.rr - root.sw / 2; radiusY: root.rr - root.sw / 2 }
            PathLine { x: root.x0 + root.rr; y: root.y0 + root.capH - root.sw / 2 }
            PathArc { x: root.x0 + root.rr; y: root.y0 + root.sw / 2; radiusX: root.rr - root.sw / 2; radiusY: root.rr - root.sw / 2 }
        }

        // Pastille pleine à gauche (haut)
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color
            startX: root.x0 + root.rr + 0.2 - root.knobR; startY: root.y0 + root.rr
            PathArc { x: root.x0 + root.rr + 0.2 + root.knobR; y: root.y0 + root.rr; radiusX: root.knobR; radiusY: root.knobR }
            PathArc { x: root.x0 + root.rr + 0.2 - root.knobR; y: root.y0 + root.rr; radiusX: root.knobR; radiusY: root.knobR }
        }

        // Capsule du bas, pleine, percée d'un trou rond à droite (règle pair-impair)
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color
            fillRule: ShapePath.OddEvenFill
            startX: root.x0 + root.rr; startY: root.y1
            PathLine { x: root.x0 + root.capW - root.rr; y: root.y1 }
            PathArc { x: root.x0 + root.capW - root.rr; y: root.y1 + root.capH; radiusX: root.rr; radiusY: root.rr }
            PathLine { x: root.x0 + root.rr; y: root.y1 + root.capH }
            PathArc { x: root.x0 + root.rr; y: root.y1; radiusX: root.rr; radiusY: root.rr }
            // Trou
            PathMove { x: root.holeCx - root.holeRx; y: root.y1 + root.rr }
            PathArc { x: root.holeCx + root.holeRx; y: root.y1 + root.rr; radiusX: root.holeRx; radiusY: root.holeRy }
            PathArc { x: root.holeCx - root.holeRx; y: root.y1 + root.rr; radiusX: root.holeRx; radiusY: root.holeRy }
        }
    }
}
