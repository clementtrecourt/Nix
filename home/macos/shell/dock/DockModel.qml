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
    // macOS : « Afficher les apps suggérées et récentes dans le Dock » est activé
    // sur une installation neuve.
    property bool showRecents: true
    property int recentsMax: 3

    // ---- Apps épinglées (persistées dans l'état du shell) ----
    // "macos:apps" = icône « Apps » (Launchpad de Tahoe), ouvre la vue Apps.
    readonly property string appsTileId: "macos:apps"
    // Ordre : modifications de l'utilisateur (état persistant) > settings.json
    // ("dock.pinned", fourni par Nix) > Apps.pinned.
    property var pinned: []
    property var recents: []
    // Réglages changés à l'exécution (IPC, raccourci, menu) : { autohide, magnification,
    // showRecents } ; persistés et appliqués par-dessus settings.json par Dock.qml.
    property var prefs: ({})
    function setPref(k, v) {
        const p = Object.assign({}, prefs);
        p[k] = v;
        prefs = p;
        saveState(false);
    }
    // « Options > Assign To » : { id: "all" | <id d'espace de travail> } (absent = None)
    property var assign: ({})
    function assignOf(id) {
        const v = assign[norm(cleanId(id))];
        return v === undefined || v === null ? "none" : v === "all" ? "all" : "this";
    }
    function setAssign(id, mode) {
        const a = Object.assign({}, assign);
        const k = norm(cleanId(id));
        if (mode === "none") delete a[k];
        else if (mode === "all") a[k] = "all";
        else a[k] = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
        assign = a;
        saveState(false);
    }
    // Nouvelle fenêtre d'une app attribuée à un bureau : envoyée sur ce bureau.
    // « All Desktops » : épinglée sur tous les bureaux (fenêtres flottantes,
    // seules épinglables sous Hyprland).
    function applyAssign(addr, ws, cls) {
        const v = assign[norm(idForClass(cls))];
        if (v === undefined || v === null) return;
        if (v === "all") {
            const t = toplevelByAddress(addr.startsWith("0x") ? addr : "0x" + addr);
            if (t?.lastIpcObject?.floating) Windows.dispatch("pin address:" + (addr.startsWith("0x") ? addr : "0x" + addr));
        } else if (String(v) !== String(ws)) {
            Windows.dispatch("movetoworkspacesilent " + v + ",address:" + (addr.startsWith("0x") ? addr : "0x" + addr));
        }
    }
    property bool stateLoaded: false
    property bool userPinned: false
    property var basePinned: null

    function defaultPinned() {
        const l = dedupe(Array.from(basePinned ?? Apps.pinned));
        // Dock Tahoe d'origine : Finder, puis Apps.
        if (!l.includes(appsTileId)) l.splice(Math.min(1, l.length), 0, appsTileId);
        return l;
    }
    function applyDefaults() { if (!userPinned) pinned = defaultPinned(); }
    // Ids en double (même id, casse différente, « .desktop ») : un seul exemplaire,
    // sinon la synchronisation du ListModel se désaligne.
    function cleanId(id) { return String(id ?? "").replace(/\.desktop$/i, ""); }
    function dedupe(l) {
        const out = [];
        for (const raw of l) {
            const id = cleanId(raw);
            if (id && !out.some(x => norm(x) === norm(id))) out.push(id);
        }
        return out;
    }
    function setBasePinned(l) { basePinned = l; applyDefaults(); }
    Connections {
        target: Apps
        function onPinnedChanged() { root.applyDefaults(); }
    }

    FileView {
        id: stateFile
        path: Quickshell.statePath("dock.json")
        watchChanges: false
        printErrors: false
        onLoaded: {
            try {
                const o = JSON.parse(text());
                if (Array.isArray(o.pinned)) { root.pinned = root.dedupe(o.pinned); root.userPinned = true; }
                if (Array.isArray(o.recents)) root.recents = root.dedupe(o.recents);
                if (o.prefs && typeof o.prefs === "object") root.prefs = o.prefs;
                if (o.assign && typeof o.assign === "object") root.assign = o.assign;
            } catch (e) {}
            root.applyDefaults();
            root.stateLoaded = true;
            root.scheduleSync();
        }
        onLoadFailed: { root.applyDefaults(); root.stateLoaded = true; root.scheduleSync(); }
    }
    // pinnedChanged : vrai quand l'utilisateur a modifié le Dock
    function saveState(pinnedChanged) {
        if (pinnedChanged) userPinned = true;
        const o = { recents: root.recents, prefs: root.prefs, assign: root.assign };
        if (userPinned) o.pinned = root.pinned;
        stateFile.setText(JSON.stringify(o, null, 2));
    }

    // ---- Correspondances classe de fenêtre <-> id d'app ----
    function norm(s) { return (s ?? "").toLowerCase(); }
    function idForClass(cls) {
        if (norm(cls) === shellClass) return finderId;
        const e = Apps.entryFor(cls);
        return e ? e.id : cls;
    }
    function sameApp(id, cls) {
        if (!id || !cls) return false;
        if (norm(id) === norm(cls)) return true;
        // Fenêtres du Finder du shell (classe org.quickshell) -> tuile Finder
        if (norm(cls) === shellClass) return isFinder(id);
        const a = Apps.entryFor(id), b = Apps.entryFor(cls);
        return !!a && !!b && norm(a.id) === norm(b.id);
    }
    function isPinned(id) { return root.pinned.some(p => norm(p) === norm(id)); }

    // ---- Finder ----
    // Le gestionnaire de fichiers joue le rôle du Finder : toujours « ouvert »
    // (point permanent), jamais « Quitter », impossible à retirer du Dock.
    readonly property var finderIds: ["nemo", "org.gnome.nautilus", "nautilus", "thunar", "org.kde.dolphin", "pcmanfm", "pcmanfm-qt", "caja"]
    function isFinder(id) { return finderIds.includes(norm(cleanId(id))); }
    // Fenêtres du shell lui-même (Finder QML de finder/, About This Mac…) :
    // classe Wayland de Quickshell, rattachées au Finder
    readonly property string shellClass: "org.quickshell"
    // Ouvre un chemin dans le Finder du shell (même instance Quickshell, IPC
    // « finder open <chemin> » : dossier -> fenêtre, fichier -> révélé), sinon
    // commande de repli (gestionnaire de fichiers externe).
    function finderOpen(path, fallback) {
        Quickshell.execDetached(["sh", "-c",
            // « ipc call » renvoie 0 même sans cible : on vérifie qu'elle existe
            'if quickshell ipc -p "$1" show 2>/dev/null | grep -qx "target finder"; then exec quickshell ipc -p "$1" call finder open "$2"; fi; [ -n "$3" ] && exec sh -c "$3" sh "$2"',
            "sh", Quickshell.shellDir, path, fallback ?? ""]);
    }
    // Id du Finder par défaut (premier gestionnaire de fichiers des apps par défaut)
    readonly property string finderId: Array.from(Apps.pinned).find(p => isFinder(p)) ?? "nemo"

    // ---- Noms affichés (bulle, menus) ----
    // Nom macOS anglais (services/Apps.displayName) ; le gestionnaire de
    // fichiers est toujours « Finder ».
    function displayName(id, cls) {
        if (id === appsTileId) return "Apps";
        if (isFinder(id || cls)) return "Finder";
        return Apps.displayName(id || cls);
    }
    // App épinglée dont l'entrée .desktop n'existe pas (désinstallée) : « ? » de macOS
    function isMissing(id, cls) {
        return !!id && id !== appsTileId && !cls && !Apps.entryFor(id);
    }

    // Fenêtres "rangées" par le Dock : minimisées ou masquées (Cmd+H)
    function isHidden(t) { return t?.workspace?.name === "special:hidden"; }
    function windowsFor(cls) { return cls ? Windows.windowsOf(cls) : []; }
    function toplevelByAddress(addr) {
        return Windows.toplevels.find(t => t.address === addr) ?? null;
    }

    // Fenêtres en cours d'animation génie : leur miniature est masquée dans le Dock
    property var landing: ({})
    function setLanding(addr, on) {
        const l = Object.assign({}, landing);
        if (on) l[addr] = true; else delete l[addr];
        landing = l;
    }

    // ---- Apps en cours de lancement (rebond) ----
    // { id: { start: ms, end: ms|0 } }
    property var launching: ({})
    readonly property bool bouncing: Object.keys(launching).length > 0 || Object.keys(attention).length > 0
    readonly property var urgentClasses: Windows.toplevels.filter(t => t.urgent).map(t => Windows.classOf(t))
    // Demande d'attention : Hyprland ne distingue pas « informative » et
    // « critique » ; macOS fait rebondir une demande informative une seule fois
    // (≈ 1 s). { classe: début (ms) } ; une classe qui redevient urgente rebondit
    // à nouveau.
    property var attention: ({})
    property var lastUrgent: []
    onUrgentClassesChanged: {
        const a = Object.assign({}, attention);
        let changed = false;
        for (const c of urgentClasses)
            if (!lastUrgent.includes(c)) { a[c] = Date.now(); changed = true; }
        lastUrgent = urgentClasses.slice();
        if (changed) attention = a;
    }
    Timer {
        // Fin du rebond d'attention (un saut de 0,64 s)
        interval: 200
        repeat: true
        running: Object.keys(root.attention).length > 0
        onTriggered: {
            const now = Date.now(), a = {};
            for (const c in root.attention)
                if (now - root.attention[c] < 1000) a[c] = root.attention[c];
            if (Object.keys(a).length !== Object.keys(root.attention).length) root.attention = a;
        }
    }

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

        const keys = new Set();
        // Le Finder est toujours la première icône (macOS ne permet pas de le retirer)
        const pins = root.pinned.some(p => isFinder(p)) ? root.pinned : [finderId].concat(root.pinned);
        for (const id of pins) {
            if (keys.has("app:" + norm(id))) continue;
            keys.add("app:" + norm(id));
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
            if (extra.some(x => norm(x.appId) === norm(id)) || keys.has("app:" + norm(id))) continue;
            keys.add("app:" + norm(id));
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
                if (isPinned(id) || keys.has("app:" + norm(id)) || !Apps.entryFor(id)) continue;
                keys.add("app:" + norm(id));
                rec.push({ key: "app:" + norm(id), kind: "app", appId: id, cls: "", address: "" });
            }
            if (rec.length > 0) {
                out.push({ key: "sep:recents", kind: "separator", appId: "", cls: "", address: "" });
                for (const x of rec) out.push(x);
            }
        }
        out.push({ key: "sep:main", kind: "separator", appId: "", cls: "", address: "" });
        out.push({ key: "folder:downloads", kind: "folder", appId: "", cls: "", address: "" });
        // Fenêtres minimisées : juste à gauche de la Corbeille, la plus récemment
        // minimisée au plus près d'elle (comme macOS).
        const mins = Windows.toplevels.filter(t => Windows.isMinimized(t));
        const order = root.minOrder.filter(a => mins.some(t => t.address === a));
        for (const t of mins) {
            if (order.includes(t.address)) continue;
            order.push(t.address);
            // Minimisée hors du Dock (Cmd+M, bouton jaune) : le Dock rejoue l'effet.
            if (root.ready && !root.landing[t.address]) root.windowMinimized(t);
        }
        root.minOrder = order;
        for (const a of order) {
            const t = mins.find(x => x.address === a);
            out.push({ key: "win:" + a, kind: "window", appId: idForClass(Windows.classOf(t)), cls: Windows.classOf(t), address: a });
        }
        out.push({ key: "trash", kind: "trash", appId: "", cls: "", address: "" });
        return out;
    }

    // Adresses des fenêtres minimisées, dans l'ordre de minimisation
    property var minOrder: []
    // Fenêtre minimisée sans passer par le Dock (pour l'animation)
    signal windowMinimized(var toplevel)

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
        // Pas de liste tant que l'état n'est pas lu (évite un « saut » au démarrage)
        if (frozen || !stateLoaded) return;
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
                if (pos > items.count) pos = items.count;
                items.insert(pos, { key: w.key, kind: w.kind, appId: w.appId, cls: w.cls, address: w.address, removing: false, fresh: root.ready });
            } else {
                // Garde : la clé déjà placée plus haut (doublon) ne doit pas sortir des bornes
                if (idx < pos) continue;
                if (idx !== pos && pos < items.count) items.move(idx, pos, 1);
                const e = items.get(pos);
                if (!e) { pos++; continue; }
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
            if (n === "openwindow") {
                // adresse,espace de travail,classe,titre
                const f = String(ev.data).split(",");
                if (f.length >= 3) root.applyAssign(f[0], f[1], f[2]);
            }
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "movewindowv2"
                || n === "windowtitle" || n === "windowtitlev2" || n === "urgent" || n === "activewindow") {
                // lastIpcObject (classe, taille, espace de travail) n'est rempli
                // qu'après un rafraîchissement explicite.
                refreshTimer.restart();
                root.scheduleSync();
            }
        }
    }
    Timer {
        id: refreshTimer
        interval: 30
        onTriggered: { Hyprland.refreshToplevels(); root.scheduleSync(); }
    }
    Connections {
        target: Windows
        function onToplevelsChanged() { root.scheduleSync(); }
        function onRunningClassesChanged() { root.scheduleSync(); }
    }
    onPinnedChanged: scheduleSync()
    onShowRecentsChanged: scheduleSync()
    Component.onCompleted: { Hyprland.refreshToplevels(); scheduleSync(); }

    // ---- Actions ----
    function launch(id) {
        if (id === appsTileId) { ShellState.toggle("apps"); return; }
        // Finder sans fenêtre : nouvelle fenêtre (dossier personnel)
        if (isFinder(id)) {
            markLaunching(id);
            finderOpen(Quickshell.env("HOME"), 'exec nemo "$1"');
            return;
        }
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

    // « Force Quit » (Option + Quit) : SIGKILL aux processus des fenêtres de l'app
    function forceQuit(cls) {
        const pids = [];
        for (const t of windowsFor(cls)) {
            const p = t?.lastIpcObject?.pid;
            if (p && p > 0 && !pids.includes(p)) pids.push(p);
        }
        if (pids.length) Quickshell.execDetached(["kill", "-KILL"].concat(pids.map(String)));
        else Windows.quitApp(cls);
    }

    function setPinned(id, keep) {
        if (!keep && isFinder(id)) return;
        let l = root.pinned.filter(p => norm(p) !== norm(id));
        if (keep) {
            // Placé là où l'app apparaît déjà (fin des épinglées)
            l.push(id);
        }
        root.pinned = l;
        saveState(true);
    }
    // Fin d'un glisser-déposer dans le Dock : l'ordre affiché devient l'ordre des
    // apps épinglées ; une app ouverte non épinglée déplacée est gardée dans le Dock.
    function commitOrder(dragKey) {
        const apps = [];
        for (let i = 0; i < items.count; i++) {
            const e = items.get(i);
            if (e.kind === "separator") break;
            if (!e.removing && e.kind === "app") apps.push({ key: e.key, appId: e.appId });
        }
        const l = apps.filter(a => a.key === dragKey || isPinned(a.appId)).map(a => a.appId);
        if (JSON.stringify(l) !== JSON.stringify(root.pinned)) {
            root.pinned = l;
            saveState(true);
        }
    }

    // Pendant un glisser-déposer, la liste n'est pas resynchronisée
    property bool frozen: false

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

    // « Show in Finder » : révèle le .desktop de l'app dans le Finder
    function showInFinder(id) {
        const script = 'for d in $(printf %s "$HOME/.local/share:${XDG_DATA_DIRS:-/run/current-system/sw/share}" | tr : " "); do f="$d/applications/$1.desktop"; if [ -e "$f" ]; then f=$(readlink -f "$f"); quickshell ipc -p "$2" show 2>/dev/null | grep -qx "target finder" && exec quickshell ipc -p "$2" call finder open "$f"; exec gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 --method org.freedesktop.FileManager1.ShowItems "[\'file://$f\']" ""; exit 0; fi; done';
        Quickshell.execDetached(["sh", "-c", script, "sh", id, Quickshell.shellDir]);
    }

    // Dossier : Finder ; fichier : app par défaut
    function openPath(p) { finderOpen(p, 'exec xdg-open "$1"'); }
    function openFile(p) { Quickshell.execDetached(["xdg-open", p]); }
    // Dossier Téléchargements de l'utilisateur (xdg-user-dirs, localisé)
    property string downloadsDir: Quickshell.env("XDG_DOWNLOAD_DIR") || (Quickshell.env("HOME") + "/Downloads")
    Process {
        running: true
        command: ["sh", "-c", "xdg-user-dir DOWNLOAD 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = text.trim();
                if (d && d !== Quickshell.env("HOME")) root.downloadsDir = d;
            }
        }
    }
    readonly property string trashDir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/Trash/files"
    // Corbeille dans le Finder. NB : finder.openPath ne reconnaît pas encore
    // « trash:// » (sa vue Corbeille) : on lui passe le dossier des fichiers.
    function openTrash() { finderOpen(trashDir, 'nemo trash:/// || gio open trash:///'); }
    function emptyTrash() { Quickshell.execDetached(["gio", "trash", "--empty"]); }
}
