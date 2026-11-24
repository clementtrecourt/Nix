import QtQuick
import qs.common

// Présentation Liste : en-tête de colonnes (Name, Date Modified, Size, Kind ;
// tri au clic, chevron sur la colonne triée, largeurs ajustables), lignes de
// 20 pt en pastilles alternées (qui continuent sous la dernière ligne),
// triangles de dépliage des dossiers (sous-éléments indentés de 18 pt),
// sélection en pastille d'accent. Le haut est « dur » : bande opaque sous la
// barre d'outils et l'en-tête (capture MacStories « The Finder in list view »).
Item {
    id: root

    required property var fw

    readonly property real headerY: fw.chromeHeight - 2
    readonly property real rowsTop: headerY + FStyle.listHeader + 8
    readonly property real inset: 9

    // ---- Colonnes ----
    property real dateW: 180
    property real sizeW: 80
    property real kindW: 150
    readonly property real nameW: Math.max(140, width - 2 * inset - dateW - sizeW - kindW)
    readonly property var cols: [
        { key: "name", title: "Name", x: inset, w: nameW },
        { key: "date", title: "Date Modified", x: inset + nameW, w: dateW },
        { key: "size", title: "Size", x: inset + nameW + dateW, w: sizeW, right: true },
        { key: "kind", title: "Kind", x: inset + nameW + dateW + sizeW, w: kindW }
    ]

    // ---- Dossiers dépliés : { chemin: true } et leurs contenus ----
    property var expanded: ({})
    property var childLists: ({})
    readonly property var expandedList: Object.keys(expanded).filter(k => expanded[k])
    function toggleExpanded(p) {
        const e = Object.assign({}, expanded);
        if (e[p]) {
            // Replie aussi les descendants
            for (const k of Object.keys(e)) if (k === p || k.startsWith(p + "/")) delete e[k];
        } else e[p] = true;
        expanded = e;
    }
    function setExpanded(open, recursive) {
        const sel = fw.selection.filter(x => x.isDir);
        const e = Object.assign({}, expanded);
        for (const s of sel) { if (open) e[s.path] = true; else delete e[s.path]; }
        expanded = e;
    }

    // Lignes à plat : [{ entry, depth }] -> flatRows : entrées (pour la sélection)
    readonly property var rows: {
        const out = [];
        const add = (list, depth) => {
            for (const e of list) {
                out.push({ e: e, depth: depth });
                if (e.isDir && expanded[e.path] && childLists[e.path])
                    add(fw._sorted(childLists[e.path].filter(x => fw.showHidden || !x.hidden), fw.sortKey, fw.sortAsc, ""), depth + 1);
            }
        };
        add(fw.items, 0);
        return out;
    }
    readonly property var flatRows: rows.map(r => r.e)

    Repeater {
        model: root.expandedList
        DirLister {
            required property string modelData
            path: modelData
            onLoaded: {
                const c = Object.assign({}, root.childLists);
                c[path] = entries;
                root.childLists = c;
            }
        }
    }
    Connections {
        target: root.fw
        function onPathChanged() { root.expanded = {}; root.childLists = {}; }
    }

    function indexOf(p) { return flatRows.findIndex(e => e.path === p); }
    function debugScroll(dy) { list.contentY += dy; }
    function ensureVisible(p) {
        const i = indexOf(p);
        if (i >= 0) list.positionViewAtIndex(i, ListView.Contain);
    }
    function navigate(k, extend) {
        const n = flatRows.length;
        if (!n) return;
        let i = indexOf(fw.cursorPath);
        const cur = i >= 0 ? rows[i] : null;
        if (k === Qt.Key_Right) { if (cur && cur.e.isDir && !expanded[cur.e.path]) toggleExpanded(cur.e.path); return; }
        if (k === Qt.Key_Left) {
            if (!cur) return;
            if (cur.e.isDir && expanded[cur.e.path]) { toggleExpanded(cur.e.path); return; }
            if (cur.depth > 0) fw.selectPaths([Fs.dirname(cur.e.path)]);
            return;
        }
        const page = Math.max(1, Math.floor((height - rowsTop) / FStyle.listRow) - 1);
        if (k === Qt.Key_Up) i = i < 0 ? n - 1 : Math.max(0, i - 1);
        else if (k === Qt.Key_Down) i = i < 0 ? 0 : Math.min(n - 1, i + 1);
        else if (k === Qt.Key_Home) i = 0;
        else if (k === Qt.Key_End) i = n - 1;
        else if (k === Qt.Key_PageUp) i = Math.max(0, i - page);
        else if (k === Qt.Key_PageDown) i = Math.min(n - 1, i + page);
        if (extend) fw.clickItem(flatRows[i], Qt.ShiftModifier, flatRows);
        else fw.selectPaths([flatRows[i].path]);
    }

    // ---- Fond : clic, rectangle de sélection, menu ----
    MouseArea {
        anchors.fill: parent
        anchors.topMargin: root.rowsTop
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property real startY: 0
        property real startX: 0
        property var base: ({})
        property bool banding: false
        onPressed: (m) => {
            root.fw.focusStage();
            if (m.button === Qt.RightButton) {
                root.fw.clearSelection();
                root.fw.finder.contextMenu(root.fw, mapToItem(null, m.x, m.y));
                return;
            }
            startX = m.x;
            startY = m.y + list.contentY - list.originY;
            base = (m.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.MetaModifier)) ? Object.assign({}, root.fw.selMap) : {};
            if (!Object.keys(base).length) root.fw.clearSelection();
            banding = true;
        }
        onPositionChanged: (m) => {
            if (!banding) return;
            const y = m.y + list.contentY - list.originY;
            band.r = Qt.rect(Math.min(startX, m.x), Math.min(startY, y), Math.abs(m.x - startX), Math.abs(y - startY));
            const a = Math.floor(band.r.y / FStyle.listRow), b = Math.floor((band.r.y + band.r.height) / FStyle.listRow);
            const sel = Object.assign({}, base);
            for (let i = Math.max(0, a); i <= Math.min(root.flatRows.length - 1, b); ++i) {
                const p = root.flatRows[i].path;
                if (base[p]) delete sel[p]; else sel[p] = true;
            }
            root.fw.selMap = sel;
        }
        onReleased: { banding = false; band.r = Qt.rect(0, 0, 0, 0); }
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

    // Pastilles alternées sous la dernière ligne (remplissage de la vue)
    Item {
        anchors.fill: parent
        anchors.topMargin: root.rowsTop
        clip: true
        Repeater {
            model: Math.ceil(root.height / FStyle.listRow) + 1
            Rectangle {
                required property int index
                readonly property int abs: index + root.rows.length
                visible: abs % 2 === 1 && list.contentHeight - (list.contentY - list.originY) < (index + 1) * FStyle.listRow + list.height
                x: root.inset
                y: list.contentHeight - (list.contentY - list.originY) + index * FStyle.listRow
                width: root.width - 2 * root.inset
                height: FStyle.listRow
                radius: 5
                color: FStyle.stripe
            }
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.topMargin: root.rowsTop
        bottomMargin: 8
        model: root.rows
        acceptedButtons: Qt.NoButton
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        reuseItems: true
        cacheBuffer: 400

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property var e: modelData.e
            readonly property int depth: modelData.depth
            readonly property bool sel: root.fw.isSel(e.path) || (drop.containsDrag && e.isDir)
            readonly property bool renaming: root.fw.renamingPath === e.path
            readonly property color textColor: sel && root.fw.active ? "white" : Theme.label
            readonly property color subColor: sel && root.fw.active ? Qt.rgba(1, 1, 1, 0.85) : FStyle.secondaryText
            width: list.width
            height: FStyle.listRow

            Rectangle {
                x: root.inset
                width: parent.width - 2 * root.inset
                height: parent.height
                radius: 5
                color: row.sel ? (root.fw.active ? FStyle.selection : FStyle.selectionInactive)
                       : (row.index % 2 === 1 ? FStyle.stripe : "transparent")
                // Coins carrés entre deux lignes sélectionnées consécutives
                Rectangle {
                    visible: row.sel && root.fw.isSel(root.flatRows[row.index - 1]?.path ?? "")
                    width: parent.width; height: parent.radius; color: parent.color
                }
                Rectangle {
                    visible: row.sel && root.fw.isSel(root.flatRows[row.index + 1]?.path ?? "")
                    y: parent.height - height
                    width: parent.width; height: parent.radius; color: parent.color
                }
            }

            readonly property real indentX: root.inset + 6 + row.depth * FStyle.listIndent
            // Triangle de dépliage
            Item {
                visible: row.e.isDir && !row.e.app && !Fs.isVirtual(row.e.path)
                x: row.indentX - 1
                width: 14
                height: parent.height
                Symbol {
                    // Triangle un peu plus grand et plus foncé (capture MacStories 2x)
                    x: Math.round((parent.width - width) / 2)
                    y: Math.round((parent.height - height) / 2)
                    name: "chevron.right"
                    size: 10
                    color: row.sel && root.fw.active ? "white" : (Theme.dark ? Qt.rgba(1, 1, 1, 0.65) : Qt.rgba(0, 0, 0, 0.62))
                    rotation: root.expanded[row.e.path] ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: 120 } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.toggleExpanded(row.e.path)
                }
            }
            FileIcon {
                id: icon
                x: row.indentX + 14
                anchors.verticalCenter: parent.verticalCenter
                size: FStyle.listIcon
                entry: row.e
                dimmed: row.e.hidden
            }
            Text {
                id: nameText
                visible: !row.renaming
                x: icon.x + icon.width + 5
                width: root.cols[0].x + root.cols[0].w - x - 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.e.name
                elide: Text.ElideMiddle
                font.family: Theme.font
                font.pixelSize: 13
                color: row.textColor
            }
            Loader {
                active: row.renaming
                x: nameText.x - 4
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: RenameField {
                    fw: root.fw
                    entry: row.e
                    maxWidth: root.cols[0].w - (nameText.x - root.cols[0].x)
                }
            }
            Text {
                x: root.cols[1].x + 6
                width: root.cols[1].w - 12
                anchors.verticalCenter: parent.verticalCenter
                text: row.e.app ? "--" : Fs.formatDate(row.e.mtime)
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 13
                color: row.subColor
            }
            Text {
                x: root.cols[2].x + 6
                width: root.cols[2].w - 12
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: row.e.isDir || row.e.app ? "--" : Fs.formatSize(row.e.size)
                font.family: Theme.font
                font.pixelSize: 13
                color: row.subColor
            }
            Text {
                x: root.cols[3].x + 6
                width: root.cols[3].w - 12
                anchors.verticalCenter: parent.verticalCenter
                text: Fs.kindOf(row.e)
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 13
                color: row.subColor
            }

            MouseArea {
                anchors.fill: parent
                anchors.leftMargin: row.indentX + 14
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property point pressPos
                property bool wasAlone: false
                property bool dragged: false
                onPressed: (m) => {
                    pressPos = Qt.point(m.x, m.y);
                    dragged = false;
                    wasAlone = root.fw.selectedPaths.length === 1 && root.fw.isSel(row.e.path)
                               && m.x + row.indentX + 14 > nameText.x && m.x + row.indentX + 14 < nameText.x + nameText.contentWidth;
                    root.fw.clickItem(row.e, m.modifiers, root.flatRows);
                    if (m.button === Qt.RightButton) root.fw.finder.contextMenu(root.fw, mapToItem(null, m.x, m.y));
                }
                onPositionChanged: (m) => {
                    if (pressed && !dragged && (m.buttons & Qt.LeftButton) && Math.hypot(m.x - pressPos.x, m.y - pressPos.y) > 5) {
                        dragged = true;
                        root.fw.beginDrag(icon);
                    }
                }
                onReleased: (m) => { if (!dragged && m.button === Qt.LeftButton) root.fw.releaseItem(row.e, m.modifiers, wasAlone); }
                onDoubleClicked: (m) => {
                    root.fw.cancelSlowRename();
                    if (m.button === Qt.LeftButton) root.fw.openEntry(row.e, (m.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) !== 0);
                }
            }
            DropArea {
                id: drop
                anchors.fill: parent
                enabled: row.e.isDir && !root.fw.draggingPaths.includes(row.e.path)
                keys: ["text/uri-list"]
                onDropped: (d) => {
                    const ps = root.fw.dropPaths(d).filter(p => p !== row.e.path);
                    if (ps.length) root.fw.dropInto(row.e.path, ps, d.proposedAction === Qt.CopyAction);
                    d.acceptProposedAction();
                }
            }
        }
    }

    Rectangle {
        id: band
        property rect r: Qt.rect(0, 0, 0, 0)
        visible: r.width > 0 || r.height > 0
        x: r.x
        y: root.rowsTop + r.y - (list.contentY - list.originY)
        width: r.width
        height: r.height
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(0, 0, 0, 0.30)
    }

    // ---- Bande du haut (bord « dur ») + en-tête de colonnes ----
    Rectangle {
        width: parent.width
        height: root.headerY + FStyle.listHeader
        color: FStyle.contentBg
    }
    Rectangle {
        y: root.headerY + FStyle.listHeader
        width: parent.width
        height: 1
        color: FStyle.gridLine
    }
    Repeater {
        model: root.cols
        Item {
            id: hc
            required property var modelData
            required property int index
            readonly property bool sorted: root.fw.sortKey === modelData.key
            x: modelData.x
            y: root.headerY
            width: modelData.w
            height: FStyle.listHeader
            // Séparateur à gauche des colonnes (sauf la première)
            Rectangle {
                visible: hc.index > 0
                x: 0
                width: 1
                height: 14
                anchors.verticalCenter: parent.verticalCenter
                color: FStyle.gridLine
            }
            Text {
                x: hc.index === 0 ? 36 : 6
                width: parent.width - x - 22
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: hc.modelData.right ? Text.AlignRight : Text.AlignLeft
                text: hc.modelData.title
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: hc.sorted ? Font.DemiBold : Font.Normal
                color: hc.sorted ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.80)) : FStyle.headerText
            }
            Symbol {
                visible: hc.sorted
                name: root.fw.sortAsc ? "chevron.up" : "chevron.down"
                size: 9
                x: parent.width - 16
                anchors.verticalCenter: parent.verticalCenter
                color: FStyle.headerText
            }
            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: 4
                onClicked: root.fw.sortBy(hc.modelData.key)
            }
            // Redimensionnement (bord droit)
            MouseArea {
                visible: hc.index > 0
                x: -4
                width: 8
                height: parent.height
                cursorShape: Qt.SplitHCursor
                property real sx: 0
                property real sw: 0
                onPressed: (m) => { sx = mapToItem(null, m.x, 0).x; sw = hc.index === 1 ? root.dateW : hc.index === 2 ? root.sizeW : root.kindW; }
                onPositionChanged: (m) => {
                    // Déplacer le bord gauche d'une colonne agrandit la colonne de gauche
                    const d = mapToItem(null, m.x, 0).x - sx;
                    const w = Math.max(50, sw - d);
                    if (hc.index === 1) root.dateW = w; else if (hc.index === 2) root.sizeW = w; else root.kindW = w;
                }
            }
        }
    }

    OverlayScrollbar {
        flick: list
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        startMargin: root.rowsTop
        endMargin: 4
    }
}
