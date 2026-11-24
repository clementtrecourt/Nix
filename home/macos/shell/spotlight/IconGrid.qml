import QtQuick
import qs.common

// Grille d'icônes de la vue Applications / Fichiers (Tahoe) : 5 colonnes,
// icônes (dessin de 60 pt) avec leur nom dessous. Lignes spéciales :
//   { header: true, title }  en-tête de section (vue Fichiers : « Suggestions »,
//                            « Recents » : 15 pt gras, couleur du texte)
//   { separator: true }      trait sous la rangée de suggestions : pleine
//                            largeur (Applications), en retrait de 19 pt avant
//                            un en-tête (Fichiers, Cult of Mac « Spotlight-Files »)
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
    // Noms sur une ligne (Applications) ou deux (Fichiers, « Superguide / Template »)
    property int labelLines: 1
    property int cellHeight: Metrics.gridCellHeight
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
                if (it.header && out.length && out[out.length - 1].separator) out[out.length - 1].beforeHeader = true;
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
        // En-tête : texte centré à 20 pt ; trait à 10 pt sous la rangée
        return r.header ? 36 : (r.separator ? (r.beforeHeader ? 11 : 21) : cellHeight);
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

        // En-tête de section, aligné sur les pastilles (19 pt)
        Text {
            visible: !!rowItem.modelData.header
            x: Metrics.sidePad
            y: Math.round(20 - height / 2)
            text: rowItem.modelData.title ?? ""
            font.family: Theme.font
            font.pixelSize: 15
            font.weight: Font.Bold
            color: Theme.label
        }

        // Trait (pleine largeur, ou en retrait avant un en-tête)
        Rectangle {
            visible: !!rowItem.modelData.separator
            readonly property int inset: rowItem.modelData.beforeHeader ? Metrics.sidePad : 0
            x: inset
            y: 10
            width: parent.width - 2 * inset
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
                    height: root.cellHeight

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
                        y: 7
                        size: root.iconSize
                        item: cell.modelData.item
                        scale: cellMouse.pressed ? 0.92 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                    }
                    Text {
                        anchors.top: ic.bottom
                        anchors.topMargin: 5
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.item.title ?? ""
                        textFormat: Text.PlainText
                        // Applications : une ligne ; Fichiers : deux, puis « … »
                        maximumLineCount: root.labelLines
                        wrapMode: root.labelLines > 1 ? Text.Wrap : Text.NoWrap
                        elide: Text.ElideRight
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 18
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
