import QtQuick
import qs.common

// Menu du bouton « ⋯ » de la vue Applications (Tahoe) : « Afficher le
// contenu sous forme de » Grille / Liste. Plaque de verre façon menu AppKit : lignes de 24 pt,
// colonne de coche, surbrillance accent arrondie en retrait de 5 pt.
Item {
    id: root

    property bool open: false
    property bool asList: false
    property int highlighted: -1

    signal picked(bool asList)

    readonly property var entries: [
        { text: "Afficher le contenu sous forme de", title: true },
        { text: "Grille", list: false },
        { text: "Liste", list: true }
    ]

    width: 236
    height: col.implicitHeight + 10
    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.96
    transformOrigin: Item.TopRight
    Behavior on opacity { NumberAnimation { duration: root.open ? 90 : 160 } }
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    onOpenChanged: highlighted = -1

    Glass {
        anchors.fill: parent
        radius: Theme.radiusMenu
        // Quasi opaque : le flou de Hyprland ne s'applique qu'à ce qui est
        // DERRIÈRE la surface, pas aux pastilles du panneau sous le menu.
        tint: Theme.dark ? Qt.rgba(0.16, 0.16, 0.17, 0.97) : Qt.rgba(0.96, 0.96, 0.97, 0.97)
        shadowBlur: 0.6
        shadowOffset: 4
        shadowMax: 0.045      // sous le seuil ignore_alpha de Hyprland
    }

    Column {
        id: col
        x: 5
        y: 5
        width: parent.width - 10
        Repeater {
            model: root.entries
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool isTitle: !!modelData.title
                readonly property bool lit: !isTitle && (root.highlighted === index || mouse.containsMouse)
                width: col.width
                height: 24
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMenuItem - 2
                    color: Theme.menuHighlight
                    visible: row.lit
                }
                Symbol {
                    x: 9
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !row.isTitle && root.asList === row.modelData.list
                    name: "checkmark"
                    size: 11
                    color: row.lit ? Theme.menuHighlightText : Theme.label
                }
                Text {
                    x: 26
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.text
                    font.family: Theme.font
                    font.pixelSize: row.isTitle ? 12 : 13
                    font.weight: row.isTitle ? Font.DemiBold : Font.Normal
                    color: row.lit ? Theme.menuHighlightText : (row.isTitle ? Theme.labelSecondary : Theme.label)
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: !row.isTitle
                    enabled: !row.isTitle
                    onClicked: root.picked(row.modelData.list)
                }
            }
        }
    }
}
