import QtQuick
import qs.common

// Grille d'icônes avec en-têtes de section pleine largeur (vue Applications,
// vue Fichiers). Navigation clavier gérée par moveSelection(dx, dy).
ListView {
    id: root

    // Liste plate : { header: true, title } ou élément (app / fichier)
    property var items: []
    property int columns: Metrics.gridColumns
    property int selected: 0          // index dans `flat` (éléments sans en-têtes)
    property int iconSize: Metrics.gridIcon
    // Sans saisie ni navigation clavier, aucune case n'est surlignée (Tahoe)
    property bool showSelection: true

    signal activated(var item)
    signal hoveredIndex(int i)

    readonly property real cellWidth: width / columns

    // Éléments seuls (sans en-têtes), dans l'ordre d'affichage
    readonly property var flat: items.filter(i => !i.header)

    // Lignes : { header, title } | { cells: [{ item, flat }] }
    readonly property var rows: {
        const out = [];
        let row = null, n = 0;
        for (const it of items) {
            if (it.header) {
                row = null;
                out.push({ header: true, title: it.title });
                continue;
            }
            if (!row || row.cells.length >= columns) {
                row = { cells: [] };
                out.push(row);
            }
            row.cells.push({ item: it, flat: n++ });
        }
        return out;
    }

    function rowOf(flatIndex) {
        for (let r = 0; r < rows.length; r++) {
            const cells = rows[r].cells;
            if (cells && cells.length && flatIndex >= cells[0].flat && flatIndex <= cells[cells.length - 1].flat) return r;
        }
        return -1;
    }

    function moveSelection(dx, dy) {
        if (!flat.length) return;
        if (dx !== 0) {
            selected = Math.max(0, Math.min(flat.length - 1, selected + dx));
        } else {
            const r = rowOf(selected);
            const col = selected - rows[r].cells[0].flat;
            let t = r + dy;
            while (t >= 0 && t < rows.length && rows[t].header) t += dy;
            if (t < 0 || t >= rows.length) return;
            const cells = rows[t].cells;
            selected = cells[Math.min(col, cells.length - 1)].flat;
        }
        positionViewAtIndex(rowOf(selected), ListView.Contain);
    }

    function current() { return flat[selected] ?? null; }

    onItemsChanged: { selected = 0; positionViewAtBeginning(); }

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: rows
    reuseItems: true
    cacheBuffer: 400

    delegate: Item {
        id: rowItem
        required property var modelData
        width: root.width
        height: modelData.header ? 34 : Metrics.gridCellHeight

        Text {
            visible: !!rowItem.modelData.header
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: rowItem.modelData.title ?? ""
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: Theme.labelSecondary
        }

        Row {
            visible: !rowItem.modelData.header
            Repeater {
                model: rowItem.modelData.cells ?? []
                delegate: Item {
                    id: cell
                    required property var modelData
                    readonly property bool isSel: root.showSelection && modelData.flat === root.selected
                    width: root.cellWidth
                    height: Metrics.gridCellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 14
                        color: cell.isSel ? Theme.fillHover : (cellMouse.containsMouse ? Theme.fill : "transparent")
                        Behavior on color { ColorAnimation { duration: 90 } }
                    }
                    ItemIcon {
                        id: ic
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 8
                        size: root.iconSize
                        item: cell.modelData.item
                        scale: cellMouse.pressed ? 0.92 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                    }
                    Text {
                        anchors.top: ic.bottom
                        anchors.topMargin: 5
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 10
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.item.title ?? ""
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        lineHeight: 0.95
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: Theme.label
                    }
                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { root.selected = cell.modelData.flat; root.activated(cell.modelData.item); }
                    }
                }
            }
        }
    }
}
