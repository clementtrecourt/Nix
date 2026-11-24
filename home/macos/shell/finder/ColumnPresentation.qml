import QtQuick
import qs.common

// Présentation Colonnes (Miller) : une colonne par niveau à partir du dossier
// de la fenêtre ; choisir un dossier ouvre la colonne suivante, choisir un
// fichier affiche la colonne d'aperçu (grande vignette, nom, type, dates).
// Lignes de 22 pt, chevron des dossiers à droite, pastille d'accent dans la
// colonne active, grise dans les colonnes parentes (captures 2x de Daring
// Fireball et MacRumors, Tahoe 26.2).
Item {
    id: root

    required property var fw
    // Décalage des colonnes (place de la barre latérale, sous laquelle elles défilent)
    property real lead: 0

    readonly property real colW: 240
    readonly property real topY: fw.chromeHeight + 2
    // Chaîne des dossiers affichés (le premier = dossier de la fenêtre)
    property var chain: [fw.path]
    // Élément choisi dans chaque colonne (chemin)
    property var picks: []
    // Colonne active (clavier)
    property int activeCol: 0
    // Contenu trié de chaque colonne (rempli par les DirLister)
    property var lists: ({})
    readonly property var preview: {
        const last = picks[chain.length - 1];
        if (!last) return null;
        const e = entriesOf(chain.length - 1).find(x => x.path === last);
        return e && !e.isDir ? e : null;
    }
    // Pour la sélection de la fenêtre : la colonne active
    readonly property var flatRows: entriesOf(activeCol)

    function rootChanged() { chain = [fw.path]; picks = []; activeCol = 0; flick.contentX = -lead; }
    Component.onCompleted: flick.contentX = -lead
    Connections {
        target: root.fw
        function onPathChanged() { root.rootChanged(); }
        function onSelMapChanged() { root.syncFromSelection(); }
    }
    // Sélection faite ailleurs (⌘A, saisie rapide…) : suit la colonne active
    function syncFromSelection() {
        const s = fw.selectedPaths;
        if (s.length !== 1) return;
        const p = s[0];
        const dir = Fs.dirname(p);
        const i = chain.indexOf(dir);
        if (i < 0 || picks[i] === p) return;
        pick(i, p, false);
    }
    function entriesOf(i) { return i === 0 ? fw.items : fw._sorted((lists[chain[i]] ?? []).filter(x => fw.showHidden || !x.hidden), fw.sortKey, fw.sortAsc, ""); }

    // Choisit `p` dans la colonne i (ouvre la colonne suivante si dossier)
    function pick(i, p, select) {
        const c = chain.slice(0, i + 1);
        const pk = picks.slice(0, i);
        pk[i] = p;
        const e = entriesOf(i).find(x => x.path === p);
        if (e && e.isDir && !e.app && !Fs.isVirtual(e.path)) c.push(e.path);
        chain = c;
        picks = pk;
        activeCol = i;
        if (select !== false) fw.selectPaths([p], false);
        Qt.callLater(() => flick.contentX = Math.max(-root.lead, flick.contentWidth - flick.width));
    }
    function ensureVisible(p) {}
    function navigate(k, extend) {
        const i = activeCol;
        const list = entriesOf(i);
        let idx = list.findIndex(x => x.path === picks[i]);
        if (k === Qt.Key_Up || k === Qt.Key_Down || k === Qt.Key_Home || k === Qt.Key_End) {
            if (!list.length) return;
            if (k === Qt.Key_Up) idx = idx < 0 ? list.length - 1 : Math.max(0, idx - 1);
            else if (k === Qt.Key_Down) idx = idx < 0 ? 0 : Math.min(list.length - 1, idx + 1);
            else if (k === Qt.Key_Home) idx = 0;
            else idx = list.length - 1;
            pick(i, list[idx].path);
            const lv = colRep.itemAt(i)?.view;
            if (lv) lv.positionViewAtIndex(idx, ListView.Contain);
        } else if (k === Qt.Key_Right) {
            const sub = entriesOf(i + 1);
            if (chain.length > i + 1 && sub.length) pick(i + 1, sub[0].path);
        } else if (k === Qt.Key_Left) {
            if (i > 0) pick(i - 1, picks[i - 1]);
        }
    }

    Repeater {
        model: root.chain
        DirLister {
            required property string modelData
            required property int index
            path: index === 0 ? "" : modelData   // colonne 0 : lister de la fenêtre
            showHidden: root.fw.showHidden
            onLoaded: {
                const l = Object.assign({}, root.lists);
                l[modelData] = entries;
                root.lists = l;
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        leftMargin: root.lead
        contentWidth: Math.max(width - root.lead, colsRow.width + (root.preview ? 250 : 0))
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        acceptedButtons: Qt.NoButton
        boundsBehavior: Flickable.StopAtBounds
        clip: false

        Row {
            id: colsRow
            height: flick.height
            Repeater {
                id: colRep
                model: root.chain
                Item {
                    id: col
                    required property string modelData
                    required property int index
                    readonly property var entries: root.entriesOf(index)
                    property alias view: lv
                    width: root.colW
                    height: colsRow.height

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPressed: (m) => {
                            root.fw.focusStage();
                            root.activeCol = col.index;
                            // Clic dans le vide : remonte la sélection à cette colonne
                            root.chain = root.chain.slice(0, col.index + 1);
                            root.picks = root.picks.slice(0, col.index);
                            root.fw.clearSelection();
                            if (m.button === Qt.RightButton) root.fw.finder.contextMenu(root.fw, mapToItem(null, m.x, m.y));
                        }
                    }
                    DropArea {
                        anchors.fill: parent
                        keys: ["text/uri-list"]
                        onDropped: (d) => {
                            const ps = root.fw.dropPaths(d).filter(p => Fs.dirname(p) !== col.modelData);
                            if (ps.length) root.fw.dropInto(col.modelData, ps, d.proposedAction === Qt.CopyAction);
                            d.acceptProposedAction();
                        }
                    }

                    ListView {
                        id: lv
                        anchors.fill: parent
                        topMargin: root.topY + 2
                        bottomMargin: 8
                        model: col.entries
                        acceptedButtons: Qt.NoButton
                        boundsBehavior: Flickable.StopAtBounds
                        reuseItems: true

                        delegate: Item {
                            id: row
                            required property var modelData
                            readonly property var e: modelData
                            readonly property bool picked: root.picks[col.index] === e.path
                            readonly property bool activeSel: picked && col.index === root.activeCol && root.fw.isSel(e.path)
                            readonly property bool multi: col.index === root.activeCol && root.fw.isSel(e.path)
                            readonly property bool renaming: root.fw.renamingPath === e.path
                            width: lv.width
                            height: FStyle.columnRow

                            Rectangle {
                                x: 6
                                width: parent.width - 12
                                height: parent.height
                                radius: 6
                                visible: row.picked || row.multi || drop.containsDrag
                                color: (row.activeSel || row.multi || drop.containsDrag) && root.fw.active ? FStyle.selection : FStyle.selectionInactive
                            }
                            FileIcon {
                                id: icon
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                size: 16
                                entry: row.e
                                dimmed: row.e.hidden
                            }
                            Text {
                                visible: !row.renaming
                                x: 36
                                width: parent.width - x - 26
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.e.name
                                elide: Text.ElideMiddle
                                font.family: Theme.font
                                font.pixelSize: 13
                                color: (row.activeSel || row.multi) && root.fw.active ? "white" : Theme.label
                            }
                            Loader {
                                active: row.renaming
                                x: 32
                                anchors.verticalCenter: parent.verticalCenter
                                sourceComponent: RenameField { fw: root.fw; entry: row.e; maxWidth: root.colW - 50 }
                            }
                            Symbol {
                                visible: row.e.isDir && !row.e.app
                                name: "chevron.right"
                                size: 9
                                x: parent.width - 22
                                anchors.verticalCenter: parent.verticalCenter
                                color: (row.activeSel || row.multi) && root.fw.active ? "white" : FStyle.secondaryText
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                property point pressPos
                                property bool dragged: false
                                property bool wasAlone: false
                                onPressed: (m) => {
                                    root.fw.focusStage();
                                    pressPos = Qt.point(m.x, m.y);
                                    dragged = false;
                                    wasAlone = row.activeSel && root.fw.selectedPaths.length === 1;
                                    root.activeCol = col.index;
                                    if (m.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.MetaModifier)) {
                                        root.fw.clickItem(row.e, m.modifiers, col.entries);
                                        return;
                                    }
                                    if (!root.fw.isSel(row.e.path) || root.fw.selectedPaths.length === 1) root.pick(col.index, row.e.path);
                                    if (m.button === Qt.RightButton) root.fw.finder.contextMenu(root.fw, mapToItem(null, m.x, m.y));
                                }
                                onPositionChanged: (m) => {
                                    if (pressed && !dragged && (m.buttons & Qt.LeftButton) && Math.hypot(m.x - pressPos.x, m.y - pressPos.y) > 5) {
                                        dragged = true;
                                        root.fw.beginDrag(icon);
                                    }
                                }
                                onReleased: (m) => { if (!dragged && wasAlone && m.button === Qt.LeftButton && m.x > 36) root.fw.releaseItem(row.e, m.modifiers, true); }
                                onDoubleClicked: (m) => {
                                    root.fw.cancelSlowRename();
                                    if (row.e.isDir && !row.e.app) root.fw.navigate(row.e.path);
                                    else root.fw.openEntry(row.e);
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
                    OverlayScrollbar {
                        flick: lv
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        startMargin: root.topY
                        endMargin: 4
                    }
                    // Séparateur de colonnes
                    Rectangle {
                        x: parent.width - 1
                        y: root.topY
                        width: 1
                        height: parent.height - root.topY
                        color: FStyle.gridLine
                    }
                }
            }
        }

        // ---- Colonne d'aperçu (fichier choisi) ----
        Item {
            visible: !!root.preview
            x: colsRow.width
            width: Math.max(250, flick.width - root.lead - colsRow.width)
            height: flick.height
            PreviewPane {
                anchors.fill: parent
                anchors.topMargin: root.topY + 16
                entry: root.preview
                compact: true
            }
        }
    }

    OverlayScrollbar {
        flick: flick
        horizontal: true
        anchors.left: parent.left
        anchors.leftMargin: root.lead
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }

    WheelHandler {
        // Molette horizontale (ou Maj+molette) : défilement des colonnes
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        acceptedModifiers: Qt.ShiftModifier
        onWheel: (ev) => flick.contentX = Math.max(-root.lead, Math.min(flick.contentWidth - flick.width, flick.contentX - ev.angleDelta.y / 2))
    }
}
