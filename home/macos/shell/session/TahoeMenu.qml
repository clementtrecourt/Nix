import QtQuick
import qs.common

// Menu contextuel façon macOS Tahoe : plaque de verre aux coins arrondis,
// lignes de 24 px avec pictogramme (Tahoe en met devant presque chaque
// commande), surbrillance accent arrondie, séparateurs fins, chevron de
// sous-menu. Au clic, la ligne clignote une fois avant l'action (détail AppKit).
//
// items : [{ text, icon?, enabled?, separator?, submenu?, action? }]
Item {
    id: root

    property var items: []
    property int minWidth: 220
    signal triggered(var item)

    readonly property bool hasIcons: items.some(i => !!i.icon)
    readonly property int padding: 5
    readonly property int rowHeight: 24

    implicitWidth: Math.max(minWidth, measure.maxWidth + (hasIcons ? 34 : 14) + 34)
    implicitHeight: col.implicitHeight + padding * 2

    // Largeur du libellé le plus long
    Item {
        id: measure
        visible: false
        property real maxWidth: {
            let m = 0;
            for (let i = 0; i < rep.count; ++i) {
                const it = rep.itemAt(i);
                if (it && it.textWidth > m) m = it.textWidth;
            }
            return m;
        }
    }

    Glass {
        anchors.fill: parent
        radius: Theme.radiusMenu
        tint: Theme.menuBackground
        shadowBlur: 0.9
        shadowOffset: 6
    }

    Column {
        id: col
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2

        Repeater {
            id: rep
            model: root.items

            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool sep: !!modelData.separator
                readonly property bool on: modelData.enabled !== false && !sep
                readonly property real textWidth: label.implicitWidth
                property bool flashing: false
                width: col.width
                height: sep ? 11 : root.rowHeight

                // Séparateur
                Rectangle {
                    visible: row.sep
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    width: parent.width - 20
                    height: 1
                    color: Theme.separator
                }

                // Surbrillance
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMenuItem
                    color: Theme.menuHighlight
                    visible: !row.sep && row.on && (hover.containsMouse || row.flashing) && !blink.blinkOff
                }

                Symbol {
                    visible: !row.sep && !!row.modelData.icon
                    name: row.modelData.icon ?? ""
                    size: 15
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: highlighted ? Theme.menuHighlightText : (row.on ? Theme.label : Theme.labelTertiary)
                    readonly property bool highlighted: row.on && (hover.containsMouse || row.flashing) && !blink.blinkOff
                }

                Text {
                    id: label
                    visible: !row.sep
                    text: row.modelData.text ?? ""
                    x: root.hasIcons ? 34 : 12
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    color: (row.on && (hover.containsMouse || row.flashing) && !blink.blinkOff)
                        ? Theme.menuHighlightText
                        : (row.on ? Theme.label : Theme.labelTertiary)
                }

                Symbol {
                    visible: !row.sep && !!row.modelData.submenu
                    name: "chevron.right"
                    size: 11
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    color: label.color
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: row.on
                    onClicked: {
                        row.flashing = true;
                        blink.restart();
                    }
                }

                // Clignotement de validation (éteint 70 ms puis rallumé 70 ms)
                SequentialAnimation {
                    id: blink
                    property bool blinkOff: false
                    PropertyAction { target: blink; property: "blinkOff"; value: true }
                    PauseAnimation { duration: 70 }
                    PropertyAction { target: blink; property: "blinkOff"; value: false }
                    PauseAnimation { duration: 70 }
                    ScriptAction {
                        script: {
                            row.flashing = false;
                            root.triggered(row.modelData);
                        }
                    }
                }
            }
        }
    }
}
