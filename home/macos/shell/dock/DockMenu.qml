import QtQuick
import Quickshell
import qs.common
import qs.services

// Menu contextuel du Dock (clic droit / appui long), ouvert au-dessus de l'icône.
// Contenu et libellés de macOS Tahoe (anglais US) :
//   app ouverte  : fenêtres (✓ active, ◆ minimisée) — Options ▸ — Show All
//                  Windows, Hide, Quit (Force Quit avec Option)
//   app fermée   : Options ▸ — Open
//   Options ▸    : Keep in Dock (Remove from Dock si fermée), Open at Login,
//                  Show in Finder, « Assign To » (All Desktops, This Desktop, None)
//   Finder       : New Finder Window, New Smart Folder, Find…, Go to Folder…,
//                  Connect to Server… — Options ▸ — Show All Windows, Hide
//   Trash        : Open — Empty Trash
//   Downloads    : Sort by / Display as / View content as — Options ▸ — Open "Downloads"
//   séparateur   : Turn Hiding On/Off, Turn Magnification On/Off — Position on
//                  Screen ▸, Minimize Using ▸ — Dock Settings…
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

    function openFor(t, alt) {
        if (open) close();
        tile = t;
        if (t.isApp && t.appId && t.appId !== model.appsTileId) model.refreshAutostart(t.appId);
        entries = build(t);
        subEntries = [];
        subOpen = false;
        panel.highlighted = -1;
        panel.alt = !!alt;
        subPanel.alt = !!alt;
        anchorX = t.x + t.width / 2;
        popup.anchor.updateAnchor();
        open = true;
    }
    function close() {
        open = false;
        grab = true;
        subOpen = false;
    }

    // Section « Assign To » des Options (All Desktops / This Desktop / None)
    function assignEntries(id) {
        const a = model.assignOf(id);
        return [
            { separator: true },
            { header: true, text: "Assign To" },
            { text: "All Desktops", checked: a === "all", action: () => model.setAssign(id, "all") },
            { text: "This Desktop", checked: a === "this", action: () => model.setAssign(id, "this") },
            { text: "None", checked: a === "none", action: () => model.setAssign(id, "none") }
        ];
    }

    function optionsFor(t) {
        const id = t.appId;
        const pinned = model.isPinned(id);
        // Finder : toujours dans le Dock, ni « Keep in Dock » ni « Open at Login »
        if (model.isFinder(id)) return assignEntries(id).slice(1);
        // App épinglée mais fermée : « Remove from Dock » remplace « Keep in Dock »
        const o = (pinned && !t.running)
            ? [{ text: "Remove from Dock", action: () => model.setPinned(id, false) }]
            : [{ text: "Keep in Dock", checked: pinned, action: () => model.setPinned(id, !pinned) }];
        if (id === model.appsTileId) return o;
        o.push({ text: "Open at Login", checked: !!model.autostart[id], action: () => model.setAutostart(id, !model.autostart[id]) });
        o.push({ text: "Show in Finder", action: () => model.showInFinder(id) });
        // « Assign To » : seulement pour une app ouverte (comme macOS)
        if (t.running) return o.concat(assignEntries(id));
        return o;
    }

    // Menu d'un dossier du Dock (page Apple « Use folders in the Dock on Mac »)
    function folderMenu() {
        const d = root.dock;
        const radio = (cur, v, text, set) => ({ text: text, checked: cur === v, action: () => set(v) });
        const sort = (v) => model.setPref("stackSort", v);
        const disp = (v) => model.setPref("stackDisplay", v);
        const view = (v) => model.setPref("stackView", v);
        return [
            { header: true, text: "Sort by" },
            radio(d.stackSort, "name", "Name", sort),
            radio(d.stackSort, "dateAdded", "Date Added", sort),
            radio(d.stackSort, "dateModified", "Date Modified", sort),
            radio(d.stackSort, "dateCreated", "Date Created", sort),
            radio(d.stackSort, "kind", "Kind", sort),
            { separator: true },
            { header: true, text: "Display as" },
            radio(d.stackDisplay, "folder", "Folder", disp),
            radio(d.stackDisplay, "stack", "Stack", disp),
            { separator: true },
            { header: true, text: "View content as" },
            radio(d.stackView, "fan", "Fan", view),
            radio(d.stackView, "grid", "Grid", view),
            radio(d.stackView, "list", "List", view),
            radio(d.stackView, "auto", "Automatic", view),
            { separator: true },
            { text: "Options", submenu: [
                { text: "Remove from Dock", enabled: false },
                { text: "Show in Finder", action: () => model.finderOpen(model.downloadsDir.replace(/\/[^/]*\/?$/, "") || "/", 'exec xdg-open "$1"') }
            ] },
            { separator: true },
            { text: "Open “Downloads”", action: () => model.openPath(model.downloadsDir) }
        ];
    }

    // Menu du séparateur (réglages rapides du Dock)
    function separatorMenu() {
        const d = root.dock;
        return [
            { text: d.autohide ? "Turn Hiding Off" : "Turn Hiding On", action: () => d.setAutohide(!d.autohide) },
            { text: d.magnification ? "Turn Magnification Off" : "Turn Magnification On", action: () => d.setMagnification(!d.magnification) },
            { separator: true },
            { text: "Position on Screen", submenu: [
                // Dock vertical non pris en charge : Left / Right grisés
                { text: "Left", checked: false, enabled: false },
                { text: "Bottom", checked: true, action: () => {} },
                { text: "Right", checked: false, enabled: false }
            ] },
            { text: "Minimize Using", submenu: [
                { text: "Genie Effect", checked: d.minimizeGenie, action: () => d.setMinimizeEffect("genie") },
                { text: "Scale Effect", checked: !d.minimizeGenie, action: () => d.setMinimizeEffect("scale") }
            ] },
            { separator: true },
            { text: "Dock Settings…", action: () => d.openDockSettings() }
        ];
    }

    function build(t) {
        const e = [];
        if (t.kind === "separator") return separatorMenu();
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
            const finder = model.isFinder(t.appId);
            if (finder) {
                // Menu du Finder (toujours ouvert : ni « Keep in Dock » ni « Quit »)
                const home = Quickshell.env("HOME");
                const win = () => model.finderOpen(home, 'exec nemo "$1"');
                e.push({ text: "New Finder Window", action: win });
                e.push({ text: "New Smart Folder", action: win });
                e.push({ text: "Find…", action: win });
                e.push({ text: "Go to Folder…", action: win });
                e.push({ text: "Connect to Server…", action: win });
                e.push({ separator: true });
            }
            e.push({ text: "Options", submenu: optionsFor(t) });
            e.push({ separator: true });
            const showAll = () => {
                // L'Exposé d'application montre l'app au premier plan : on
                // l'active d'abord (exposeClass sert si Mission Control le lit).
                const vis = ws.filter(w => !Windows.isMinimized(w) && !model.isHidden(w));
                if (vis.length > 0 && Windows.activeClass.toLowerCase() !== t.cls.toLowerCase()) Windows.focus(vis[0]);
                ShellState.exposeClass = t.cls;
                ShellState.open("appexpose");
            };
            if (finder) {
                e.push({ text: "Show All Windows", enabled: ws.length > 0, action: showAll });
                e.push({ text: "Hide", enabled: ws.length > 0, action: () => model.hide(t.cls) });
            } else if (ws.length > 0) {
                e.push({ text: "Show All Windows", action: showAll });
                e.push({ text: "Hide", action: () => model.hide(t.cls) });
                // Option enfoncée : « Force Quit » (documenté par Apple)
                e.push({ text: "Quit", action: () => Windows.quitApp(t.cls),
                         altText: "Force Quit", altAction: () => model.forceQuit(t.cls) });
            } else {
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
            return folderMenu();
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
    function debugOpen(t, alt) { grab = false; openFor(t, alt); }
    function debugHover(row) {
        panel.highlighted = row;
        const it = panel.rowItem(row);
        if (it) panel.hoveredRow(row, it);
    }
    function debugTrigger(row) { panel.flashRow(row); }
}
