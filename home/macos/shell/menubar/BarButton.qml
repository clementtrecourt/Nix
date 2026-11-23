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
    // Couleur de premier plan (blanc / noir selon le fond)
    property color fg: "white"
    property bool lightBackdrop: false
    default property alias content: holder.data

    signal pressed(var mouse)
    signal entered()

    implicitWidth: holder.childrenRect.width + padding * 2
    implicitHeight: parent ? parent.height : 32

    // Pastille (capsule de verre). Sur fond clair : voile sombre très léger.
    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Math.min(parent.height - 8, 24)
        radius: height / 2
        color: root.lightBackdrop ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.22)
        border.width: 1
        border.color: root.lightBackdrop ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.16)
        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
    }

    Item {
        id: holder
        x: root.padding
        width: childrenRect.width
        height: parent.height

        // Halo discret (ombre portée sans décalage, comme la barre de Tahoe)
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.lightBackdrop ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.42)
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
