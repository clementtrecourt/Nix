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
//
// Matériaux :
//  - par défaut : Liquid Glass (lentille de bord, flou léger) ;
//  - `frost` > 0 : verre DÉPOLI des fenêtres, alertes et menus AppKit (flou de
//    `frost` px, sans lentille ni bande sombre de bord) : le fond n'y paraît
//    que comme une teinte, jamais lisible (About This Mac de Tahoe : ciel
//    86,141,193 -> 225,249,255) ;
//  - `opaque` : fond plein (Force Quit Applications : blanc 255 en clair) ;
//    seuls l'ombre et le liseré restent.
Item {
    id: root

    property real radius: Theme.radiusPanel
    property color tint: Theme.glassThick
    property real shadowBlur: 1.0
    property int shadowOffset: 8
    property color shadowColor: Theme.shadow
    property real frost: 0
    property bool opaque: false
    // Saturation du fond dépoli (vibrancy : la couleur du fond est gardée)
    property real frostSaturation: Theme.dark ? 1.25 : 1.6

    readonly property bool frosted: frost > 0 && !opaque

    // Avec réfraction, le verre est opaque : la teinte devient son voile (overlay)
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tint
        visible: !glass.refracting
    }
    Glass {
        id: glass
        anchors.fill: parent
        // (fond plein : la teinte opaque recouvre entièrement la capture)
        overlay: refracting ? root.tint : "transparent"
        radius: root.radius
        tint: "transparent"
        shadowBlur: root.shadowBlur
        shadowOffset: root.shadowOffset
        shadowColor: root.shadowColor
    }

    // Verre dépoli : flou fort, ni lentille ni assombrissement de bord
    Binding { target: glass; property: "blur"; value: root.frost; when: root.frosted }
    Binding { target: glass; property: "refraction"; value: 0; when: root.frosted || root.opaque }
    Binding { target: glass; property: "edgeDarken"; value: 0; when: root.frosted || root.opaque }
    Binding { target: glass; property: "edgeSaturate"; value: 0; when: root.frosted || root.opaque }
    Binding { target: glass; property: "adaptive"; value: 0; when: root.frosted }
    Binding { target: glass; property: "saturation"; value: root.frostSaturation; when: root.frosted }
    // Fond plein : inutile de flouter la capture
    Binding { target: glass; property: "blur"; value: 0; when: root.opaque }
    // Liseré discret (les fenêtres AppKit n'ont qu'un filet clair)
    Binding {
        target: glass; property: "rimColor"; when: root.frosted || root.opaque
        value: Theme.dark ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.70)
    }
    Binding {
        target: glass; property: "glowColor"; when: root.frosted || root.opaque
        value: Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.12)
    }
    Binding {
        target: glass; property: "shadeColor"; when: root.frosted || root.opaque
        value: Theme.dark ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(0, 0, 0, 0.02)
    }
}
