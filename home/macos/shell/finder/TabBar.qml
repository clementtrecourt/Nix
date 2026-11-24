import QtQuick
import qs.common

// Barre d'onglets du Finder (⌘T), sous la barre d'outils : capsule de verre
// découpée en onglets de même largeur, onglet actif en pastille, bouton de
// fermeture au survol, bouton « + » rond à droite (style des barres
// d'onglets de Tahoe, Safari / Finder).
Item {
    id: root

    required property var fw
    property Item backdropItem: null

    FinderGlass {
        id: cap
        x: 8.5
        y: 2
        width: parent.width - x - 8 - 36
        height: 30
        radius: 15
        backdropItem: root.backdropItem
        shadowBlur: 0.5

        Row {
            id: row
            x: 3
            y: 3
            readonly property real tabW: (cap.width - 6) / Math.max(1, root.fw.tabs.length)
            Repeater {
                model: root.fw.tabs
                Item {
                    id: tab
                    required property var modelData
                    required property int index
                    readonly property bool current: index === root.fw.tabIndex
                    width: row.tabW
                    height: 24
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: tab.current ? FStyle.toolSelected : (ma.containsMouse ? FStyle.toolHover : "transparent")
                    }
                    Rectangle {
                        visible: tab.index > 0 && !tab.current && tab.index - 1 !== root.fw.tabIndex
                        width: 1
                        height: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: FStyle.gridLine
                    }
                    Text {
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 44)
                        elide: Text.ElideMiddle
                        text: Fs.displayName(tab.modelData.path)
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: tab.current ? Font.Medium : Font.Normal
                        color: tab.current ? Theme.label : FStyle.secondaryText
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: (m) => m.button === Qt.MiddleButton ? root.fw.closeTab(tab.index) : root.fw.selectTab(tab.index)
                    }
                    // Fermer (au survol)
                    Rectangle {
                        visible: ma.containsMouse || closeMa.containsMouse
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 8
                        color: closeMa.containsMouse ? FStyle.toolSelected : "transparent"
                        Symbol { anchors.centerIn: parent; name: "xmark"; size: 8; color: FStyle.secondaryText }
                        MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.fw.closeTab(tab.index) }
                    }
                }
            }
        }
    }
    // Nouvel onglet
    Item {
        x: cap.x + cap.width + 6
        y: 2
        width: 30
        height: 30
        FinderGlass {
            anchors.fill: parent
            radius: 15
            backdropItem: root.backdropItem
            shadowBlur: 0.5
        }
        Symbol { anchors.centerIn: parent; name: "plus"; size: 13; color: FStyle.toolIconColor }
        MouseArea { anchors.fill: parent; onClicked: root.fw.newTab() }
    }
}
