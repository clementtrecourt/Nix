import QtQuick
import Quickshell
import qs.common
import qs.services

// Menu contextuel du Dock (clic droit / appui long), ouvert au-dessus de l'icône.
// Contenu calqué sur macOS :
//   app ouverte  : fenêtres (✓ active, ◆ minimisée) — Options ▸ — Afficher toutes
//                  les fenêtres, Masquer, Quitter
//   app fermée   : Options ▸ — Ouvrir
//   Options ▸    : Garder dans le Dock, Ouvrir à l'ouverture de session,
//                  Afficher dans le Finder
//   Corbeille    : Ouvrir, Vider la corbeille ; Téléchargements : Ouvrir
Scope {
    id: root

    required property var dockWindow
    required property var dock
    readonly property var model: dock.model

    property bool open: false
    property var tile: null
    property var entries: []
    property var subEntries: []
    property real anchorX: 0

    function openFor(t) {
        tile = t;
        if (t.isApp && t.appId && t.appId !== model.appsTileId) model.refreshAutostart(t.appId);
        entries = build(t);
        subEntries = [];
        sub.visible = false;
        panel.highlighted = -1;
        anchorX = t.x + t.width / 2;
        popup.anchor.updateAnchor();
        open = true;
    }
    function close() {
        open = false;
        sub.visible = false;
        subEntries = [];
    }

    function optionsFor(t) {
        const id = t.appId;
        const pinned = model.isPinned(id);
        return [
            { text: "Garder dans le Dock", checked: pinned, action: () => model.setPinned(id, !pinned) },
            { text: "Ouvrir à l'ouverture de session", checked: !!model.autostart[id], action: () => model.setAutostart(id, !model.autostart[id]) },
            { text: "Afficher dans le Finder", action: () => model.showInFinder(id) }
        ];
    }

    function build(t) {
        const e = [];
        if (t.kind === "app") {
            if (t.appId === model.appsTileId) {
                e.push({ text: "Ouvrir", action: () => ShellState.toggle("apps") });
                e.push({ separator: true });
                e.push({ text: "Supprimer du Dock", action: () => model.setPinned(t.appId, false) });
                return e;
            }
            const ws = t.windows;
            if (ws.length > 0) {
                for (const w of ws) {
                    e.push({
                        text: w.title || Apps.name(t.cls),
                        checked: w === Windows.activeToplevel,
                        minimized: Windows.isMinimized(w),
                        action: () => Windows.focus(w)
                    });
                }
                e.push({ separator: true });
            }
            e.push({ text: "Options", submenu: optionsFor(t) });
            e.push({ separator: true });
            if (ws.length > 0) {
                e.push({ text: "Afficher toutes les fenêtres", action: () => { ShellState.exposeClass = t.cls; ShellState.open("appexpose"); } });
                e.push({ text: "Masquer", action: () => model.hide(t.cls) });
                e.push({ text: "Quitter", action: () => Windows.quitApp(t.cls) });
            } else {
                e.push({ text: "Ouvrir", action: () => model.launch(t.appId) });
            }
        } else if (t.kind === "window") {
            const w = t.toplevel;
            e.push({ text: "Restaurer", action: () => root.dock.activateTile(t) });
            e.push({ text: "Fermer", action: () => w && Windows.close(w) });
        } else if (t.kind === "folder") {
            e.push({ text: "Ouvrir « Téléchargements »", action: () => model.openPath(model.downloadsDir) });
        } else if (t.kind === "trash") {
            e.push({ text: "Ouvrir", action: () => model.openTrash() });
            e.push({ separator: true });
            e.push({ text: "Vider la corbeille", enabled: root.dock.trashFull, action: () => model.emptyTrash() });
        }
        return e;
    }

    function run(entry) {
        if (!entry || entry.submenu) return;
        close();
        if (entry.action) entry.action();
    }

    PopupWindow {
        id: popup
        visible: root.open
        color: "transparent"
        grabFocus: true
        anchor.window: root.dockWindow
        anchor.rect.x: root.anchorX
        anchor.rect.y: root.dock.platterTop - 6 + panel.margin
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight
        mask: Region { item: panel.plateItem }
        onVisibleChanged: if (!visible && root.open) root.close()

        DockMenuPanel {
            id: panel
            anchors.fill: parent
            entries: root.entries
            onTriggered: (entry) => root.run(entry)
            onHoveredRow: (i, item) => {
                const e = root.entries[i];
                if (e && e.submenu) {
                    root.subEntries = e.submenu;
                    subPanel.highlighted = -1;
                    sub.anchor.item = item;
                    sub.anchor.updateAnchor();
                    sub.visible = true;
                } else {
                    sub.visible = false;
                }
            }
        }
    }

    // Sous-menu « Options »
    PopupWindow {
        id: sub
        visible: false
        color: "transparent"
        anchor.window: popup
        anchor.edges: Edges.Right | Edges.Top
        anchor.gravity: Edges.Right | Edges.Bottom
        anchor.margins.left: -subPanel.margin + 1
        anchor.margins.top: -subPanel.margin - subPanel.padding
        implicitWidth: subPanel.implicitWidth
        implicitHeight: subPanel.implicitHeight
        mask: Region { item: subPanel.plateItem }

        DockMenuPanel {
            id: subPanel
            anchors.fill: parent
            entries: root.subEntries
            onTriggered: (entry) => root.run(entry)
        }
    }

    // ---- Débogage ----
    function debugHover(row) {
        panel.highlighted = row;
        const it = panel.rowItem(row);
        if (it) panel.hoveredRow(row, it);
    }
    function debugTrigger(row) { panel.flashRow(row); }
}
