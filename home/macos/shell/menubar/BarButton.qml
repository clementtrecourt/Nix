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

    implicitWidth: holder.childrenRect.width + padding * 2
    implicitHeight: parent ? parent.height : 32

    // Pastille (capsule de verre clair, sans liseré visible : blanc ~0,30 mesuré
    // sur la capture Apple). Sur fond clair : voile sombre très léger.
    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width + 2 * root.pillExtra
        height: Math.min(parent.height - 8, 24)
        radius: height / 2
        color: root.lightBackdrop ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.30)
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
    }
}
