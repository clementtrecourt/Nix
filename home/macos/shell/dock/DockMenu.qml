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
    // Saisie xdg_popup : le compositeur ferme le menu au clic extérieur. Exige un
    // événement d'entrée récent (clic) : désactivée pour l'ouverture par IPC.
    property bool grab: true

    function openFor(t) {
        if (open) close();
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
        grab = true;
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
                e.push({ text: "Afficher toutes les fenêtres", action: () => {
                    // L'Exposé d'application montre l'app au premier plan : on
                    // l'active d'abord (exposeClass sert si Mission Control le lit).
                    const vis = ws.filter(w => !Windows.isMinimized(w) && !model.isHidden(w));
                    if (vis.length > 0 && Windows.activeClass.toLowerCase() !== t.cls.toLowerCase()) Windows.focus(vis[0]);
                    ShellState.exposeClass = t.cls;
                    ShellState.open("appexpose");
                } });
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
        grabFocus: root.grab
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
                    sub.rowY = item.mapToItem(panel, 0, 0).y;
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
        // Le bord gauche de la plaque du sous-menu touche le bord droit du menu,
        // sa première ligne alignée sur la ligne « Options ».
        property real rowY: 0
        anchor.rect.x: panel.margin + panel.contentW - subPanel.margin
        anchor.rect.y: rowY - subPanel.margin - subPanel.padding
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
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
    function debugOpen(t) { grab = false; openFor(t); }
    function debugHover(row) {
        panel.highlighted = row;
        const it = panel.rowItem(row);
        if (it) panel.hoveredRow(row, it);
    }
    function debugTrigger(row) { panel.flashRow(row); }
}
