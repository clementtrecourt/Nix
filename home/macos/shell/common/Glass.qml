import QtQuick
import qs.common

// Plaque "Liquid Glass" (macOS Tahoe) : teinte translucide, lueur interne
// d'épaisseur près des bords, liseré spéculaire qui s'allume sur les bords
// orientés vers la lumière (haut-gauche, et plus faiblement bas-droite), ombre
// portée douce. Tout est calculé dans un seul shader SDF
// (assets/shaders/glass.frag) : pas de couche intermédiaire, pas d'artefact
// carré autour de l'ombre, l'intérieur du verre n'est jamais assombri par
// l'ombre.
//
// Le flou d'arrière-plan vient de Hyprland (layerrule blur sur le namespace
// "macos-*" de la surface) : rien n'est flouté ici.
//
// L'ombre déborde de l'item (de ~3 x shadowBlur x 14 px) : prévoir cette marge
// dans la fenêtre.
//
// Usage : Glass { radius: Theme.radiusPanel; <contenu> }
Item {
    id: root

    property real radius: Theme.radiusPanel
    property color tint: thick ? Theme.glassThick : Theme.glass
    property bool thick: false
    property bool shadowEnabled: true
    // 1.0 = ombre de panneau standard (sigma 14 px) ; 0.5 = ombre courte.
    property real shadowBlur: 1.0
    property int shadowOffset: 8
    property color shadowColor: Theme.shadow
    default property alias content: contentItem.data

    // --- Réglages fins (optionnels) ---
    // Liseré spéculaire : couleur, épaisseur, intensité minimale hors lumière.
    property color rimColor: Theme.glassHighlight
    property real rimWidth: 1.5
    property real rimBase: Theme.dark ? 0.16 : 0.30
    // Lueur interne (épaisseur du verre).
    property color glowColor: Theme.glassGlow
    property real glowWidth: Math.min(14, Math.min(width, height) * 0.22)
    // Angle (degrés) de la lumière : 225 = vient du haut-gauche.
    property real lightAngle: 225
    // Alpha max de l'ombre. Hyprland floute tout pixel des surfaces "macos-*"
    // dont l'alpha dépasse ignore_alpha (0.3 attendu) : une ombre plus opaque
    // ferait apparaître un halo flouté autour du verre.
    property real shadowMax: 0.26

    readonly property real _sigma: shadowEnabled ? Math.max(0.5, shadowBlur * 14) : 0
    readonly property int _pad: shadowEnabled ? Math.ceil(_sigma * 3 + Math.abs(shadowOffset)) : 1

    ShaderEffect {
        id: fx
        x: -root._pad
        y: -root._pad
        width: root.width + 2 * root._pad
        height: root.height + 2 * root._pad
        visible: root.width > 0 && root.height > 0
        fragmentShader: Qt.resolvedUrl("../assets/shaders/glass.frag.qsb")

        property vector2d itemSize: Qt.vector2d(width, height)
        property vector4d plate: Qt.vector4d(root._pad, root._pad, root.width, root.height)
        property real radius: root.radius
        property color tint: root.tint
        property color rimColor: root.rimColor
        property real rimWidth: root.rimWidth
        property real rimBase: root.rimBase
        property color glowColor: root.glowColor
        property real glowWidth: root.glowWidth
        property color shadowColor: root.shadowColor
        property real shadowSigma: root._sigma
        property real shadowOffsetY: root.shadowOffset
        property real shadowMax: root.shadowMax
        // Direction dans laquelle se propage la lumière (repère écran, y vers le bas)
        property vector2d lightDir: Qt.vector2d(-Math.cos(root.lightAngle * Math.PI / 180),
                                                -Math.sin(root.lightAngle * Math.PI / 180))
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }
}
