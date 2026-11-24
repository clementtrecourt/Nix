import QtQuick
import Quickshell
import qs.common
import qs.services

// Menu contextuel du Dock (clic droit / appui long), ouvert au-dessus de l'icône.
// Contenu et libellés de macOS Tahoe (anglais US) :
//   app ouverte  : fenêtres (✓ active, ◆ minimisée) — Options ▸ — Show All
//                  Windows, Hide, Quit
//   app fermée   : Options ▸ — Open
//   Options ▸    : Keep in Dock, Open at Login, Show in Finder
//   Trash        : Open — Empty Trash ; Downloads : Open "Downloads"
// Les deux fenêtres (menu, sous-menu « Options ») sont en Liquid Glass : chacune
// réfracte une capture de l'écran prise juste avant son apparition.
Scope {
    id: root

    required property var dockWindow
    required property var dock
    readonly property var model: dock.model

    property bool open: false
    property var tile: null
    property var entries: []
    property var subEntries: []
    property bool subOpen: false
    property real anchorX: 0
    // Saisie xdg_popup : le compositeur ferme le menu au clic extérieur. Exige un
    // événement d'entrée récent (clic) : désactivée pour l'ouverture par IPC.
    property bool grab: true

    readonly property var screen: dockWindow.screen
    readonly property real screenW: screen?.width ?? 0
    readonly property real screenH: screen?.height ?? 0

    function openFor(t) {
        if (open) close();
        tile = t;
        if (t.isApp && t.appId && t.appId !== model.appsTileId) model.refreshAutostart(t.appId);
        entries = build(t);
        subEntries = [];
        subOpen = false;
        panel.highlighted = -1;
        anchorX = t.x + t.width / 2;
        popup.anchor.updateAnchor();
        open = true;
    }
    function close() {
        open = false;
        grab = true;
        subOpen = false;
    }

    function optionsFor(t) {
        const id = t.appId;
        const pinned = model.isPinned(id);
        // Finder : toujours dans le Dock, pas de « Keep in Dock »
        const o = model.isFinder(id) ? [] : [{ text: "Keep in Dock", checked: pinned, action: () => model.setPinned(id, !pinned) }];
        if (id === model.appsTileId) return o;
        o.push({ text: "Open at Login", checked: !!model.autostart[id], action: () => model.setAutostart(id, !model.autostart[id]) });
        o.push({ text: "Show in Finder", action: () => model.showInFinder(id) });
        return o;
    }

    function build(t) {
        const e = [];
        if (t.kind === "app") {
            if (t.appId === model.appsTileId) {
                e.push({ text: "Options", submenu: optionsFor(t) });
                e.push({ separator: true });
                e.push({ text: "Open", action: () => ShellState.toggle("apps") });
                return e;
            }
            const ws = t.windows;
            if (ws.length > 0) {
                for (const w of ws) {
                    e.push({
                        text: w.title || model.displayName(t.appId, t.cls),
                        checked: w === Windows.activeToplevel,
                        minimized: Windows.isMinimized(w),
                        action: () => Windows.focus(w)
                    });
                }
                e.push({ separator: true });
            }
            if (model.isFinder(t.appId)) {
                // Menu du Finder : nouvelle fenêtre (pas de « Keep in Dock » ni « Quit »)
                e.push({ text: "New Finder Window", action: () => model.finderOpen(Quickshell.env("HOME"), 'exec nemo "$1"') });
                e.push({ separator: true });
            } else {
                e.push({ text: "Options", submenu: optionsFor(t) });
                e.push({ separator: true });
            }
            if (ws.length > 0) {
                e.push({ text: "Show All Windows", action: () => {
                    // L'Exposé d'application montre l'app au premier plan : on
                    // l'active d'abord (exposeClass sert si Mission Control le lit).
                    const vis = ws.filter(w => !Windows.isMinimized(w) && !model.isHidden(w));
                    if (vis.length > 0 && Windows.activeClass.toLowerCase() !== t.cls.toLowerCase()) Windows.focus(vis[0]);
                    ShellState.exposeClass = t.cls;
                    ShellState.open("appexpose");
                } });
                e.push({ text: "Hide", action: () => model.hide(t.cls) });
                // Le Finder ne se quitte pas (comme macOS)
                if (!model.isFinder(t.appId)) e.push({ text: "Quit", action: () => Windows.quitApp(t.cls) });
            } else if (!model.isFinder(t.appId)) {
                e.push({ text: "Open", action: () => model.launch(t.appId) });
            }
            while (e.length && e[e.length - 1].separator) e.pop();
        } else if (t.kind === "window") {
            // Fenêtre minimisée : menu de son app (macOS affiche celui de l'app)
            const w = t.toplevel;
            e.push({ text: w?.title || model.displayName(t.appId, t.cls), action: () => root.dock.activateTile(t) });
            e.push({ separator: true });
            e.push({ text: "Close", action: () => w && Windows.close(w) });
        } else if (t.kind === "folder") {
            e.push({ text: "Open “Downloads”", action: () => model.openPath(model.downloadsDir) });
        } else if (t.kind === "trash") {
            e.push({ text: "Open", action: () => model.openTrash() });
            e.push({ separator: true });
            e.push({ text: "Empty Trash", enabled: root.dock.trashFull, action: () => model.emptyTrash() });
        }
        return e;
    }

    function run(entry) {
        if (!entry || entry.submenu) return;
        close();
        if (entry.action) entry.action();
    }

    // ---- Position des fenêtres sur l'écran (repère de la capture du verre) ----
    // Le Dock est ancré en bas : son origine est (0, hauteur écran - sa hauteur).
    // Le menu est centré sur l'icône, bas sur le point d'ancrage, et glissé
    // horizontalement dans l'écran (PopupAdjustment.Slide), comme le compositeur.
    readonly property real dockY: screenH - dockWindow.height
    readonly property real popupX: Math.max(0, Math.min(screenW - panel.implicitWidth,
                                                       Math.round(anchorX + 0.5 - panel.implicitWidth / 2)))
    readonly property real popupY: dockY + popup.anchor.rect.y - panel.implicitHeight
    // Sous-menu : à droite du menu, à gauche s'il n'y a pas la place
    readonly property bool subLeft: popupX + panel.margin + panel.contentW + subPanel.contentW + 4 > screenW
    property real subRowY: 0

    PopupWindow {
        id: popup
        // Visible dès que la capture du fond est arrivée (~50 ms)
        visible: menuBackdrop.pass
        color: "transparent"
        grabFocus: root.grab
        anchor.window: root.dockWindow
        anchor.rect.x: root.anchorX
        anchor.rect.y: root.dock.platterTop - 6 + panel.margin
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.adjustment: PopupAdjustment.Slide
        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight
        mask: Region { item: panel.plateItem }
        // Fermé par le compositeur (clic hors du menu) : on suit
        onVisibleChanged: if (!visible && root.open) root.close()

        property Item glassBackdrop: menuBackdrop
        GlassBackdrop {
            id: menuBackdrop
            mode: "snapshot"
            screen: root.screen
            want: root.open
            origin: Qt.point(root.popupX, root.popupY)
        }

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
                    root.subRowY = item.mapToItem(panel, 0, 0).y;
                    sub.anchor.updateAnchor();
                    root.subOpen = true;
                } else {
                    root.subOpen = false;
                }
            }
        }
    }

    // Sous-menu « Options »
    PopupWindow {
        id: sub
        visible: subBackdrop.pass && root.open
        color: "transparent"
        anchor.window: popup
        // Le bord de la plaque du sous-menu touche celui du menu, sa première
        // ligne alignée sur la ligne « Options ».
        anchor.rect.x: root.subLeft ? panel.margin - subPanel.contentW - subPanel.margin
                                    : panel.margin + panel.contentW - subPanel.margin
        anchor.rect.y: root.subRowY - subPanel.margin - subPanel.padding
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.None
        implicitWidth: subPanel.implicitWidth
        implicitHeight: subPanel.implicitHeight
        mask: Region { item: subPanel.plateItem }

        property Item glassBackdrop: subBackdrop
        GlassBackdrop {
            id: subBackdrop
            mode: "snapshot"
            screen: root.screen
            want: root.open && root.subOpen
            origin: Qt.point(root.popupX + sub.anchor.rect.x, root.popupY + sub.anchor.rect.y)
        }

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
