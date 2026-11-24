import QtQuick
import qs.common

// Module du Control Center : plaque Liquid Glass "claire" qui s'éclaircit au
// survol et s'illumine / gonfle légèrement à la pression (comportement des
// contrôles Liquid Glass de Tahoe).
Item {
    id: tile

    property real radius: CCStyle.radiusTile
    property bool interactive: true
    property bool glassVisible: true
    // Verre (valeurs du Control Center par défaut ; le HUD a les siennes)
    property color tint: CCStyle.tile
    property color hoverTint: CCStyle.tileHover
    property real glassSaturation: CCStyle.glassSaturation
    readonly property alias hovered: ma.containsMouse
    readonly property alias pressed: ma.pressed
    // Contenu du module (le dépliage en fait un fondu sortant dans la carte)
    readonly property alias contentLayer: inner
    signal clicked()
    default property alias content: inner.data

    Glass {
        id: glass
        anchors.fill: parent
        radius: tile.radius
        tint: ma.containsMouse && tile.interactive ? tile.hoverTint : tile.tint
        // Liseré teinté par le fond (référence Tahoe : cyan sur fond bleu)
        rimTintMix: 0.7
        blur: CCStyle.glassBlur
        saturation: tile.glassSaturation
        adaptive: CCStyle.glassAdaptive
        // Liseré directionnel (arcs éclairés), flancs presque éteints
        rimBase: CCStyle.rimBase
        edgeDarken: CCStyle.edgeDarken
        // Pas d'anneau sombre autour du module (Tahoe)
        shadowEnabled: CCStyle.tileShadow
        opacity: tile.glassVisible ? 1 : 0
        Behavior on tint { ColorAnimation { duration: 140 } }
    }

    // Illumination sous le pointeur pendant la pression
    Rectangle {
        anchors.fill: parent
        radius: tile.radius
        color: "white"
        opacity: ma.pressed && tile.interactive ? 0.10 : 0
        visible: tile.glassVisible
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    // Toujours actif : un module grisé "avale" le clic (sinon il atteindrait le
    // fond de la surface, qui ferme le Control Center).
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: tile.interactive
        onClicked: if (tile.interactive) tile.clicked()
    }

    Item {
        id: inner
        anchors.fill: parent
    }

    scale: ma.pressed && interactive ? 1.025 : 1
    Behavior on scale { SpringAnimation { spring: 6; damping: 0.38; epsilon: 0.0005 } }
}
