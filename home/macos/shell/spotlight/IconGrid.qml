import QtQuick
import qs.common

// Grille d'icônes de la vue Applications / Fichiers (Tahoe) : 5 colonnes,
// icônes de 60 pt avec leur nom dessous. Lignes spéciales :
//   { header: true, title }  en-tête de section (vue Fichiers : « Récents »)
//   { separator: true }      trait pleine largeur (sous la rangée de suggestions)
// Navigation clavier : moveSelection(dx, dy). La grille occupe toute la
// largeur du panneau (les traits vont d'un bord à l'autre) ; les cases sont
// en retrait de `sidePad`.
ListView {
    id: root

    property var items: []
    property int columns: Metrics.gridColumns
    property int selected: 0          // index dans `flat` (éléments seuls)
    property int iconSize: Metrics.gridIcon
    property int sidePad: 20
    // Sans saisie ni navigation clavier, aucune case n'est surlignée (Tahoe)
    property bool showSelection: true

    // Survol actif seulement après un vrai mouvement du pointeur (cf. Spotlight)
    property bool hoverActive: true
    signal activated(var item)
    signal pointed(real sx, real sy)

    readonly property real cellWidth: (width - 2 * sidePad) / columns

    // Éléments seuls, dans l'ordre d'affichage
    readonly property var flat: items.filter(i => !i.header && !i.separator)

    // Lignes : { header, title } | { separator } | { cells: [{ item, flat }] }
    readonly property var rows: {
        const out = [];
        let row = null, n = 0;
        for (const it of items) {
            if (it.header || it.separator) {
                row = null;
                out.push(it.header ? { header: true, title: it.title } : { separator: true });
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

    function rowHeightOf(r) {
        return r.header ? 34 : (r.separator ? 15 : Metrics.gridCellHeight);
    }
    // Hauteur totale des `n` premières lignes (pour dimensionner le panneau)
    function heightOfRows(n) {
        let h = 0;
        for (let i = 0; i < Math.min(n, rows.length); i++) h += rowHeightOf(rows[i]);
        return h;
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
            while (t >= 0 && t < rows.length && !rows[t].cells) t += dy;
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
        height: root.rowHeightOf(modelData)

        // En-tête de section
        Text {
            visible: !!rowItem.modelData.header
            x: root.sidePad + 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: rowItem.modelData.title ?? ""
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: Theme.labelSecondary
        }

        // Trait pleine largeur
        Rectangle {
            visible: !!rowItem.modelData.separator
            y: 5
            width: parent.width
            height: 1
            color: Theme.separator
        }

        Row {
            x: root.sidePad
            visible: !!rowItem.modelData.cells
            Repeater {
                model: rowItem.modelData.cells ?? []
                delegate: Item {
                    id: cell
                    required property var modelData
                    readonly property bool isSel: root.showSelection && modelData.flat === root.selected
                    width: root.cellWidth
                    height: Metrics.gridCellHeight

                    // Sélection clavier / survol : plaque arrondie derrière l'icône et le nom
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 2
                        width: parent.width - 8
                        height: parent.height - 4
                        radius: 16
                        color: cell.isSel ? Theme.fillHover : (cellMouse.containsMouse && root.hoverActive ? Theme.fill : "transparent")
                        Behavior on color { ColorAnimation { duration: 90 } }
                    }
                    ItemIcon {
                        id: ic
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 10
                        size: root.iconSize
                        item: cell.modelData.item
                        scale: cellMouse.pressed ? 0.92 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                    }
                    Text {
                        anchors.top: ic.bottom
                        anchors.topMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.item.title ?? ""
                        textFormat: Text.PlainText
                        // Tahoe : une seule ligne, tronquée par « … »
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: Metrics.gridLabelSize
                        color: Theme.label
                    }
                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: mouse => {
                            const p = mapToItem(null, mouse.x, mouse.y);
                            root.pointed(p.x, p.y);
                        }
                        onClicked: { root.selected = cell.modelData.flat; root.activated(cell.modelData.item); }
                    }
                }
            }
        }
    }
}
