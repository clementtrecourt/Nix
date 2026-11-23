import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common
import qs.services

// Modèle du Dock : liste ordonnée des tuiles (apps épinglées, apps ouvertes,
// séparateurs, fenêtres minimisées, Téléchargements, Corbeille), synchronisée de
// façon incrémentale dans un ListModel pour que les délégués survivent aux
// changements (animations d'apparition / disparition, rebond de lancement).
//
// Clés des tuiles :
//   app:<id .desktop ou classe>   rec:<id> (récentes)   win:<adresse>
//   sep:main  sep:recents  folder:downloads  trash
Item {
    id: root
    visible: false

    // ---- Réglages (surchargés par settings.json : clés "dock.*") ----
    property bool showRecents: false
    property int recentsMax: 3

    // ---- Apps épinglées (persistées dans l'état du shell) ----
    // "macos:apps" = icône « Apps » (Launchpad de Tahoe), ouvre la vue Apps.
    readonly property string appsTileId: "macos:apps"
    property var pinned: defaultPinned()
    property var recents: []
    property bool stateLoaded: false

    function defaultPinned() {
        const l = Array.from(Apps.pinned);
        // Dock Tahoe d'origine : Finder, puis Apps.
        if (!l.includes(appsTileId)) l.splice(Math.min(1, l.length), 0, appsTileId);
        return l;
    }

    FileView {
        id: stateFile
        path: Quickshell.statePath("dock.json")
        watchChanges: false
        printErrors: false
        onLoaded: {
            try {
                const o = JSON.parse(text());
                if (Array.isArray(o.pinned)) root.pinned = o.pinned;
                if (Array.isArray(o.recents)) root.recents = o.recents;
            } catch (e) {}
            root.stateLoaded = true;
            root.scheduleSync();
        }
        onLoadFailed: { root.stateLoaded = true; root.scheduleSync(); }
    }
    function saveState() {
        stateFile.setText(JSON.stringify({ pinned: root.pinned, recents: root.recents }, null, 2));
    }

    // ---- Correspondances classe de fenêtre <-> id d'app ----
    function norm(s) { return (s ?? "").toLowerCase(); }
    function idForClass(cls) {
        const e = Apps.entryFor(cls);
        return e ? e.id : cls;
    }
    function sameApp(id, cls) {
        if (!id || !cls) return false;
        if (norm(id) === norm(cls)) return true;
        const a = Apps.entryFor(id), b = Apps.entryFor(cls);
        return !!a && !!b && norm(a.id) === norm(b.id);
    }
    function isPinned(id) { return root.pinned.some(p => norm(p) === norm(id)); }

    // Fenêtres "rangées" par le Dock : minimisées ou masquées (Cmd+H)
    function isHidden(t) { return t?.workspace?.name === "special:hidden"; }
    function windowsFor(cls) { return cls ? Windows.windowsOf(cls) : []; }
    function toplevelByAddress(addr) {
        return Windows.toplevels.find(t => t.address === addr) ?? null;
    }

    // ---- Apps en cours de lancement (rebond) ----
    // { id: { start: ms, end: ms|0 } }
    property var launching: ({})
    readonly property bool bouncing: Object.keys(launching).length > 0 || urgentClasses.length > 0
    readonly property var urgentClasses: Windows.toplevels.filter(t => t.urgent).map(t => Windows.classOf(t))

    function markLaunching(id) {
        const l = Object.assign({}, launching);
        l[id] = { start: Date.now(), end: 0 };
        launching = l;
        launchTimeout.restart();
    }
    // Appelé quand une fenêtre de l'app est apparue : le rebond en cours se termine.
    function endLaunching(id) {
        if (!launching[id] || launching[id].end) return;
        const l = Object.assign({}, launching);
        l[id] = { start: l[id].start, end: Date.now() };
        launching = l;
    }
    function clearLaunching(id) {
        const l = Object.assign({}, launching);
        delete l[id];
        launching = l;
    }
    Timer {
        // Garde-fou : macOS arrête de rebondir si l'app ne s'ouvre jamais.
        id: launchTimeout
        interval: 1000
        repeat: true
        running: Object.keys(root.launching).length > 0
        onTriggered: {
            const now = Date.now();
            for (const id in root.launching) {
                const s = root.launching[id];
                if (s.end && now - s.end > 1500) root.clearLaunching(id);
                else if (!s.end && now - s.start > 15000) root.endLaunching(id);
            }
        }
    }

    // ---- Liste voulue ----
    function computeItems() {
        const out = [];
        const running = Windows.runningClasses.filter(c => c && !c.startsWith("macos-"));
        const used = new Set();

        for (const id of root.pinned) {
            let cls = "";
            for (const c of running) {
                if (!used.has(c) && sameApp(id, c)) { cls = c; used.add(c); }
            }
            out.push({ key: "app:" + norm(id), kind: "app", appId: id, cls: cls, address: "" });
        }
        const showRec = root.showRecents;
        const extra = [];
        for (const c of running) {
            if (used.has(c)) continue;
            used.add(c);
            const id = idForClass(c);
            // Deux classes pour la même app : on fusionne.
            if (extra.some(x => norm(x.appId) === norm(id))) continue;
            extra.push({ key: "app:" + norm(id), kind: "app", appId: id, cls: c, address: "" });
        }
        if (!showRec) {
            for (const x of extra) out.push(x);
        }
        if (showRec) {
            // Section « récentes » : apps ouvertes non épinglées + dernières quittées
            const rec = extra.slice();
            for (const id of root.recents) {
                if (rec.length >= Math.max(root.recentsMax, extra.length)) break;
                if (isPinned(id) || rec.some(x => norm(x.appId) === norm(id))) continue;
                rec.push({ key: "app:" + norm(id), kind: "app", appId: id, cls: "", address: "" });
            }
            if (rec.length > 0) {
                out.push({ key: "sep:recents", kind: "separator", appId: "", cls: "", address: "" });
                for (const x of rec) out.push(x);
            }
        }
        out.push({ key: "sep:main", kind: "separator", appId: "", cls: "", address: "" });
        // Fenêtres minimisées, juste après le séparateur (comme macOS)
        for (const t of Windows.toplevels) {
            if (Windows.isMinimized(t))
                out.push({ key: "win:" + t.address, kind: "window", appId: idForClass(Windows.classOf(t)), cls: Windows.classOf(t), address: t.address });
        }
        out.push({ key: "folder:downloads", kind: "folder", appId: "", cls: "", address: "" });
        out.push({ key: "trash", kind: "trash", appId: "", cls: "", address: "" });
        return out;
    }

    // ---- Synchronisation incrémentale ----
    property bool ready: false
    readonly property ListModel items: ListModel {}

    function scheduleSync() { syncTimer.restart(); }
    Timer { id: syncTimer; interval: 16; onTriggered: root.sync() }

    function indexOfKey(key) {
        for (let i = 0; i < items.count; i++) {
            const e = items.get(i);
            if (e.key === key && !e.removing) return i;
        }
        return -1;
    }

    function sync() {
        const want = computeItems();
        const keys = new Set(want.map(w => w.key));
        for (let i = 0; i < items.count; i++) {
            const e = items.get(i);
            if (!keys.has(e.key) && !e.removing) items.setProperty(i, "removing", true);
        }
        let pos = 0;
        for (const w of want) {
            while (pos < items.count && items.get(pos).removing) pos++;
            const idx = indexOfKey(w.key);
            if (idx < 0) {
                items.insert(pos, { key: w.key, kind: w.kind, appId: w.appId, cls: w.cls, address: w.address, removing: false, fresh: root.ready });
            } else {
                if (idx !== pos) items.move(idx, pos, 1);
                const e = items.get(pos);
                if (e.cls !== w.cls) items.setProperty(pos, "cls", w.cls);
                if (e.appId !== w.appId) items.setProperty(pos, "appId", w.appId);
            }
            pos++;
        }
        // Fin du rebond pour les apps dont une fenêtre est apparue
        for (const id in launching) {
            if (launching[id].end) continue;
            const w = want.find(x => x.kind === "app" && norm(x.appId) === norm(id));
            if (w && w.cls) endLaunching(id);
        }
        // Apps quittées -> récentes
        trackRecents(want);
        root.ready = true;
    }

    // Retire définitivement une tuile dont l'animation de sortie est finie.
    function finishRemoval(key) {
        for (let i = 0; i < items.count; i++) {
            const e = items.get(i);
            if (e.key === key && e.removing) { items.remove(i); return; }
        }
    }

    property var lastRunning: []
    function trackRecents(want) {
        const now = want.filter(w => w.kind === "app" && w.cls).map(w => w.appId);
        const quit = lastRunning.filter(id => !now.some(n => norm(n) === norm(id)));
        lastRunning = now;
        if (quit.length === 0) return;
        let r = root.recents.filter(id => !quit.some(q => norm(q) === norm(id)));
        r = quit.filter(id => !isPinned(id)).concat(r).slice(0, 10);
        if (JSON.stringify(r) !== JSON.stringify(root.recents)) { root.recents = r; saveState(); }
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            const n = ev.name;
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "movewindowv2"
                || n === "windowtitle" || n === "windowtitlev2" || n === "urgent" || n === "activewindow")
                root.scheduleSync();
        }
    }
    Connections {
        target: Windows
        function onToplevelsChanged() { root.scheduleSync(); }
        function onRunningClassesChanged() { root.scheduleSync(); }
    }
    onPinnedChanged: scheduleSync()
    onShowRecentsChanged: scheduleSync()
    Component.onCompleted: scheduleSync()

    // ---- Actions ----
    function launch(id) {
        if (id === appsTileId) { ShellState.toggle("apps"); return; }
        markLaunching(id);
        Apps.launch(id);
    }

    // Clic sur une app : lance, ré-affiche (masquée), ou active / fait défiler.
    function activate(id, cls) {
        if (id === appsTileId) { ShellState.toggle("apps"); return; }
        const ws = windowsFor(cls);
        if (ws.length === 0) { launch(id); return; }
        const hidden = ws.filter(t => isHidden(t));
        if (hidden.length > 0) { unhide(cls); return; }
        Windows.activateApp(cls, () => launch(id));
    }

    function hide(cls) {
        for (const t of windowsFor(cls))
            if (!Windows.isMinimized(t)) Windows.dispatch("movetoworkspacesilent special:hidden,address:" + Windows.addressOf(t));
    }
    function unhide(cls) {
        const ws = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
        const list = windowsFor(cls).filter(t => isHidden(t));
        for (const t of list) Windows.dispatch("movetoworkspacesilent " + ws + ",address:" + Windows.addressOf(t));
        if (list.length) Windows.dispatch("focuswindow address:" + Windows.addressOf(list[list.length - 1]));
    }

    function setPinned(id, keep) {
        let l = root.pinned.filter(p => norm(p) !== norm(id));
        if (keep) {
            // Placé là où l'app apparaît déjà (fin des épinglées)
            l.push(id);
        }
        root.pinned = l;
        saveState();
    }
    function movePinned(id, toIndex) {
        const l = root.pinned.filter(p => norm(p) !== norm(id));
        l.splice(Math.max(0, Math.min(toIndex, l.length)), 0, id);
        root.pinned = l;
        saveState();
    }

    // « Ouvrir à l'ouverture de session » : lien dans ~/.config/autostart
    property var autostart: ({})
    function autostartPath(id) { return Quickshell.env("HOME") + "/.config/autostart/" + id + ".desktop"; }
    function refreshAutostart(id) {
        autostartProbe.target = id;
        autostartProbe.command = ["sh", "-c", "test -e \"$1\"", "sh", autostartPath(id)];
        autostartProbe.running = true;
    }
    Process {
        id: autostartProbe
        property string target
        onExited: (code) => {
            const a = Object.assign({}, root.autostart);
            a[target] = (code === 0);
            root.autostart = a;
        }
    }
    function setAutostart(id, on) {
        const script = on
            ? 'mkdir -p "$HOME/.config/autostart"; for d in $(printf %s "$HOME/.local/share:${XDG_DATA_DIRS:-/run/current-system/sw/share}" | tr : " "); do f="$d/applications/$1.desktop"; if [ -e "$f" ]; then ln -sf "$f" "$2"; exit 0; fi; done; exit 1'
            : 'rm -f "$2"';
        Quickshell.execDetached(["sh", "-c", script, "sh", id, autostartPath(id)]);
        const a = Object.assign({}, autostart);
        a[id] = on;
        autostart = a;
    }

    // « Afficher dans le Finder » : révèle le .desktop dans le gestionnaire de fichiers
    function showInFinder(id) {
        const script = 'for d in $(printf %s "$HOME/.local/share:${XDG_DATA_DIRS:-/run/current-system/sw/share}" | tr : " "); do f="$d/applications/$1.desktop"; if [ -e "$f" ]; then f=$(readlink -f "$f"); exec gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 --method org.freedesktop.FileManager1.ShowItems "[\'file://$f\']" ""; fi; done';
        Quickshell.execDetached(["sh", "-c", script, "sh", id]);
    }

    function openPath(p) { Quickshell.execDetached(["xdg-open", p]); }
    readonly property string downloadsDir: Quickshell.env("XDG_DOWNLOAD_DIR") || (Quickshell.env("HOME") + "/Downloads")
    readonly property string trashDir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/Trash/files"
    function openTrash() { Quickshell.execDetached(["sh", "-c", "nemo trash:/// || gio open trash:///"]); }
    function emptyTrash() { Quickshell.execDetached(["gio", "trash", "--empty"]); }
}
