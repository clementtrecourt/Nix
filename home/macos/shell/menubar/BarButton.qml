import QtQuick
import QtQuick.Effects
import qs.common

// Élément de la barre (titre de menu ou icône d'état). Quand son menu ou son
// panneau est ouvert, il reçoit la pastille Tahoe : capsule de verre clair
// derrière le libellé. Le contenu porte un léger halo pour rester lisible sur
// n'importe quel fond (la barre n'a pas de fond).
Item {
    id: root

    property bool active: false
    property real padding: 10
    // Débord de la pastille de part et d'autre de l'élément : sur Tahoe, la
    // pastille d'une icône d'état (~44 x 24 pt pour le Control Center) est plus
    // large que l'écart entre deux pictos (~20 pt).
    property real pillExtra: 0
    // Couleur de premier plan (blanc / noir selon le fond)
    property color fg: "white"
    property bool lightBackdrop: false
    // Halo de lisibilité (inutile sur le fond opaque de la barre en plein écran)
    property bool halo: true
    default property alias content: holder.data

    signal pressed(var mouse)
    signal entered()
    // Glisser bouton enfoncé (point dans le repère de la fenêtre de la barre) :
    // macOS permet d'appuyer sur un titre, glisser jusqu'à un élément et relâcher
    signal dragged(point p)
    signal released(point p)

    implicitWidth: holder.childrenRect.width + padding * 2
    implicitHeight: parent ? parent.height : 32

    // Verre (Liquid Glass sur le fond d'écran) pour la pastille ; sinon
    // (barre opaque du plein écran) simple capsule teintée
    property bool glassPill: true

    // Pastille Tahoe : capsule de ~24 pt de haut, sans liseré visible, qui
    // ÉCLAIRCIT le fond en gardant sa couleur (capture Ars Technica de Tahoe,
    // Control Center ouvert : bleu 62,115,165 -> 78,134,187, soit la luminance
    // rapprochée du blanc de ~13 % et la chrominance conservée : c'est la
    // compression de luminance du verre, pas un voile blanc qui délaverait).
    // Sur fond clair (texte noir), la pastille assombrit légèrement.
    readonly property real pillWidth: width + 2 * pillExtra
    // (20-22 pt de haut sur Tahoe)
    readonly property real pillHeight: Math.min(height - 8, 22)
    Loader {
        id: pillGlass
        active: root.glassPill && (root.active || opacity > 0)
        anchors.centerIn: parent
        width: root.pillWidth
        height: root.pillHeight
        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        sourceComponent: Glass {
            radius: height / 2
            tint: root.lightBackdrop ? Qt.rgba(0, 0, 0, 0.09) : Qt.rgba(1, 1, 1, 0.13)
            adaptive: 0
            saturation: 1.1
            refraction: 2
            blur: 3
            shadowEnabled: false
            // (liseré à peine perceptible : la pastille de Tahoe n'a pas de bord net)
            rimColor: Qt.rgba(1, 1, 1, root.lightBackdrop ? 0.18 : 0.07)
            rimBase: 0.2
            glowColor: "transparent"
            shadeColor: "transparent"
            edgeDarken: 0
        }
    }
    Rectangle {
        id: pill
        visible: !root.glassPill
        anchors.centerIn: parent
        width: root.pillWidth
        height: root.pillHeight
        radius: height / 2
        color: root.lightBackdrop ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.20)
        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
    }

    Item {
        id: holder
        x: root.padding
        width: childrenRect.width
        height: parent.height

        // Halo discret (ombre portée sans décalage, comme la barre de Tahoe)
        layer.enabled: root.halo
        layer.effect: MultiEffect {
            shadowEnabled: true
            // (sur fond clair, un halo blanc marqué grisait le texte noir : à peine visible)
            shadowColor: root.lightBackdrop ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.42)
            shadowBlur: 0.45
            blurMax: 10
            shadowVerticalOffset: root.lightBackdrop ? 0 : 0.5
            shadowHorizontalOffset: 0
            autoPaddingEnabled: true
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => root.pressed(mouse)
        onEntered: root.entered()
        // (pendant l'appui, Wayland continue d'envoyer le pointeur à la barre
        // même hors de sa surface : c'est elle qui pilote alors le menu)
        onPositionChanged: mouse => { if (pressed) root.dragged(mapToItem(null, mouse.x, mouse.y)); }
        onReleased: mouse => root.released(mapToItem(null, mouse.x, mouse.y))
    }
}
