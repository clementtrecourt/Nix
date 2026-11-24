import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common
import qs.services

// Finder (macOS Tahoe 26) : fenêtres multiples (FloatingWindow gérées par
// Hyprland), menus, Coup d'œil (Quick Look), Lire les informations, Aller au
// dossier.
//
// IPC : quickshell -c macos ipc call finder open <chemin|URL>   (dossier -> nouvelle
//         fenêtre ; fichier -> fenêtre de son dossier, fichier sélectionné)
//       quickshell -c macos ipc call finder newWindow
// Raccourci global : appid "macos", name "finder" (nouvelle fenêtre / premier plan)
Scope {
    id: root

    // Fenêtres ouvertes : identifiants (Variants crée une FinderWindow par id)
    property var windowIds: []
    property var _starts: ({})
    property int _nextId: 1
    // Dernière fenêtre utilisée (IPC, raccourci)
    property var lastWindow: null

    function newWindow(path, reveal) {
        const id = _nextId++;
        const s = Object.assign({}, _starts);
        s[id] = { path: path || Fs.home, reveal: reveal || "" };
        _starts = s;
        windowIds = windowIds.concat([id]);
    }
    function closeWindow(id) {
        windowIds = windowIds.filter(x => x !== id);
        const s = Object.assign({}, _starts);
        delete s[id];
        _starts = s;
        if (ql.source && ql.source.wid === id) ql.close();
    }
    // Chemin ou URL file:// -> nouvelle fenêtre (dossier) ou dossier parent
    // avec l'élément sélectionné (fichier)
    function openPath(arg) {
        let p = (arg || "").trim();
        if (p.startsWith("file://")) p = decodeURIComponent(p.slice(7));
        if (p.startsWith("~")) p = Fs.home + p.slice(1);
        if (!p) { newWindow(Fs.home); return; }
        probe.target = p;
        probe.command = ["sh", "-c", 'if [ -d "$1" ]; then echo d; elif [ -e "$1" ] || [ -L "$1" ]; then echo f; else echo n; fi', "sh", p];
        probe.running = true;
    }
    ProcessCollector {
        id: probe
        property string target: ""
        onDone: (t) => {
            const k = t.trim();
            if (k === "d") root.newWindow(target);
            else if (k === "f") root.newWindow(Fs.dirname(target), Fs.basename(target));
            else root.newWindow(Fs.home);
        }
    }
    // Raccourci global : premier plan de la dernière fenêtre, sinon nouvelle
    function activate() {
        if (windowIds.length === 0) { newWindow(Fs.home); return; }
        Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "title:^(" + (lastWindow?.title ?? "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + ")$"]);
    }

    Variants {
        id: wins
        model: root.windowIds
        FinderWindow {
            required property var modelData
            finder: root
            wid: modelData
            startPath: root._starts[modelData]?.path ?? Fs.home
            startReveal: root._starts[modelData]?.reveal ?? ""
            onActiveChanged: if (active) root.lastWindow = this
        }
    }

    IpcHandler {
        target: "finder"
        function open(path: string): void { root.openPath(path); }
        function newWindow(): void { root.newWindow(Fs.home); }
        // ---- Débogage (banc de test : pas de clic possible) ----
        function debugSelect(names: string): void { root.lastWindow?.debugSelect(names.split("|")); }
        function debugView(mode: string): void { if (root.lastWindow) root.lastWindow.viewMode = mode; }
        function debugNavigate(path: string): void { root.lastWindow?.navigate(path); }
        function debugMenu(kind: string, x: int, y: int): void {
            const w = root.lastWindow;
            if (!w) return;
            const p = Qt.point(x, y);
            if (kind === "context") root.contextMenu(w, p, true);
            else if (kind === "action") root.actionMenu(w, p, true);
            else if (kind === "group") root.groupMenu(w, p, true);
            else if (kind === "tag") root.tagMenu(w, p, true);
            menu.grab = false;
        }
        function debugQuickLook(): void { if (root.lastWindow) root.toggleQuickLook(root.lastWindow); }
        function debugInfo(): void { const w = root.lastWindow; if (w) for (const s of w.selection) root.getInfo(s); }
        function debugGoTo(): void { if (root.lastWindow) root.goToFolder(root.lastWindow); }
        function debugToggle(what: string): void {
            const w = root.lastWindow;
            if (!w) return;
            if (what === "pathbar") w.showPathBar = !w.showPathBar;
            else if (what === "statusbar") w.showStatusBar = !w.showStatusBar;
            else if (what === "sidebar") w.showSidebar = !w.showSidebar;
            else if (what === "hidden") w.showHidden = !w.showHidden;
            else if (what === "search") w.searching = !w.searching;
            else if (what === "dark") Theme.dark = !Theme.dark;
        }
        function debugKey(key: string): void { root.lastWindow?.debugKey(key); }
        function debugRename(): void { root.lastWindow?.startRename(); }
        function debugExpand(name: string): void { root.lastWindow?.debugExpand(name); }
        function debugSort(key: string): void { root.lastWindow?.sortBy(key); }
        function debugScroll(dy: int): void { root.lastWindow?.debugScroll(dy); }
        function debugState(): string {
            const w = root.lastWindow;
            return w ? JSON.stringify({ path: w.path, back: w.backStack, fwd: w.fwdStack, sel: w.selectedPaths, view: w.viewMode, windows: root.windowIds }) : "none";
        }
        function debugClose(): void { if (root.lastWindow) root.closeWindow(root.lastWindow.wid); }
    }

    GlobalShortcut {
        appid: "macos"
        name: "finder"
        description: "Finder : nouvelle fenêtre / premier plan"
        onPressed: root.activate()
    }

    // ------------------------------------------------------------ menus
    FinderMenu { id: menu }

    // Raccourcis affichés comme sur Mac
    function sc(s) { return s.replace("cmd", "⌘").replace("shift", "⇧").replace("opt", "⌥").replace("ctrl", "⌃"); }

    function quoted(sel) {
        return sel.length === 1 ? "“" + sel[0].name + "”" : sel.length + " Items";
    }
    function itemMenu(w) {
        const sel = w.selection;
        const one = sel.length === 1 ? sel[0] : null;
        const files = sel.filter(e => !e.app && !e.volume);
        const l = [];
        if (w.path === "trash://") {
            l.push({ text: "Put Back", icon: "arrow.uturn.backward", action: () => Fs.restoreFromTrash(files.map(e => e.name)) });
            l.push({ text: "Delete Immediately…", icon: "xmark.bin", action: () => Fs.run(["rm", "-rf", "--"].concat(files.map(e => e.path)), [Fs.trashDir + "/files"]) });
            l.push({ text: "Empty Trash", icon: "trash", action: () => Fs.emptyTrash() });
            l.push({ separator: true });
            l.push({ text: "Get Info", icon: "info.circle", action: () => { for (const s of sel) root.getInfo(s); } });
            l.push({ text: "Quick Look", icon: "eye", action: () => root.toggleQuickLook(w) });
            l.push({ text: "Copy", icon: "doc.on.doc", action: () => w.copySelection() });
            return l;
        }
        l.push({ text: "Open", icon: "arrow.up.forward.app", action: () => w.openSelection(false) });
        if (one && !one.isDir && !one.app) l.push({ text: "Open With", icon: "", submenu: openWith.itemsFor(one), enabled: true });
        if (files.length) {
            l.push({ separator: true });
            l.push({ text: "Move to Trash", icon: "trash", action: () => w.trashSelection() });
        }
        l.push({ separator: true });
        l.push({ text: "Get Info", icon: "info.circle", action: () => { for (const s of sel) root.getInfo(s); } });
        if (one && !w.isVirtual) l.push({ text: "Rename", icon: "pencil", action: () => w.startRename() });
        if (files.length && !w.isVirtual) {
            l.push({ text: "Compress " + quoted(files), icon: "doc.zipper", action: () => w.compressSelection() });
            l.push({ text: "Duplicate", icon: "plus.square.on.square", action: () => w.duplicateSelection() });
            l.push({ text: "Make Alias", icon: "rectangle.dashed", action: () => w.aliasSelection() });
        }
        l.push({ text: "Quick Look", icon: "eye", action: () => root.toggleQuickLook(w) });
        l.push({ separator: true });
        if (files.length) l.push({ text: "Copy", icon: "doc.on.doc", action: () => w.copySelection() });
        l.push({ text: "Share…", icon: "square.and.arrow.up", action: () => root.shareMenu(w, w.lastMenuPos) });
        if (files.length) {
            l.push({ separator: true });
            l.push({ tags: true, isTagged: n => files.every(e => Fs.tagsOf(e.path).includes(n)), toggle: n => Fs.toggleTag(files.map(e => e.path), n) });
            l.push({ text: "Tags…", icon: "tag", action: () => root.tagMenu(w, w.lastMenuPos) });
        }
        if (w.path === "recents://" || w.path.startsWith("tag://") || w.searchText) {
            l.push({ separator: true });
            if (one) l.push({ text: "Show in Enclosing Folder", icon: "folder", action: () => w.navigate(Fs.dirname(one.path), one.name) });
        }
        return l;
    }
    function backgroundMenu(w) {
        const l = [];
        l.push({ text: "New Folder", icon: "folder.badge.plus", enabled: !w.isVirtual, action: () => w.newFolder() });
        l.push({ separator: true });
        l.push({ text: "Get Info", icon: "info.circle", action: () => root.getInfo(w.currentFolderEntry()) });
        if (Fs.clipboard.length && !w.isVirtual)
            l.push({ text: Fs.clipboard.length === 1 ? "Paste Item" : "Paste " + Fs.clipboard.length + " Items", icon: "doc.on.clipboard", action: () => w.paste(false) });
        if (w.path === "trash://") l.push({ text: "Empty Trash", icon: "trash", action: () => Fs.emptyTrash() });
        l.push({ separator: true });
        l.push({ text: "Use Groups", icon: "finder.group", action: () => {} , enabled: false });
        l.push({ text: "Sort By", icon: "arrow.up.arrow.down", submenu: sortItems(w) });
        if (w.viewMode === "icon") {
            l.push({ text: "Clean Up", icon: "square.grid.3x3", enabled: false });
            l.push({ text: "Clean Up By", submenu: sortItems(w), enabled: false });
        }
        l.push({ text: "Show View Options", icon: "gearshape", enabled: false });
        return l;
    }
    function sortItems(w) {
        const keys = [["Name", "name"], ["Kind", "kind"], ["Date Modified", "date"], ["Size", "size"]];
        return [{ text: "None", checked: false, action: () => { w.sortKey = "name"; w.sortAsc = true; } }, { separator: true }]
            .concat(keys.map(k => ({ text: k[0], checked: w.sortKey === k[1], action: () => { w.sortKey = k[1]; w.sortAsc = k[1] === "name" || k[1] === "kind"; } })));
    }

    function contextMenu(w, pos, noGrab) {
        w.lastMenuPos = pos;
        menu.show(w, pos, w.selection.length ? itemMenu(w) : backgroundMenu(w), noGrab);
    }
    function actionMenu(w, pos, noGrab) {
        w.lastMenuPos = pos;
        let l = w.selection.length ? itemMenu(w) : backgroundMenu(w);
        if (w.selection.length) l = [{ text: "New Folder", icon: "folder.badge.plus", enabled: !w.isVirtual, action: () => w.newFolder() }, { separator: true }].concat(l);
        l = l.concat([{ separator: true },
                      { text: w.showPathBar ? "Hide Path Bar" : "Show Path Bar", icon: "", shortcut: sc("opt cmdP").replace(" ", ""), action: () => w.showPathBar = !w.showPathBar },
                      { text: w.showStatusBar ? "Hide Status Bar" : "Show Status Bar", icon: "", shortcut: sc("cmd/"), action: () => w.showStatusBar = !w.showStatusBar }]);
        menu.show(w, Qt.point(pos.x - 10, pos.y), l, noGrab);
    }
    function groupMenu(w, pos, noGrab) {
        const keys = [["Name", "name"], ["Kind", "kind"], ["Application", ""], ["Date Last Opened", ""], ["Date Added", ""],
                      ["Date Modified", "date"], ["Date Created", ""], ["Size", "size"], ["Tags", ""]];
        const l = [{ text: "None", checked: w.groupBy === "", action: () => w.groupBy = "" }, { separator: true }]
            .concat(keys.map(k => ({ text: k[0], checked: w.groupBy !== "" && w.groupBy === k[1], enabled: k[1] !== "",
                                     action: () => { w.groupBy = k[1]; w.sortKey = k[1]; w.sortAsc = k[1] === "name" || k[1] === "kind"; } })));
        menu.show(w, Qt.point(pos.x - 10, pos.y), l, noGrab);
    }
    function viewMenu(w, pos, noGrab) {
        const v = [["as Icons", "icon", "square.grid.2x2", "cmd1"], ["as List", "list", "list.bullet", "cmd2"],
                   ["as Columns", "column", "rectangle.split.3x1", "cmd3"], ["as Gallery", "gallery", "finder.gallery", "cmd4"]];
        menu.show(w, Qt.point(pos.x - 10, pos.y), v.map(x => ({ text: x[0], icon: x[2], checked: w.viewMode === x[1] ? true : undefined,
                                                         shortcut: sc(x[3]), action: () => w.viewMode = x[1] })), noGrab);
    }
    function tagMenu(w, pos, noGrab) {
        const files = w.selection.filter(e => !e.app && !e.volume);
        if (!files.length) return;
        const l = [{ tags: true, isTagged: n => files.every(e => Fs.tagsOf(e.path).includes(n)), toggle: n => Fs.toggleTag(files.map(e => e.path), n) },
                   { separator: true }]
            .concat(Fs.tagList.map(t => ({ text: t.name, checked: files.every(e => Fs.tagsOf(e.path).includes(t.name)) ? true : undefined,
                                           action: () => Fs.toggleTag(files.map(e => e.path), t.name) })));
        menu.show(w, Qt.point(pos.x - 10, pos.y), l, noGrab);
    }
    function shareMenu(w, pos, noGrab) {
        const files = w.selection.filter(e => !e.app && !e.volume);
        if (!files.length) return;
        const l = [
            { text: "Copy", icon: "doc.on.doc", action: () => w.copySelection() },
            { text: "AirDrop", icon: "airdrop", enabled: false },
            { separator: true },
            { text: "Compress " + quoted(files), icon: "doc.zipper", enabled: !w.isVirtual, action: () => w.compressSelection() }
        ];
        menu.show(w, Qt.point(pos.x - 10, pos.y), l, noGrab);
    }
    function sidebarMenu(w, item, pos) {
        const l = [
            { text: "Open in New Window", icon: "macwindow.badge.plus", enabled: item.enabled !== false, action: () => root.newWindow(item.path) },
            { text: "Get Info", icon: "info.circle", enabled: !Fs.isVirtual(item.path),
              action: () => root.getInfo({ name: item.label, path: item.path, isDir: true, size: -1, mtime: 0 }) }
        ];
        if (item.path === "trash://") l.push({ separator: true }, { text: "Empty Trash", icon: "trash", action: () => Fs.emptyTrash() });
        if (item.volume) l.push({ separator: true }, { text: "Eject “" + item.label + "”", icon: "eject.fill", action: () => Fs.eject(item.path) });
        menu.show(w, pos, l);
    }

    // « Open With » : applications associées au type (gio mime), en cache
    QtObject {
        id: openWith
        property var cache: ({})
        function itemsFor(e) {
            const mime = Fs.mimeOf(e);
            const ids = cache[mime];
            if (ids === undefined && !owProc.running) {
                owProc.mime = mime;
                owProc.command = ["sh", "-c", 'gio mime "$1" 2>/dev/null | sed -n "s/^[[:space:]]*\\([^[:space:]]*\\.desktop\\)$/\\1/p"; xdg-mime query default "$1" 2>/dev/null', "sh", mime];
                owProc.running = true;
            }
            const list = [];
            const seen = {};
            for (const id of ids ?? []) {
                const de = DesktopEntries.byId(id.replace(/\.desktop$/, ""));
                if (!de || seen[de.id]) continue;
                seen[de.id] = true;
                list.push({ text: de.name + (list.length === 0 ? " (default)" : ""), icon: "", action: () => Fs.openWith(e.path, de.id + ".desktop") });
            }
            if (!list.length) list.push({ text: "No Applications", enabled: false });
            list.push({ separator: true });
            list.push({ text: "Other…", enabled: false });
            return list;
        }
    }
    ProcessCollector {
        id: owProc
        property string mime: ""
        onDone: (t) => {
            const ids = t.split("\n").map(s => s.trim()).filter(s => s.endsWith(".desktop"));
            // Par défaut en tête
            const def = ids[ids.length - 1];
            const uniq = [def].concat(ids).filter((v, i, a) => v && a.indexOf(v) === i);
            const c = Object.assign({}, openWith.cache);
            c[mime] = uniq;
            openWith.cache = c;
        }
    }

    // ------------------------------------------------------------ Coup d'œil
    QuickLook { id: ql; finder: root }
    function toggleQuickLook(w) {
        if (ql.shown) { ql.close(); return; }
        const sel = w.selection;
        if (!sel.length) return;
        ql.show(w, sel);
    }
    // La sélection change pendant le Coup d'œil : l'aperçu suit
    function selectionChanged(w) {
        if (ql.shown && ql.source === w && w.selection.length) ql.entries = w.selection;
        // Préchargement des applications « Open With » du type sélectionné
        const s = w.selection;
        if (s.length === 1 && !s[0].isDir && !s[0].app) openWith.itemsFor(s[0]);
    }

    // ------------------------------------------------------------ Lire les informations
    property var infoEntries: []
    function getInfo(e) {
        if (!e) return;
        if (infoEntries.some(x => x.path === e.path)) return;
        infoEntries = infoEntries.concat([e]);
    }
    Variants {
        model: root.infoEntries
        InfoWindow {
            required property var modelData
            entry: modelData
            onDismissed: root.infoEntries = root.infoEntries.filter(x => x.path !== modelData.path)
        }
    }

    // ------------------------------------------------------------ Aller au dossier / alertes
    // Ouvre un chemin dans une fenêtre existante (dossier -> y naviguer ;
    // fichier -> son dossier, fichier sélectionné ; absent -> alerte)
    Component { id: probeComp; ProcessCollector {} }
    function openInWindow(w, p) {
        const pr = probeComp.createObject(root, { command: ["sh", "-c", 'if [ -d "$1" ]; then echo d; elif [ -e "$1" ] || [ -L "$1" ]; then echo f; else echo n; fi', "sh", p] });
        pr.done.connect(t => {
            const k = t.trim();
            if (k === "d") w.navigate(p);
            else if (k === "f") w.navigate(Fs.dirname(p), Fs.basename(p));
            else root.alert(w, "The folder \u201C" + Fs.basename(p) + "\u201D can\u2019t be found.");
            pr.destroy();
        });
        pr.running = true;
    }
    function goToFolder(w) { w.showGoTo = true; }
    function alert(w, text) { w.alertText = text; }
}
