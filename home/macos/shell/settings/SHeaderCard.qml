import QtQuick
import qs.common

// Carte d'en-tête d'un panneau (Tahoe) : pastille de 26 pt à gauche, titre
// 13 pt, description grise 11 pt (interligne 14) ; contrôle facultatif à
// droite (interrupteur Wi‑Fi / Bluetooth). Capture 2x MacStories (Spotlight) :
// pastille à 11 pt du bord, texte à 46 pt, titre centré à 18 pt du haut.
Rectangle {
    id: root

    property var pane: null
    property string title: pane?.name ?? ""
    property string description
    default property alias controls: ctl.data

    width: parent ? parent.width : 0
    height: implicitHeight
    radius: SStyle.groupRadius
    color: SStyle.groupFill
    implicitHeight: Math.max(48, Math.round(desc.y + (desc.visible ? desc.height : 0) + 11))

    Item {
        id: body
        anchors.fill: parent
    PaneIcon {
        x: 11
        y: 10
        spec: root.pane
        size: 26
    }
    Text {
        id: titleText
        x: 46
        y: 10
        width: ctl.x - x - 10
        text: root.title
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: SStyle.body
        lineHeight: 16
        lineHeightMode: Text.FixedHeight
        color: SStyle.label
    }
    Text {
        id: desc
        visible: root.description !== ""
        x: 46
        y: 26
        width: ctl.x - x - 10
        text: root.description
        wrapMode: Text.WordWrap
        textFormat: Text.StyledText
        linkColor: SStyle.link
        font.family: Theme.font
        font.pixelSize: SStyle.small
        lineHeight: 14
        lineHeightMode: Text.FixedHeight
        color: SStyle.secondary
    }
    }
    Row {
        id: ctl
        x: root.width - width - SStyle.pad
        y: 16
        spacing: 8
    }
}
