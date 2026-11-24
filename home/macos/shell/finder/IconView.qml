import QtQuick
import qs.common

// Présentation Icônes : grille d'icônes 64 pt (vignettes pour les images),
// libellé 12 pt sur deux lignes au plus sous l'icône. Sélection : fond gris
// arrondi derrière l'icône et pastille d'accent sous le nom (gris si la
// fenêtre n'est pas au premier plan). Rectangle de sélection à la souris,
// déplacement aux flèches dans la grille. Le contenu défile sous la barre
// d'outils (bord « doux »).
Item {
    id: root

    required property var fw
    // Groupes (Grouper par…) : [{ title, items }] ; entries dans l'ordre affiché
    readonly property string groupKey: fw.effectiveGroup
    readonly property bool grouped: groupKey !== ""
    readonly property var groups: grouped ? Fs.groupEntries(fw.items, groupKey) : []
    readonly property var entries: grouped ? [].concat(...groups.map(g => g.items)) : fw.items
    readonly property var flatRows: entries

    readonly property real margin: 10
    readonly property real topPad: fw.chromeHeight + 9
    // Taille des icônes (curseur de la barre d'état) ; la grille suit
    readonly property int iconSize: fw.iconSize
    readonly property real minCellW: Math.max(FStyle.iconCellW, iconSize + 48)
    readonly property int columns: Math.max(1, Math.floor((width - 2 * margin) / minCellW))
    readonly property real cellW: Math.floor((width - 2 * margin) / columns)
    readonly property real cellH: FStyle.iconCellH - root.iconSize + iconSize

    function indexOf(p) { return entries.findIndex(e => e.path === p); }
    function debugScroll(dy) { if (grouped) groupFlick.contentY += dy; else grid.contentY += dy; }
    function ensureVisible(p) {
        if (grouped) {
            for (let g = 0; g < groups.length; ++g) {
                const i = groups[g].items.findIndex(e => e.path === p);
                const it = groupRep.itemAt(g);
                if (i >= 0 && it) { it.list.positionViewAtIndex(i, ListView.Contain); return; }
            }
            return;
        }
        const i = indexOf(p);
        if (i >= 0) grid.positionViewAtIndex(i, GridView.Contain);
    }
    function navigate(k, extend) {
        const n = entries.length;
        if (!n) return;
        let i = indexOf(fw.cursorPath);
        if (grouped && (k === Qt.Key_Up || k === Qt.Key_Down)) {
            let gi = 0, acc = 0;
            for (; gi < groups.length; ++gi) { if (i < acc + groups[gi].items.length) break; acc += groups[gi].items.length; }
            const tg = i < 0 ? 0 : Math.max(0, Math.min(groups.length - 1, gi + (k === Qt.Key_Down ? 1 : -1)));
            let start = 0;
            for (let g = 0; g < tg; ++g) start += groups[g].items.length;
            const ne = entries[start];
            if (ne) { if (extend) fw.clickItem(ne, Qt.ShiftModifier, entries); else fw.selectPaths([ne.path]); }
            return;
        }
        if (i < 0) i = (k === Qt.Key_Left || k === Qt.Key_Up) ? n : -1;
        if (k === Qt.Key_Left) i = Math.max(0, i - 1);
        else if (k === Qt.Key_Right) i = Math.min(n - 1, i + 1);
        else if (k === Qt.Key_Up) i = i - columns >= 0 ? i - columns : (i >= n ? n - 1 : i);
        else if (k === Qt.Key_Down) i = i < 0 ? 0 : Math.min(n - 1, i + columns);
        else if (k === Qt.Key_Home) i = 0;
        else if (k === Qt.Key_End) i = n - 1;
        else if (k === Qt.Key_PageUp) i = Math.max(0, i - columns * 4);
        else if (k === Qt.Key_PageDown) i = Math.min(n - 1, i + columns * 4);
        const e = entries[i];
        if (extend) fw.clickItem(e, Qt.ShiftModifier, entries);
        else fw.selectPaths([e.path]);
    }
    // Éléments dont l'icône ou le nom touchent le rectangle (repère du contenu)
    function itemsInRect(r) {
        const out = [];
        for (let i = 0; i < entries.length; ++i) {
            const c = i % columns, rr = Math.floor(i / columns);
            const cx = margin + c * cellW + cellW / 2;
            const y0 = rr * cellH;
            const ix = cx - iconSize / 2 - 4, iw = iconSize + 8, iy = y0 + 4, ih = iconSize + 32;
            if (ix < r.x + r.width && ix + iw > r.x && iy < r.y + r.height && iy + ih > r.y) out.push(entries[i].path);
        }
        return out;
    }

    // ---- Fond : clic (désélection), rectangle de sélection, menu ----
    MouseArea {
        id: bg
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property point start
        property var base: ({})
        property bool banding: false
        onPressed: (m) => {
            root.fw.focusStage();
            if (m.button === Qt.RightButton) {
                if (!(m.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.MetaModifier))) root.fw.clearSelection();
                root.fw.finder.contextMenu(root.fw, mapToItem(null, m.x, m.y));
                return;
            }
            start = Qt.point(m.x, m.y + grid.contentY);
            base = (m.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.MetaModifier)) ? Object.assign({}, root.fw.selMap) : {};
            if (!Object.keys(base).length) root.fw.clearSelection();
            banding = !root.grouped;
        }
        onPositionChanged: (m) => {
            if (!banding) return;
            const y = m.y + grid.contentY;
            band.r = Qt.rect(Math.min(start.x, m.x), Math.min(start.y, y), Math.abs(m.x - start.x), Math.abs(y - start.y));
            const hits = root.itemsInRect(band.r);
            const sel = Object.assign({}, base);
            for (const p of hits) { if (base[p]) delete sel[p]; else sel[p] = true; }
            root.fw.selMap = sel;
            // Défilement automatique près des bords
            autoScroll.dir = m.y < root.topPad ? -1 : (m.y > height - 10 ? 1 : 0);
        }
        onReleased: { banding = false; band.r = Qt.rect(0, 0, 0, 0); autoScroll.dir = 0; }
        onDoubleClicked: (m) => {}
        Timer {
            id: autoScroll
            property int dir: 0
            interval: 16
            repeat: true
            running: dir !== 0
            onTriggered: grid.contentY = Math.max(grid.originY - grid.topMargin, Math.min(grid.contentY + dir * 8, grid.contentHeight - grid.height + grid.originY + grid.bottomMargin))
        }
    }

    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        enabled: !root.fw.isVirtual
        onDropped: (d) => {
            const ps = root.fw.dropPaths(d).filter(p => Fs.dirname(p) !== root.fw.path);
            if (ps.length) root.fw.dropInto(root.fw.path, ps, d.proposedAction === Qt.CopyAction);
            d.acceptProposedAction();
        }
    }

    GridView {
        id: grid
        anchors.fill: parent
        leftMargin: root.margin
        rightMargin: root.margin
        topMargin: root.topPad
        bottomMargin: 12
        cellWidth: root.cellW
        cellHeight: root.cellH
        model: root.entries
        acceptedButtons: Qt.NoButton
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        cacheBuffer: 400
        visible: !root.grouped
        interactive: !root.grouped
        delegate: cellComp
    }

    // Cellule (grille ou rangée d'un groupe)
    Component {
        id: cellComp
        Item {
            id: cell
            required property var modelData
            required property int index
            readonly property var e: modelData
            readonly property bool sel: root.fw.isSel(e.path) || (drop.containsDrag && e.isDir)
            readonly property bool renaming: root.fw.renamingPath === e.path
            width: GridView.view ? root.cellW : root.minCellW
            height: root.cellH
            // Le champ de renommage déborde sur la rangée suivante : au-dessus
            z: renaming ? 100 : 0

            // Fond gris arrondi derrière l'icône choisie
            Rectangle {
                visible: cell.sel
                x: (parent.width - width) / 2
                y: icon.y - 4
                width: Math.max(icon.paintedW, 44) + 10
                height: root.iconSize + 8
                radius: 7
                color: FStyle.selectionIcon
            }
            FileIcon {
                id: icon
                x: Math.round((parent.width - root.iconSize) / 2)
                y: 6
                size: root.iconSize
                entry: cell.e
                dimmed: cell.e.hidden || root.fw.draggingPaths.includes(cell.e.path)
            }
            // Pastilles des tags (avant le nom)
            Row {
                id: tagDots
                readonly property var t: Fs.tagsOf(cell.e.path)
                visible: t.length > 0 && !cell.renaming
                spacing: -3
                anchors.right: label.left
                anchors.rightMargin: 3
                y: label.y + 4
                Repeater {
                    model: tagDots.t
                    Rectangle {
                        required property string modelData
                        width: 8; height: 8; radius: 4
                        color: Fs.tagColor(modelData)
                        border.width: 1
                        border.color: FStyle.contentBg
                    }
                }
            }
            // Nom : coupé aux mots, 2e ligne tronquée au milieu ; pastille
            // d'accent si choisi
            IconLabel {
                id: label
                visible: !cell.renaming
                x: Math.round((parent.width - width) / 2)
                y: icon.y + root.iconSize + 6
                name: cell.e.name
                selected: cell.sel
                active: root.fw.active
            }
            Loader {
                active: cell.renaming
                x: Math.round((parent.width - width) / 2)
                y: icon.y + root.iconSize + 5
                sourceComponent: RenameField {
                    fw: root.fw
                    entry: cell.e
                    centered: true
                    fontSize: FStyle.iconText
                    maxWidth: FStyle.iconTextW + 16
                }
            }

            MouseArea {
                id: ma
                x: (parent.width - width) / 2
                width: Math.max(root.iconSize + 10, label.width)
                height: label.y + label.height
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property point pressPos
                property bool wasAlone: false
                property bool dragged: false
                onPressed: (m) => {
                    pressPos = Qt.point(m.x, m.y);
                    dragged = false;
                    wasAlone = root.fw.selectedPaths.length === 1 && root.fw.isSel(cell.e.path) && m.y > label.y;
                    root.fw.clickItem(cell.e, m.modifiers, root.entries);
                    if (m.button === Qt.RightButton) root.fw.finder.contextMenu(root.fw, mapToItem(null, m.x, m.y));
                }
                onPositionChanged: (m) => {
                    if (pressed && !dragged && m.buttons & Qt.LeftButton && Math.hypot(m.x - pressPos.x, m.y - pressPos.y) > 5) {
                        dragged = true;
                        root.fw.beginDrag(icon);
                    }
                }
                onReleased: (m) => { if (!dragged && m.button === Qt.LeftButton) root.fw.releaseItem(cell.e, m.modifiers, wasAlone); }
                onDoubleClicked: (m) => {
                    root.fw.cancelSlowRename();
                    if (m.button === Qt.LeftButton) root.fw.openEntry(cell.e, (m.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) !== 0);
                }
            }
            DropArea {
                id: drop
                anchors.fill: ma
                enabled: cell.e.isDir && !root.fw.draggingPaths.includes(cell.e.path)
                keys: ["text/uri-list"]
                onDropped: (d) => {
                    const ps = root.fw.dropPaths(d).filter(p => p !== cell.e.path);
                    if (ps.length) root.fw.dropInto(cell.e.path, ps, d.proposedAction === Qt.CopyAction);
                    d.acceptProposedAction();
                }
            }
        }
    }

    // ---- Présentation groupée (Grouper par…, Récents : Date Last Opened) ----
    // Un groupe par rangée horizontale défilante, titre en tête (Tahoe)
    Flickable {
        id: groupFlick
        visible: root.grouped
        anchors.fill: parent
        topMargin: root.topPad - 4
        bottomMargin: 12
        contentHeight: groupCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        acceptedButtons: Qt.NoButton
        Column {
            id: groupCol
            width: groupFlick.width
            Repeater {
                id: groupRep
                model: root.grouped ? root.groups : []
                Item {
                    id: grp
                    required property var modelData
                    required property int index
                    property alias list: glv
                    width: groupCol.width
                    height: 30 + root.cellH + 8
                    Text {
                        x: root.margin + 10
                        y: 8
                        text: grp.modelData.title
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Theme.label
                    }
                    Text {
                        visible: glv.contentWidth > glv.width
                        anchors.right: parent.right
                        anchors.rightMargin: root.margin + 10
                        y: 9
                        text: "Show All (" + grp.modelData.items.length + ")"
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: FStyle.secondaryText
                    }
                    Rectangle {
                        visible: grp.index > 0
                        x: root.margin + 10
                        width: parent.width - 2 * x
                        height: 1
                        color: FStyle.gridLine
                    }
                    ListView {
                        id: glv
                        y: 30
                        width: parent.width
                        height: root.cellH
                        orientation: ListView.Horizontal
                        leftMargin: root.margin
                        rightMargin: root.margin
                        model: grp.modelData.items
                        acceptedButtons: Qt.NoButton
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        delegate: cellComp
                    }
                    OverlayScrollbar {
                        flick: glv
                        horizontal: true
                        y: glv.y + glv.height - 10
                        width: parent.width
                    }
                }
            }
        }
    }

    // Rectangle de sélection
    Rectangle {
        id: band
        property rect r: Qt.rect(0, 0, 0, 0)
        visible: r.width > 0 || r.height > 0
        x: r.x
        y: r.y - grid.contentY
        width: r.width
        height: r.height
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(0, 0, 0, 0.30)
    }

    OverlayScrollbar {
        flick: grid
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        startMargin: root.topPad
        endMargin: 4
    }

    // Dossier vide / inaccessible
    Text {
        visible: root.fw.lister.ok === false
        anchors.centerIn: parent
        text: "The folder “" + Fs.displayName(root.fw.path) + "” can’t be opened."
        font.family: Theme.font
        font.pixelSize: 13
        color: FStyle.secondaryText
    }
}
