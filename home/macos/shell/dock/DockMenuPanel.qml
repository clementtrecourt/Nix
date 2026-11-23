import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common

// Contenu d'un menu du Dock (même style que les menus de la barre Tahoe) :
// plaque de verre, lignes de 24 pt, surbrillance accent arrondie en retrait de
// 5 pt, colonne de coche, chevron de sous-menu, clignotement avant l'action.
//
// entries : [{ text, checked?, minimized?, enabled?, separator?, submenu?: [...], action?: fn }]
Item {
    id: root

    property var entries: []
    property int highlighted: -1
    property int minWidth: 170
    // Marge transparente autour de la plaque pour laisser déborder l'ombre
    readonly property int margin: 24
    readonly property int padding: 5
    readonly property int rowH: 24
    readonly property bool hasLead: entries.some(e => e.checked !== undefined || e.minimized)

    signal triggered(var entry)
    signal hoveredRow(int row, var item)

    readonly property real textX: hasLead ? 30 : 14
    readonly property real contentW: Math.max(minWidth, measure.w + textX + 14 + (entries.some(e => !!e.submenu) ? 22 : 0))
    readonly property real contentH: col.implicitHeight + 2 * padding

    implicitWidth: contentW + 2 * margin
    implicitHeight: contentH + 2 * margin

    Item {
        id: measure
        visible: false
        property real w: {
            let m = 0;
            for (let i = 0; i < rep.count; i++) {
                const it = rep.itemAt(i);
                if (it && it.textW > m) m = it.textW;
            }
            return Math.min(m, 360);
        }
    }

    // Plaque (zone d'entrée de la fenêtre)
    Item {
        id: plate
        objectName: "plate"
        x: root.margin
        y: root.margin
        width: root.contentW
        height: root.contentH

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
            width: parent.width - 2 * root.padding

            Repeater {
                id: rep
                model: root.entries

                Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sep: !!modelData.separator
                    readonly property bool on: !sep && modelData.enabled !== false
                    readonly property bool lit: on && root.highlighted === index && !blink.off
                    readonly property real textW: label.implicitWidth
                    readonly property color fg: lit ? Theme.menuHighlightText : (on ? Theme.label : Theme.labelTertiary)
                    width: col.width
                    height: sep ? 11 : root.rowH

                    Rectangle {
                        visible: row.sep
                        anchors.verticalCenter: parent.verticalCenter
                        x: 9
                        width: parent.width - 18
                        height: 1
                        color: Theme.separator
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusMenuItem
                        color: Theme.menuHighlight
                        visible: row.lit
                    }
                    Symbol {
                        visible: !row.sep && !!row.modelData.checked
                        x: 9 + 8 - size / 2
                        anchors.verticalCenter: parent.verticalCenter
                        name: "checkmark"
                        size: 12
                        color: row.fg
                    }
                    Text {
                        visible: !row.sep && !row.modelData.checked && !!row.modelData.minimized
                        x: 9 + 8 - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: "◆"
                        font.pixelSize: 9
                        color: row.fg
                    }
                    Text {
                        id: label
                        visible: !row.sep
                        x: root.textX - root.padding
                        width: Math.min(implicitWidth, 360)
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.text ?? ""
                        textFormat: Text.PlainText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        color: row.fg
                    }
                    Symbol {
                        visible: !row.sep && !!row.modelData.submenu
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron.right"
                        size: 10
                        color: row.lit ? Theme.menuHighlightText : Theme.labelSecondary
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: row.on
                        onEntered: { root.highlighted = row.index; root.hoveredRow(row.index, row); }
                        onClicked: if (!row.modelData.submenu) blink.restart()
                    }
                    // Validation : la ligne s'éteint 70 ms puis se rallume 70 ms
                    SequentialAnimation {
                        id: blink
                        property bool off: false
                        PropertyAction { target: blink; property: "off"; value: true }
                        PauseAnimation { duration: 70 }
                        PropertyAction { target: blink; property: "off"; value: false }
                        PauseAnimation { duration: 70 }
                        ScriptAction { script: root.triggered(row.modelData) }
                    }
                    function flash() { root.highlighted = row.index; blink.restart(); }
                }
            }
        }
    }

    readonly property Item plateItem: plate
    function rowItem(i) { return rep.itemAt(i); }
    function flashRow(i) { const r = rep.itemAt(i); if (r) r.flash(); }
}
