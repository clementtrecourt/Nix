import QtQuick
import qs.common

// Légende de section ("Réseaux connus", "Appareils", "Sortie"...),
// avec chevron optionnel pour les sections repliables ("Autres réseaux").
Item {
    id: c

    property string text
    property bool collapsible: false
    property bool expanded: true
    signal toggled()

    implicitWidth: CCStyle.width
    implicitHeight: 24

    Text {
        renderType: Text.CurveRendering
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        text: c.text
        color: CCStyle.textSecondary
        font.family: Theme.font
        font.letterSpacing: CCStyle.tracking
        font.pixelSize: CCStyle.captionSize
        font.weight: Font.DemiBold
    }

    Symbol {
        visible: c.collapsible
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron.right"
        size: 12
        color: CCStyle.text
        opacity: CCStyle.textSecondary.a     // Symbol ignore l'alpha de la couleur
        rotation: c.expanded ? 90 : 0
        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: c.collapsible
        onClicked: c.toggled()
    }
}
