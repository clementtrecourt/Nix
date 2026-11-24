import QtQuick
import Quickshell
import qs.common

// Capsule de verre de la barre d'outils de Tahoe (36 pt de haut, marge interne
// 4 pt) qui regroupe des boutons. Réfracte le contenu de la fenêtre qui défile
// dessous (LiquidGlass, backdrop "snapshot" sur la scène de la fenêtre).
Item {
    id: root

    property Item backdropItem: null
    default property alias content: row.data
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + 2 * FStyle.capsulePad
    implicitHeight: FStyle.capsuleHeight
    width: implicitWidth
    height: implicitHeight

    FinderGlass {
        anchors.fill: parent
        radius: height / 2
        backdropItem: root.backdropItem
        tint: FStyle.capsuleTint
    }

    Row {
        id: row
        x: FStyle.capsulePad
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
    }
}
