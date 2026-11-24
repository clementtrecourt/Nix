import QtQuick
import Quickshell
import qs.common

// Contenu d'un menu du Dock, au style des menus de la barre Tahoe
// (menubar/MenuRow.qml, mesurés sur captures 2x) : plaque Liquid Glass de rayon
// 14 pt, lignes de 24 pt, surbrillance accent arrondie en retrait de 5 pt,
// coche centrée à 23 pt, texte à 37 pt (16 pt sans colonne de coche), filets
// et chevron à 16 pt des bords, clignotement avant l'action.
//
// entries : [{ text, checked?, minimized?, enabled?, separator?, header?, submenu?: [...],
//              action?: fn, altText?, altAction?: fn }]
//   header  : en-tête de section (11 pt demi-gras, gris, non sélectionnable),
//             aligné sur le texte des éléments (« Sort by », « Assign To »)
//   altText : libellé quand Option est enfoncée (« Quit » -> « Force Quit »)
Item {
    id: root

    property var entries: []
    property int highlighted: -1
    // Option enfoncée (libellés alternatifs)
    property bool alt: false
    // Marge transparente autour de la plaque pour laisser déborder l'ombre
    readonly property int margin: 24
    readonly property int padding: 5
    readonly property int rowH: 24
    readonly property int edge: 16
    readonly property real radius: 14
    readonly property bool hasLead: entries.some(e => e.checked !== undefined || e.minimized)

    // Option enfoncée / relâchée pendant que le menu a le clavier
    focus: true
    Keys.onPressed: (e) => { if (e.key === Qt.Key_Alt) root.alt = true; }
    Keys.onReleased: (e) => { if (e.key === Qt.Key_Alt) root.alt = false; }

    signal triggered(var entry)
    signal hoveredRow(int row, var item)

    readonly property real textX: hasLead ? 37 : 16

    FontMetrics {
        id: fm
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }
    // Largeur : texte le plus long + 24 pt de respiration (+16 pt de chevron),
    // au moins 140 pt, au plus ~400 pt (titres de fenêtre élidés)
    readonly property real contentW: {
        let w = 0;
        for (const e of entries) {
            if (e.separator) continue;
            const t = Math.max(fm.advanceWidth(e.text ?? ""), e.altText ? fm.advanceWidth(e.altText) : 0);
            w = Math.max(w, textX + Math.min(t, 340) + 24 + (e.submenu ? 16 : 0));
        }
        return Math.ceil(Math.max(140, w));
    }
    readonly property real contentH: col.implicitHeight + 2 * padding

    implicitWidth: contentW + 2 * margin
    implicitHeight: contentH + 2 * margin

    // Plaque (zone d'entrée de la fenêtre)
    Item {
        id: plate
        x: root.margin
        y: root.margin
        width: root.contentW
        height: root.contentH

        // Sans réfraction (capture indisponible) : voile posé par un Rectangle
        // (alpha correct), le flou venant alors de Hyprland
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: Theme.menuBackground
            antialiasing: true
            visible: !glass.refracting
        }
        Glass {
            id: glass
            anchors.fill: parent
            radius: root.radius
            // Avec réfraction, le verre est opaque : la teinte devient son voile
            overlay: refracting ? Theme.menuBackground : "transparent"
            tint: "transparent"
            shadowBlur: 0.5
            shadowOffset: 4
        }

        Column {
            id: col
            y: root.padding
            width: parent.width

            Repeater {
                id: rep
                model: root.entries

                Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sep: !!modelData.separator
                    readonly property bool head: !!modelData.header
                    readonly property bool on: !sep && !head && modelData.enabled !== false
                    readonly property bool useAlt: root.alt && !!modelData.altText
                    readonly property bool lit: on && root.highlighted === index && !blink.off
                    readonly property color fg: head ? Theme.labelSecondary : lit ? Theme.menuHighlightText : (on ? Theme.label : Theme.labelTertiary)
                    width: col.width
                    height: sep ? 11 : root.rowH

                    Rectangle {
                        visible: row.sep
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.edge
                        width: parent.width - 2 * root.edge
                        height: 1
                        color: Theme.separator
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 5
                        anchors.rightMargin: 5
                        radius: Theme.radiusMenuItem
                        color: Theme.menuHighlight
                        visible: row.lit
                    }
                    Symbol {
                        visible: !row.sep && !!row.modelData.checked
                        x: 23 - size / 2
                        anchors.verticalCenter: parent.verticalCenter
                        name: "checkmark"
                        size: 12
                        color: row.fg
                    }
                    // Fenêtre minimisée : losange (◆) comme dans le menu Fenêtre
                    Text {
                        visible: !row.sep && !row.modelData.checked && !!row.modelData.minimized
                        x: 23 - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: "◆"
                        font.pixelSize: 9
                        color: row.fg
                    }
                    Text {
                        visible: !row.sep
                        x: root.textX
                        width: Math.min(implicitWidth, parent.width - root.textX - root.edge - (row.modelData.submenu ? 16 : 0))
                        elide: Text.ElideMiddle
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: row.head ? 1.5 : 0
                        text: row.useAlt ? row.modelData.altText : (row.modelData.text ?? "")
                        textFormat: Text.PlainText
                        font.family: Theme.font
                        font.pixelSize: row.head ? Theme.fontSizeSmall : Theme.fontSize
                        font.weight: row.head ? Font.DemiBold : Font.Normal
                        color: row.fg
                    }
                    Symbol {
                        visible: !row.sep && !!row.modelData.submenu
                        anchors.right: parent.right
                        anchors.rightMargin: root.edge - 2
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron.right"
                        size: 10
                        color: row.lit ? Theme.menuHighlightText : (row.on ? Theme.label : Theme.labelTertiary)
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: row.on
                        onEntered: { root.highlighted = row.index; root.hoveredRow(row.index, row); }
                        onPositionChanged: (m) => root.alt = !!(m.modifiers & Qt.AltModifier)
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
                        ScriptAction { script: root.triggered(row.useAlt ? Object.assign({}, row.modelData, { action: row.modelData.altAction }) : row.modelData) }
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
