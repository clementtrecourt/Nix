import QtQuick
import qs.common

// Contenu d'un menu de Tahoe (menu contextuel, menus de la barre d'outils) :
// plaque claire/sombre aux coins de 12 pt, lignes de 24 pt en 13 pt, petit
// pictogramme devant les commandes (nouveauté de Tahoe), surbrillance
// d'accent en pastille inset, séparateurs fins, raccourcis à droite, chevron
// de sous-menu, rangée de pastilles de tags.
// Capture de référence : Apple mh26885 (menu contextuel du Finder, Tahoe).
//
// items : [{ text, icon?, shortcut?, enabled?, separator?, checked?, submenu?,
//            action?, tags?: true, header? }]
Item {
    id: root

    property var items: []
    property int highlighted: -1
    readonly property int margin: 30          // place pour l'ombre portée
    readonly property int padding: 5
    readonly property int rowHeight: 24
    readonly property bool hasIcons: items.some(i => !!i.icon || i.checked !== undefined)
    readonly property real textX: hasIcons ? 33 : 14
    readonly property alias plateItem: plate
    readonly property real contentW: plate.width
    signal triggered(var item)
    signal hoveredRow(int index, var rowItem)

    readonly property real _maxText: {
        let m = 0;
        for (let i = 0; i < rep.count; ++i) {
            const r = rep.itemAt(i);
            if (r) m = Math.max(m, r.needed);
        }
        return m;
    }
    implicitWidth: plate.width + 2 * margin
    implicitHeight: plate.height + 2 * margin

    function rowItem(i) { return rep.itemAt(i); }

    Item {
        id: plate
        x: root.margin
        y: root.margin
        width: Math.max(200, root._maxText + 2 * root.padding)
        height: col.implicitHeight + 2 * root.padding

        Glass {
            anchors.fill: parent
            radius: 12
            tint: Theme.dark ? Qt.rgba(0.17, 0.17, 0.18, 0.97) : Qt.rgba(0.985, 0.985, 0.99, 0.97)
            shadowBlur: 0.85
            shadowOffset: 8
            shadowMax: 1.0
            shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.5 : 0.22)
            rimBase: Theme.dark ? 0.35 : 0.6
            glowWidth: 0
        }
        // Liseré fin
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "transparent"
            border.width: 0.5
            border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
        }

        Column {
            id: col
            x: root.padding
            y: root.padding
            width: plate.width - 2 * root.padding

            Repeater {
                id: rep
                model: root.items

                Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sep: !!modelData.separator
                    readonly property bool tagRow: !!modelData.tags
                    readonly property bool hdr: !!modelData.header
                    readonly property bool on: modelData.enabled !== false && !sep && !hdr
                    readonly property bool lit: on && !tagRow && root.highlighted === index
                    readonly property real needed: sep ? 0 : tagRow ? 7 * 22 + 24
                        : root.textX + label.implicitWidth + (modelData.shortcut ? shortcutText.implicitWidth + 28 : 0) + (modelData.submenu ? 30 : 18)
                    width: col.width
                    height: sep ? 11 : tagRow ? 30 : root.rowHeight

                    Rectangle {
                        visible: row.sep
                        x: 12
                        width: parent.width - 24
                        height: 1
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: row.lit
                        radius: 6
                        color: Theme.accent
                    }
                    Symbol {
                        visible: !row.sep && !!row.modelData.icon && row.modelData.checked === undefined
                        name: row.modelData.icon ?? ""
                        size: 15
                        x: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: row.lit ? "white" : (row.on ? Theme.label : Theme.labelTertiary)
                    }
                    Symbol {
                        visible: row.modelData.checked === true
                        name: "checkmark"
                        size: 12
                        x: 11
                        anchors.verticalCenter: parent.verticalCenter
                        color: row.lit ? "white" : Theme.label
                    }
                    Text {
                        id: label
                        visible: !row.sep && !row.tagRow
                        x: row.hdr ? 9 : root.textX - root.padding + 3
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.text ?? ""
                        font.family: Theme.font
                        font.pixelSize: row.hdr ? 11 : 13
                        font.weight: row.hdr ? Font.DemiBold : Font.Normal
                        color: row.lit ? "white" : (row.hdr ? Theme.labelSecondary : (row.on ? Theme.label : Theme.labelTertiary))
                    }
                    Text {
                        id: shortcutText
                        visible: !!row.modelData.shortcut
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.shortcut ?? ""
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: row.lit ? "white" : Theme.labelSecondary
                    }
                    Symbol {
                        visible: !!row.modelData.submenu
                        name: "chevron.right"
                        size: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: row.lit ? "white" : Theme.labelSecondary
                    }

                    // Rangée de tags : pastilles de couleur (bascule)
                    Row {
                        visible: row.tagRow
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Repeater {
                            model: row.tagRow ? Fs.tagList : []
                            Item {
                                id: dot
                                required property var modelData
                                width: 16
                                height: 16
                                readonly property bool has: row.modelData.isTagged ? row.modelData.isTagged(modelData.name) : false
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: dm.containsMouse ? 16 : 14
                                    height: width
                                    radius: width / 2
                                    color: Fs.tagColor(dot.modelData.name)
                                    border.width: 1
                                    border.color: Qt.darker(color, 1.15)
                                }
                                Symbol {
                                    visible: dot.has
                                    anchors.centerIn: parent
                                    name: dm.containsMouse ? "xmark" : "checkmark"
                                    size: 8
                                    color: "white"
                                }
                                MouseArea {
                                    id: dm
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.triggered({ tagToggle: dot.modelData.name, action: () => row.modelData.toggle(dot.modelData.name) })
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !row.tagRow
                        hoverEnabled: true
                        onContainsMouseChanged: if (containsMouse) {
                            root.highlighted = row.on ? row.index : -1;
                            root.hoveredRow(row.index, row);
                        }
                        onClicked: if (row.on) root.triggered(row.modelData)
                    }
                }
            }
        }
    }
}
