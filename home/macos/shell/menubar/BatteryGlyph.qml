import QtQuick
import QtQuick.Shapes

// Picto batterie façon SF Symbol "battery.100" : contour estompé, remplissage
// plein proportionnel à la charge, borne à droite. En charge : éclair évidé
// au centre. Rouge sous 10 %, jaune en mode économie d'énergie.
Item {
    id: root

    property color color: "white"
    property real level: 1.0          // 0..1
    property bool charging: false
    property bool pluggedFull: false  // secteur, batterie pleine
    property bool lowPower: false

    // Géométrie ENTIÈRE (écran 1x) : corps 23 x 12 px, contour d'1 px bien
    // visible (Tahoe : contour net à ~60 %, About-This-Mac.png de 512pixels et
    // ars-tahoe-light.jpg), borne de 2 x 4 px, niveau en retrait de 2 px.
    implicitWidth: 26
    implicitHeight: 12

    readonly property color fillColor: level <= 0.10 && !charging ? "#FF3B30"
        : lowPower ? "#FFCC00" : root.color
    readonly property color strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.6)

    // Corps
    Rectangle {
        id: body
        x: 0
        y: Math.round((parent.height - height) / 2)
        width: 23
        height: 12
        radius: 3.5
        color: "transparent"
        border.width: 1
        border.color: root.strokeColor
        antialiasing: true
    }
    // Borne
    Rectangle {
        x: body.width + 1
        y: body.y + 4
        width: 2
        height: 4
        radius: 1
        color: root.strokeColor
    }
    // Niveau
    Item {
        id: fillClip
        x: 2
        y: body.y + 2
        width: Math.max(1, Math.round((body.width - 4) * Math.max(0.06, Math.min(1, root.level))))
        height: body.height - 4
        clip: true

        Rectangle {
            width: body.width - 4
            height: parent.height
            radius: 1.5
            color: root.fillColor
        }
    }

    // Éclair (charge) : dessiné en couleur de remplissage avec un liseré évidé
    Shape {
        visible: root.charging || root.pluggedFull
        anchors.centerIn: body
        width: 9
        height: 13
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            // Contour "évidé" : trait de la couleur du fond = transparent impossible,
            // on trace un liseré sombre / clair discret autour de l'éclair.
            strokeWidth: 1.4
            strokeColor: Qt.rgba(1 - root.color.r, 1 - root.color.g, 1 - root.color.b, 0.55)
            joinStyle: ShapePath.RoundJoin
            fillColor: root.color
            startX: 5.6; startY: 0.4
            PathLine { x: 1.0; y: 7.4 }
            PathLine { x: 4.4; y: 7.4 }
            PathLine { x: 3.4; y: 12.6 }
            PathLine { x: 8.0; y: 5.4 }
            PathLine { x: 4.6; y: 5.4 }
            PathLine { x: 5.6; y: 0.4 }
        }
    }
}
