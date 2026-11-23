import QtQuick
import qs.common

// Plaque de verre des fenêtres / menus de la session : le remplissage teinté
// est un Rectangle (couleur composée normalement par Qt), et Glass n'ajoute
// par-dessus que liseré, lueur interne et ombre portée (teinte transparente).
//
// Pourquoi : la teinte passée au shader de Glass arrive déjà prémultipliée
// (ShaderEffect convertit les `color` en vec4 prémultiplié) et le shader la
// prémultiplie une seconde fois ; un blanc à 0,66 y devient un gris-bleu
// (≈ rgb(138,162,182) mesuré sur le fond Tahoe). Les menus et alertes claires
// de Tahoe sont au contraire d'un blanc laiteux.
Item {
    id: root

    property real radius: Theme.radiusPanel
    property color tint: Theme.glassThick
    property real shadowBlur: 1.0
    property int shadowOffset: 8
    property color shadowColor: Theme.shadow

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tint
    }
    Glass {
        anchors.fill: parent
        radius: root.radius
        tint: "transparent"
        shadowBlur: root.shadowBlur
        shadowOffset: root.shadowOffset
        shadowColor: root.shadowColor
    }
}
