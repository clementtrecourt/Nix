import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.services

// Fenêtre du Finder (macOS Tahoe 26) : fenêtre normale gérée par Hyprland
// (classe org.quickshell), sans barre de titre du compositeur : le Finder
// dessine ses feux tricolores dans la barre latérale flottante.
//
// Couches (de bas en haut) :
//   stage    : fond + présentation courante + barres du bas. C'est le « fond »
//              que réfractent les verres (LiquidGlass, backdrop "snapshot").
//   bord     : effet de bord de défilement sous la barre d'outils (fondu)
//   sidebar  : verre Liquid Glass inset aux coins arrondis
//   toolbar  : capsules de verre (Précédent/Suivant, présentations, Grouper,
//              Partager/Tags/Action, Rechercher) + titre
//   overlays : feuille « Go to Folder », fantôme de glisser, menus
FloatingWindow {
    id: win

    required property var finder
    required property int wid
    property string startPath: Fs.home
    property string startReveal: ""

    title: Fs.displayName(path)
    // Fenêtre transparente : le fond du contenu est dessiné par `stage`, avec
    // un trou sous la barre latérale ; Hyprland floute ce qu'il y a derrière
    // la fenêtre (bureau, autres fenêtres) et le verre de la barre latérale le
    // teinte, comme le matériau « behind-window » du Finder de Tahoe.
    color: "transparent"
    implicitWidth: 980
    implicitHeight: 620
    minimumSize: Qt.size(FStyle.minWidth, FStyle.minHeight)

    // ------------------------------------------------------------ état
    property string path: ""
    property var backStack: []
    property var fwdStack: []
    // "icon" | "list" | "column" | "gallery"
    property string viewMode: "icon"
    // Taille des icônes en présentation Icônes (curseur de la barre d'état)
    property int iconSize: FStyle.iconSize
    property string sortKey: "name"        // name | date | size | kind
    property bool sortAsc: true
    property bool showHidden: false
    property bool showSidebar: true
    property bool showPathBar: false
    property bool showStatusBar: false
    property real sidebarWidth: FStyle.sidebarWidth
    property string searchText: ""
    // Grouper par (barre d'outils) : "" = aucun
    property string groupBy: ""
    // Récents : groupés par date de dernière ouverture par défaut (Tahoe)
    property string recentsGroupBy: "opened"
    readonly property string effectiveGroup: path === "recents://" ? recentsGroupBy : groupBy
    property point lastMenuPos: Qt.point(0, 0)
    property bool showGoTo: false
    property string alertText: ""
    property string alertInfo: ""
    property var alertButtons: []
    property bool searching: false
    readonly property bool active: stage.Window.active

    // Sélection : { chemin: true } (réaffectée à chaque changement : liaisons)
    property var selMap: ({})
    property string cursorPath: ""
    property string anchorPath: ""
    // Renommage en cours (chemin) ; ouverture différée du champ (clic lent)
    property string renamingPath: ""
    // Chemins à sélectionner quand ils apparaîtront (nouveau dossier, collage…)
    property var pendingSelect: []
    property bool pendingRename: false

    readonly property alias lister: lister
    // Recherche : dès la saisie, barre de portée sous la barre d'outils ;
    // « This Mac » (par défaut, comme Tahoe : ici le dossier personnel, faute
    // d'index Spotlight) ou le dossier courant, récursivement
    property string searchScope: "mac"
    readonly property string searchRoot: searchScope === "mac" || isVirtual ? Fs.home : path
    property string _searchKey: ""
    Timer {
        id: searchDebounce
        interval: 250
        onTriggered: win._searchKey = win.searchText ? JSON.stringify([win.searchRoot, win.searchText]) : ""
    }
    onSearchTextChanged: { if (!searchText) _searchKey = ""; else searchDebounce.restart(); }
    onSearchRootChanged: if (searchText) searchDebounce.restart()
    readonly property bool searchResults: searchText !== "" && _searchKey !== "" && !(isVirtual && searchScope !== "mac")
    DirLister {
        id: searchLister
        watch: false
        path: win._searchKey ? "search://" + win._searchKey : ""
    }
    readonly property var items: searchResults ? _sorted(searchLister.visibleEntries, sortKey, sortAsc, "")
                                               : _sorted(lister.visibleEntries, sortKey, sortAsc, searchText)
    // Éléments sélectionnés, dans l'ordre d'affichage (toutes profondeurs en Liste)
    readonly property var selection: {
        const m = selMap;
        const rows = (view.item && view.item.flatRows) ? view.item.flatRows : items;
        return rows.filter(e => m[e.path]);
    }
    readonly property var selectedPaths: Object.keys(selMap).filter(k => selMap[k])
    onSelectionChanged: win.finder.selectionChanged(win)
    readonly property bool canGoBack: backStack.length > 0
    readonly property bool canGoForward: fwdStack.length > 0
    readonly property bool isVirtual: Fs.isVirtual(path)
    readonly property bool writable: !isVirtual || path === "trash://"

    // Espace libre (barre d'état)
    property real freeBytes: -1

    // ------------------------------------------------------------ onglets
    // Chaque onglet garde son dossier, son historique, sa présentation et sa
    // sélection ; l'onglet actif vit dans les propriétés de la fenêtre.
    property var tabs: []          // [{ path, back, fwd, view, sel }]
    property int tabIndex: 0
    readonly property int tabCount: Math.max(1, tabs.length)
    readonly property real tabBarHeight: tabs.length > 1 ? 34 : 0
    // Hauteur de la barre d'outils (+ barre d'onglets) : haut des présentations
    // Barre sous la barre d'outils : portée de la recherche, ou « Trash … Empty »
    readonly property string subBar: searchText !== "" ? "search" : (path === "trash://" ? "trash" : "")
    readonly property real subBarHeight: subBar ? 32 : 0
    readonly property real chromeHeight: FStyle.toolbarHeight + tabBarHeight + subBarHeight
    function _saveTab() {
        const t = { path: path, back: backStack, fwd: fwdStack, view: viewMode, sel: selectedPaths };
        const l = tabs.length ? tabs.slice() : [t];
        l[tabIndex] = t;
        return l;
    }
    function _loadTab(t) {
        backStack = t.back;
        fwdStack = t.fwd;
        viewMode = t.view;
        if (t.path === path) selectPaths(t.sel, true);
        else { navigate(t.path, "", true); pendingSelect = t.sel; }
    }
    function newTab(p) {
        const l = _saveTab();
        l.splice(tabIndex + 1, 0, { path: p || path, back: [], fwd: [], view: viewMode, sel: [] });
        tabs = l;
        tabIndex = tabIndex + 1;
        _loadTab(l[tabIndex]);
    }
    function selectTab(i) {
        if (i === tabIndex || i < 0 || i >= tabs.length) return;
        tabs = _saveTab();
        tabIndex = i;
        _loadTab(tabs[i]);
    }
    function closeTab(i) {
        if (tabs.length <= 1) { closeWindow(); return; }
        const l = _saveTab();
        l.splice(i, 1);
        let ni = tabIndex;
        if (i < tabIndex) ni = tabIndex - 1;
        else if (i === tabIndex) ni = Math.min(tabIndex, l.length - 1);
        const reload = i === tabIndex;
        tabs = l.length > 1 ? l : [];
        tabIndex = l.length > 1 ? ni : 0;
        if (reload) _loadTab(l[ni]);
    }
    // Le titre de l'onglet actif suit le dossier
    onPathChanged: if (tabs.length > 1) { const l = tabs.slice(); l[tabIndex] = Object.assign({}, l[tabIndex], { path: path }); tabs = l; }

    // ------------------------------------------------------------ navigation
    function navigate(p, reveal, noHistory) {
        if (!p) return;
        if (p.length > 1 && p.endsWith("/") && !Fs.isVirtual(p)) p = p.slice(0, -1);
        if (p === path) { if (reveal) selectPaths([Fs.join(p, reveal)]); return; }
        if (!noHistory && path) { backStack = backStack.concat([path]); fwdStack = []; }
        renamingPath = "";
        searchText = "";
        searching = false;
        selMap = {};
        cursorPath = "";
        anchorPath = "";
        pendingSelect = reveal ? [Fs.join(p, reveal)] : (path && Fs.dirname(path) === p ? [path] : []);
        path = p;
        if (viewMode === "column" && view.item) view.item.rootChanged();
        refreshFree();
    }
    function goBack() {
        if (!canGoBack) return;
        const p = backStack[backStack.length - 1];
        backStack = backStack.slice(0, -1);
        fwdStack = fwdStack.concat([path]);
        navigate(p, "", true);
    }
    function goForward() {
        if (!canGoForward) return;
        const p = fwdStack[fwdStack.length - 1];
        fwdStack = fwdStack.slice(0, -1);
        backStack = backStack.concat([path]);
        navigate(p, "", true);
    }
    function goUp() {
        if (isVirtual || path === "/") { if (path === "/") navigate("computer://"); return; }
        navigate(Fs.dirname(path));
    }

    // Ouvre un élément : dossier -> navigue, application -> lance, fichier -> app par défaut
    function openEntry(e, newWindow) {
        if (!e) return;
        if (e.app) { e.app.execute(); return; }
        if (e.isDir) {
            if (newWindow) win.finder.newWindow(e.path);
            else navigate(e.path);
            return;
        }
        if (e.isLink && e.broken) return;
        // Archive Utility : une archive .zip se décompresse à côté d'elle
        if (Fs.ext(e.name) === "zip" && !isVirtual) {
            const dir = Fs.dirname(e.path);
            const n = Fs.uniqueName(dir === path ? existingNames : [], Fs.stem(e.name), "", "");
            if (dir === path) pendingSelect = [Fs.join(dir, n)];
            Fs.run(["sh", "-c", 'mkdir -p "$2" && cd "$2" && unzip -q "$1" && set -- * && [ "$#" -eq 1 ] && [ -d "$1" ] && [ "$1" = "$(basename "$PWD")" ] && mv "$1" "../.$1.tmp" && cd .. && rmdir "$OLDPWD" && mv ".$1.tmp" "$1"; exit 0', "sh", e.path, Fs.join(dir, n)], [dir]);
            return;
        }
        Fs.open(e.path);
    }
    function openSelection(newWindow) {
        const s = selection;
        if (s.length === 1 && s[0].isDir && !newWindow) { navigate(s[0].path); return; }
        for (const e of s) openEntry(e, e.isDir);
    }

    // ------------------------------------------------------------ tri
    function _natural(a, b) {
        const ax = a.toLowerCase().match(/(\d+|\D+)/g) ?? [];
        const bx = b.toLowerCase().match(/(\d+|\D+)/g) ?? [];
        for (let i = 0; i < Math.min(ax.length, bx.length); ++i) {
            const x = ax[i], y = bx[i];
            if (x === y) continue;
            const nx = /^\d/.test(x), ny = /^\d/.test(y);
            if (nx && ny) { const d = Number(x) - Number(y); if (d !== 0) return d; continue; }
            return x.localeCompare(y);
        }
        return ax.length - bx.length;
    }
    function compare(a, b, key) {
        let r = 0;
        if (key === "date") r = (a.mtime ?? 0) - (b.mtime ?? 0);
        else if (key === "size") r = (a.isDir ? -1 : a.size) - (b.isDir ? -1 : b.size);
        else if (key === "kind") r = Fs.kindOf(a).localeCompare(Fs.kindOf(b));
        if (r === 0) r = _natural(a.name, b.name);
        return r;
    }
    function _sorted(list, key, asc, q) {
        let l = list;
        if (q) {
            const ql = q.toLowerCase();
            l = l.filter(e => e.name.toLowerCase().indexOf(ql) >= 0);
        }
        // Récents : du plus récent au plus ancien (comme le Finder)
        const k = path === "recents://" && key === "name" ? "recent" : key;
        if (k === "recent") return l.slice().sort((a, b) => a.rank - b.rank);
        const s = l.slice().sort((a, b) => compare(a, b, k));
        return asc ? s : s.reverse();
    }
    function sortBy(key) {
        if (sortKey === key) sortAsc = !sortAsc;
        else { sortKey = key; sortAsc = key === "name" || key === "kind"; }
    }

    // ------------------------------------------------------------ sélection
    function isSel(p) { return !!selMap[p]; }
    function selectPaths(ps, keepCursor) {
        const m = {};
        for (const p of ps) m[p] = true;
        selMap = m;
        if (!keepCursor && ps.length) { cursorPath = ps[ps.length - 1]; anchorPath = ps[0]; }
        if (ps.length && view.item) view.item.ensureVisible(ps[ps.length - 1]);
    }
    function selectAll() {
        const rows = (view.item && view.item.flatRows) ? view.item.flatRows : items;
        selectPaths(rows.map(e => e.path), true);
    }
    function clearSelection() { selMap = {}; }
    // Clic sur un élément : simple, Maj (plage), ⌘ (bascule). `order` : liste
    // ordonnée de la présentation (pour les plages).
    function clickItem(e, mods, order) {
        stage.forceActiveFocus();
        const cmd = mods & (Qt.ControlModifier | Qt.MetaModifier);
        const shift = mods & Qt.ShiftModifier;
        if (cmd) {
            const m = Object.assign({}, selMap);
            if (m[e.path]) delete m[e.path]; else m[e.path] = true;
            selMap = m;
            cursorPath = e.path;
            anchorPath = e.path;
            return;
        }
        if (shift && anchorPath) {
            const list = order ?? items;
            const a = list.findIndex(x => x.path === anchorPath);
            const b = list.findIndex(x => x.path === e.path);
            if (a >= 0 && b >= 0) {
                const m = {};
                for (let i = Math.min(a, b); i <= Math.max(a, b); ++i) m[list[i].path] = true;
                selMap = m;
                cursorPath = e.path;
                return;
            }
        }
        if (!selMap[e.path]) selectPaths([e.path]);
        else { cursorPath = e.path; anchorPath = e.path; }
    }
    // Relâchement sans glisser sur un élément déjà sélectionné : réduit la
    // sélection à lui (ou lance le renommage au « clic lent » comme le Finder)
    function releaseItem(e, mods, wasSelectedAlone) {
        if (mods & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier)) return;
        if (wasSelectedAlone && writable && !isVirtual) slowRename.start(e.path);
        else selectPaths([e.path]);
    }
    Timer {
        id: slowRename
        property string target: ""
        interval: 650
        function start(p) { target = p; restart(); }
        onTriggered: if (win.selectedPaths.length === 1 && win.selectedPaths[0] === target) win.renamingPath = target
    }
    function cancelSlowRename() { slowRename.stop(); }

    // Saisie rapide d'un nom : sélectionne le premier élément qui commence par
    // les lettres tapées (remis à zéro après 1 s de silence)
    property string typeAhead: ""
    Timer { id: typeTimer; interval: 1000; onTriggered: win.typeAhead = "" }
    function typeSelect(ch) {
        typeAhead += ch.toLowerCase();
        typeTimer.restart();
        const rows = (view.item && view.item.flatRows) ? view.item.flatRows : items;
        const sorted = rows.slice().sort((a, b) => _natural(a.name, b.name));
        const hit = sorted.find(e => e.name.toLowerCase().startsWith(typeAhead))
                    ?? sorted.find(e => e.name.toLowerCase() >= typeAhead);
        if (hit) selectPaths([hit.path]);
    }

    // Sélection différée (après création / collage / navigation)
    Connections {
        target: lister
        function onLoaded() {
            if (win.pendingSelect.length) {
                const have = win.pendingSelect.filter(p => win.lister.entries.some(e => e.path === p));
                if (have.length) {
                    win.selectPaths(have);
                    if (win.pendingRename && have.length === 1) win.renamingPath = have[0];
                    win.pendingSelect = [];
                    win.pendingRename = false;
                }
            }
            // Éléments disparus : retirés de la sélection
            const m = {};
            let changed = false;
            for (const p of Object.keys(win.selMap)) {
                if (win.lister.entries.some(e => e.path === p) || (view.item && view.item.flatRows && view.item.flatRows.some(e => e.path === p))) m[p] = true;
                else changed = true;
            }
            if (changed) win.selMap = m;
        }
    }

    // ------------------------------------------------------------ opérations
    readonly property var existingNames: lister.entries.map(e => e.name)

    function newFolder() {
        if (isVirtual) return;
        const n = Fs.uniqueName(existingNames, "untitled folder", "", "");
        const p = Fs.join(path, n);
        pendingSelect = [p];
        pendingRename = true;
        Fs.mkdir(p);
    }
    function trashSelection() {
        const ps = selection.filter(e => !e.app && !e.volume).map(e => e.path);
        if (!ps.length || path === "trash://") return;
        // Sélectionne l'élément suivant (comme le Finder)
        const rows = (view.item && view.item.flatRows) ? view.item.flatRows : items;
        const last = rows.findIndex(e => e.path === ps[ps.length - 1]);
        const next = rows.slice(last + 1).find(e => !ps.includes(e.path)) ?? rows.slice(0, last).reverse().find(e => !ps.includes(e.path));
        Fs.trash(ps, code => {
            // Volume sans corbeille (tmpfs, autre système de fichiers) : comme le
            // Finder, proposer la suppression immédiate
            if (code === 0) {
                if (next) win.selectPaths([next.path]);
            } else {
                win.alertText = ps.length === 1 ? "Are you sure you want to delete \u201C" + Fs.basename(ps[0]) + "\u201D?"
                                                : "Are you sure you want to delete these " + ps.length + " items?";
                win.alertInfo = "This item will be deleted immediately. You can\u2019t undo this action.";
                win.alertButtons = [{ text: "Delete", primary: true, destructive: true, action: () => Fs.run(["rm", "-rf", "--"].concat(ps), [win.path]) },
                                    { text: "Cancel", cancel: true }];
            }
        });
        selMap = {};
    }
    function copySelection() {
        const ps = selection.filter(e => !e.app).map(e => e.path);
        if (ps.length) Fs.copyToClipboard(ps);
    }
    function paste(move) {
        if (isVirtual || !Fs.clipboard.length) return;
        Fs.transfer(Fs.clipboard, path, existingNames, move, (code, created) => {
            win.pendingSelect = created;
            if (move) Fs.clipboard = [];
        });
    }
    function duplicateSelection() {
        const ps = selection.filter(e => !e.app && !e.volume).map(e => e.path);
        if (!ps.length || isVirtual) return;
        Fs.duplicate(ps, existingNames, (code, created) => win.pendingSelect = created);
    }
    function aliasSelection() {
        const ps = selection.filter(e => !e.app && !e.volume).map(e => e.path);
        if (!ps.length || isVirtual) return;
        Fs.makeAlias(ps, existingNames, (code, created) => win.pendingSelect = created);
    }
    function compressSelection() {
        const ps = selection.filter(e => !e.app && !e.volume).map(e => e.path);
        if (!ps.length || isVirtual) return;
        Fs.compress(ps, existingNames, (code, created) => win.pendingSelect = created);
    }
    function commitRename(e, newName) {
        renamingPath = "";
        stage.forceActiveFocus();
        newName = newName.replace(/\//g, ":").trim();
        if (!newName || newName === e.name) return;
        if (existingNames.includes(newName) && newName.toLowerCase() !== e.name.toLowerCase()) {
            win.finder.alert(win, "The name “" + newName + "” is already taken. Please choose a different name.");
            return;
        }
        const to = Fs.join(Fs.dirname(e.path), newName);
        pendingSelect = [to];
        Fs.rename(e.path, to);
    }
    function startRename() {
        if (selection.length === 1 && !isVirtual && !selection[0].app) renamingPath = selection[0].path;
    }
    function toggleTag(name) {
        const ps = selection.map(e => e.path);
        if (ps.length) Fs.toggleTag(ps, name);
    }

    // Déposer des fichiers (glisser-déposer) dans destDir. Même volume ->
    // déplacer, autre volume ou ⌥ -> copier (comme le Finder).
    function dropInto(destDir, paths, forceCopy) {
        if (Fs.isVirtual(destDir) && destDir !== "trash://") {
            if (destDir.startsWith("tag://")) Fs.toggleTag(paths, destDir.slice(6));
            return;
        }
        if (destDir === "trash://") { Fs.trash(paths); return; }
        const vol = p => {
            let best = "/";
            for (const v of Fs.volumes) if ((p === v.path || p.startsWith(v.path + "/")) && v.path.length > best.length) best = v.path;
            return best;
        };
        const move = !forceCopy && paths.every(p => vol(p) === vol(destDir));
        const doIt = names => Fs.transfer(paths, destDir, names, move, (code, created) => {
            if (destDir === win.path) win.pendingSelect = created;
        });
        if (destDir === path) doIt(existingNames);
        else namesProc.run(destDir, doIt);
    }
    // Noms présents dans un autre dossier (conflits lors d'un dépôt)
    Item {
        id: namesProc
        property var cb: null
        function run(dir, cb) {
            namesLister.path = "";
            namesProc.cb = cb;
            namesLister.path = dir;
        }
        DirLister {
            id: namesLister
            watch: false
            onLoaded: if (namesProc.cb && path) { const f = namesProc.cb; namesProc.cb = null; f(entries.map(e => e.name)); }
        }
    }

    function refreshFree() {
        if (isVirtual) { freeBytes = -1; return; }
        freeProc.command = ["df", "-B1", "--output=avail", path];
        freeProc.running = true;
    }
    ProcessCollector { id: freeProc; onDone: (text) => { const l = text.trim().split("\n"); win.freeBytes = Number(l[l.length - 1]) || -1; } }

    // ------------------------------------------------------------ fenêtre
    function closeWindow() { win.finder.closeWindow(win.wid); }
    function minimizeWindow() {
        Quickshell.execDetached(["sh", "-c", "macos-wm minimize 2>/dev/null || hyprctl dispatch movetoworkspacesilent special:minimized"]);
    }
    function zoomWindow(full) {
        Quickshell.execDetached(["sh", "-c", full ? "macos-wm fullscreen 2>/dev/null || hyprctl dispatch fullscreen 0" : "hyprctl dispatch fullscreen 1"]);
    }
    onVisibleChanged: if (!visible) win.finder.closeWindow(win.wid)

    Component.onCompleted: {
        navigate(startPath, startReveal, true);
        stage.forceActiveFocus();
    }

    DirLister {
        id: lister
        path: win.path
        showHidden: win.showHidden
    }

    // ------------------------------------------------------------ clavier
    property real _homeShiftAt: 0
    function handleKey(e) {
        if (renamingPath) return false;
        const cmd = (e.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) !== 0;
        const shift = (e.modifiers & Qt.ShiftModifier) !== 0;
        const alt = (e.modifiers & Qt.AltModifier) !== 0;
        const k = e.key;
        // ⌘⌫ arrive (macos-wm kill-line) comme Maj+Début puis Retour arrière
        if (k === Qt.Key_Home && shift && !cmd) { _homeShiftAt = Date.now(); return true; }
        if ((k === Qt.Key_Backspace || k === Qt.Key_Delete) && (cmd || Date.now() - _homeShiftAt < 400)) { trashSelection(); return true; }
        if (cmd && !shift && !alt) {
            switch (k) {
            case Qt.Key_1: viewMode = "icon"; return true;
            case Qt.Key_2: viewMode = "list"; return true;
            case Qt.Key_3: viewMode = "column"; return true;
            case Qt.Key_4: viewMode = "gallery"; return true;
            case Qt.Key_A: selectAll(); return true;
            case Qt.Key_C: copySelection(); return true;
            case Qt.Key_V: paste(false); return true;
            case Qt.Key_D: duplicateSelection(); return true;
            case Qt.Key_L: aliasSelection(); return true;
            case Qt.Key_I: for (const s of selection.length ? selection : [currentFolderEntry()]) win.finder.getInfo(s); return true;
            case Qt.Key_N: win.finder.newWindow(isVirtual ? Fs.home : path); return true;
            case Qt.Key_O: openSelection(false); return true;
            case Qt.Key_Y: win.finder.toggleQuickLook(win); return true;
            case Qt.Key_F: searching = true; toolbar.focusSearch(); return true;
            case Qt.Key_W: if (tabs.length > 1) closeTab(tabIndex); else closeWindow(); return true;
            case Qt.Key_T: newTab(); return true;
            case Qt.Key_E: { const v = selection.find(x => x.volume); if (v) Fs.eject(v.path); return true; }
            case Qt.Key_BracketLeft: goBack(); return true;
            case Qt.Key_BracketRight: goForward(); return true;
            case Qt.Key_Up: goUp(); return true;
            case Qt.Key_Down: openSelection(false); return true;
            case Qt.Key_Home: goUp(); return true;          // ⌘↑ (macos-wm : Ctrl+Début)
            case Qt.Key_End: openSelection(false); return true;  // ⌘↓ (Ctrl+Fin)
            case Qt.Key_Slash: showStatusBar = !showStatusBar; return true;
            }
        }
        if (cmd && shift && !alt) {
            switch (k) {
            case Qt.Key_BracketLeft: case Qt.Key_BraceLeft: selectTab((tabIndex - 1 + tabCount) % tabCount); return true;
            case Qt.Key_BracketRight: case Qt.Key_BraceRight: selectTab((tabIndex + 1) % tabCount); return true;
            case Qt.Key_N: newFolder(); return true;
            case Qt.Key_G: win.finder.goToFolder(win); return true;
            case Qt.Key_Period: case Qt.Key_Greater: showHidden = !showHidden; return true;
            case Qt.Key_D: navigate(Fs.xdg.DESKTOP); return true;
            case Qt.Key_H: navigate(Fs.home); return true;
            case Qt.Key_A: navigate("applications://"); return true;
            case Qt.Key_O: navigate(Fs.xdg.DOCUMENTS); return true;
            case Qt.Key_F: navigate("recents://"); return true;
            case Qt.Key_C: navigate("computer://"); return true;
            case Qt.Key_K: navigate("network://"); return true;
            }
        }
        if (cmd && alt) {
            switch (k) {
            case Qt.Key_V: paste(true); return true;
            case Qt.Key_L: navigate(Fs.xdg.DOWNLOAD); return true;
            case Qt.Key_P: showPathBar = !showPathBar; return true;
            case Qt.Key_S: showSidebar = !showSidebar; return true;
            }
        }
        if ((e.modifiers & Qt.ControlModifier) && (e.modifiers & Qt.MetaModifier) && k === Qt.Key_S) { showSidebar = !showSidebar; return true; }
        // ⌘[ / ⌘] arrivent (Hyprland) comme ⌥← / ⌥→
        if (alt && !cmd && k === Qt.Key_Left) { goBack(); return true; }
        if (alt && !cmd && k === Qt.Key_Right) { goForward(); return true; }
        if (k === Qt.Key_Space && !cmd) { win.finder.toggleQuickLook(win); return true; }
        if ((k === Qt.Key_Return || k === Qt.Key_Enter) && !cmd) { startRename(); return true; }
        if (k === Qt.Key_Escape) {
            if (showGoTo) { showGoTo = false; return true; }
            if (searching) { searching = false; searchText = ""; return true; }
            return false;
        }
        if (view.item && view.item.navigate && (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_Down
                                                || k === Qt.Key_Home || k === Qt.Key_End || k === Qt.Key_PageUp || k === Qt.Key_PageDown)) {
            if (alt && (k === Qt.Key_Right || k === Qt.Key_Left) && viewMode === "list") { view.item.setExpanded(k === Qt.Key_Right, true); return true; }
            view.item.navigate(k, shift);
            return true;
        }
        if ((e.modifiers & Qt.ControlModifier) && (k === Qt.Key_Tab || k === Qt.Key_Backtab) && tabs.length > 1) {
            selectTab((tabIndex + (shift || k === Qt.Key_Backtab ? -1 : 1) + tabCount) % tabCount);
            return true;
        }
        if (k === Qt.Key_Tab) {
            const rows = (view.item && view.item.flatRows) ? view.item.flatRows : items;
            const sorted = rows.slice().sort((a, b) => _natural(a.name, b.name));
            let i = sorted.findIndex(x => x.path === cursorPath);
            i = shift || k === Qt.Key_Backtab ? i - 1 : i + 1;
            if (sorted.length) selectPaths([sorted[(i + sorted.length) % sorted.length].path]);
            return true;
        }
        if (!cmd && !alt && e.text.length === 1 && /\S/.test(e.text)) { typeSelect(e.text); return true; }
        return false;
    }

    function focusStage() { stage.forceActiveFocus(); }
    function viewItem() { return view.item; }

    // Entrée « dossier courant » (Lire les informations sans sélection)
    function currentFolderEntry() {
        return { name: Fs.displayName(path), path: path, isDir: true, size: -1, mtime: 0 };
    }

    // ------------------------------------------------------------ mise en page
    readonly property real contentX: showSidebar ? FStyle.sidebarInset + sidebarWidth : 0
    // Volet d'informations de la Galerie (pleine hauteur, barre d'outils
    // au-dessus) : 0 si la place manque
    readonly property real inspectorWidth: viewMode === "gallery" && width - contentX > 700 ? 260 : 0
    readonly property real bottomBars: (showPathBar ? FStyle.pathBarHeight : 0) + (showStatusBar ? FStyle.statusBarHeight : 0)

    // Fond réfracté par les verres : contenu de la fenêtre seulement
    Item {
        id: stage
        anchors.fill: parent
        focus: true
        // Fournisseur de fond pour LiquidGlass (backdrop "snapshot")
        property bool ready: true

        Keys.onPressed: (e) => { if (win.handleKey(e)) e.accepted = true; }

        // Fond du contenu, troué sous la plaque de la barre latérale (coins de
        // 18 pt : bord intérieur d'un anneau de rayon 2R et d'épaisseur R)
        Item {
            id: windowBg
            anchors.fill: parent
            readonly property bool holed: win.showSidebar
            readonly property real hx: FStyle.sidebarInset
            readonly property real hy: FStyle.sidebarInset
            readonly property real hw: win.sidebarWidth - FStyle.sidebarInset
            readonly property real hh: height - 2 * FStyle.sidebarInset
            readonly property real r: FStyle.sidebarRadius
            Rectangle { visible: !windowBg.holed; anchors.fill: parent; color: FStyle.contentBg }
            Rectangle { visible: windowBg.holed; width: parent.width; height: windowBg.hy; color: FStyle.contentBg }
            Rectangle { visible: windowBg.holed; y: windowBg.hy + windowBg.hh; width: parent.width; height: parent.height - y; color: FStyle.contentBg }
            Rectangle { visible: windowBg.holed; y: windowBg.hy; width: windowBg.hx; height: windowBg.hh; color: FStyle.contentBg }
            Rectangle { visible: windowBg.holed; x: windowBg.hx + windowBg.hw; y: windowBg.hy; width: parent.width - x; height: windowBg.hh; color: FStyle.contentBg }
            Rectangle {
                visible: windowBg.holed
                x: windowBg.hx - windowBg.r
                y: windowBg.hy - windowBg.r
                width: windowBg.hw + 2 * windowBg.r
                height: windowBg.hh + 2 * windowBg.r
                radius: 2 * windowBg.r
                color: "transparent"
                border.width: windowBg.r
                border.color: FStyle.contentBg
                antialiasing: true
            }
        }

        Loader {
            id: view
            // Le contenu s'arrête au bord de la barre latérale : dessous, la
            // fenêtre est transparente (flou du bureau par Hyprland)
            x: win.contentX
            clip: true
            y: 0
            width: parent.width - x
            height: parent.height - win.bottomBars
            sourceComponent: win.viewMode === "list" ? listComp
                             : win.viewMode === "column" ? columnComp
                             : win.viewMode === "gallery" ? galleryComp : iconComp
            onLoaded: {
                const s = win.selectedPaths;
                if (s.length) Qt.callLater(() => { if (view.item) view.item.ensureVisible(s[s.length - 1]); });
            }
        }

        PathBar {
            visible: win.showPathBar
            fw: win
            x: win.contentX
            width: parent.width - x
            y: parent.height - win.bottomBars
            height: FStyle.pathBarHeight
        }
        StatusBar {
            visible: win.showStatusBar
            fw: win
            x: win.contentX
            width: parent.width - x
            y: parent.height - FStyle.statusBarHeight
            height: FStyle.statusBarHeight
        }
    }

    Component { id: iconComp; IconView { fw: win } }
    Component { id: listComp; ListPresentation { fw: win } }
    Component { id: columnComp; ColumnPresentation { fw: win } }
    Component { id: galleryComp; GalleryPresentation { fw: win } }

    // Effet de bord de défilement (« soft edge ») sous la barre d'outils : le
    // contenu qui passe dessous s'estompe dans le fond de la fenêtre
    Rectangle {
        x: win.contentX
        width: parent.width - x
        height: win.chromeHeight + 10
        visible: win.viewMode !== "list"
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(FStyle.contentBg.r, FStyle.contentBg.g, FStyle.contentBg.b, 0.92) }
            GradientStop { position: 0.55; color: Qt.rgba(FStyle.contentBg.r, FStyle.contentBg.g, FStyle.contentBg.b, 0.6) }
            GradientStop { position: 1.0; color: Qt.rgba(FStyle.contentBg.r, FStyle.contentBg.g, FStyle.contentBg.b, 0) }
        }
    }

    // Glisser la fenêtre par la zone de la barre d'outils ; double-clic = Zoom
    MouseArea {
        x: win.contentX
        width: parent.width - x
        height: FStyle.toolbarHeight
        acceptedButtons: Qt.LeftButton
        onPressed: win.startSystemMove()
        onDoubleClicked: win.zoomWindow(false)
    }

    Sidebar {
        id: sidebar
        fw: win
        visible: win.showSidebar
        x: FStyle.sidebarInset
        y: FStyle.sidebarInset
        width: win.sidebarWidth - FStyle.sidebarInset
        height: parent.height - 2 * FStyle.sidebarInset
        backdropItem: stage
    }
    // Poignée de redimensionnement de la barre latérale
    MouseArea {
        visible: win.showSidebar
        x: FStyle.sidebarInset + win.sidebarWidth - FStyle.sidebarInset - 3
        y: FStyle.sidebarInset + 20
        width: 8
        height: parent.height - 2 * FStyle.sidebarInset - 40
        cursorShape: Qt.SplitHCursor
        property real startX: 0
        property real startW: 0
        onPressed: (m) => { startX = mapToItem(null, m.x, 0).x; startW = win.sidebarWidth; }
        onPositionChanged: (m) => {
            const w = startW + mapToItem(null, m.x, 0).x - startX;
            win.sidebarWidth = Math.max(150, Math.min(360, w));
        }
    }

    // Feux tricolores hors de la barre latérale quand elle est masquée
    TrafficLights {
        visible: !win.showSidebar
        x: FStyle.lightX
        y: FStyle.lightY
        active: win.active
        onCloseClicked: win.closeWindow()
        onMinimizeClicked: win.minimizeWindow()
        onZoomClicked: win.zoomWindow(true)
    }

    TabBar {
        fw: win
        visible: win.tabs.length > 1
        x: win.contentX
        y: FStyle.toolbarHeight
        width: parent.width - x
        height: win.tabBarHeight
        backdropItem: stage
    }

    SubBar {
        fw: win
        visible: win.subBar !== ""
        x: win.contentX
        y: FStyle.toolbarHeight + win.tabBarHeight
        width: parent.width - x
        height: win.subBarHeight
    }

    Toolbar {
        id: toolbar
        fw: win
        x: win.contentX
        width: parent.width - x
        height: FStyle.toolbarHeight
        backdropItem: stage
    }

    GoToFolder { fw: win }
    AlertSheet { fw: win }

    // ------------------------------------------------------------ glisser-déposer
    // Mandataire du glisser système (text/uri-list) : marche entre fenêtres du
    // Finder et vers les autres applications.
    Item {
        id: dragProxy
        width: 1
        height: 1
        property var paths: []
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
        Drag.proposedAction: Qt.MoveAction
        Drag.mimeData: ({ "text/uri-list": paths.map(p => Fs.fileUrl(p)).join("\r\n") })
        Drag.onDragFinished: (action) => win.draggingPaths = []
    }
    property var draggingPaths: []
    function beginDrag(sourceItem) {
        const ps = selection.filter(e => !e.app && !e.volume).map(e => e.path);
        if (!ps.length) return;
        dragProxy.paths = ps;
        draggingPaths = ps;
        cancelSlowRename();
        const fin = () => { dragProxy.Drag.active = true; };
        if (sourceItem && sourceItem.width > 0) {
            sourceItem.grabToImage(r => {
                dragProxy.Drag.imageSource = r.url;
                dragProxy.Drag.hotSpot = Qt.point(sourceItem.width / 2, sourceItem.height / 2);
                fin();
            });
        } else fin();
    }
    // Chemins locaux d'un dépôt (urls file://)
    function dropPaths(drop) {
        const out = [];
        for (const u of drop.urls ?? []) {
            const s = u.toString();
            if (s.startsWith("file://")) out.push(decodeURIComponent(s.slice(7)));
        }
        return out;
    }

    // ---- Débogage (banc de test) ----
    function debugSelect(names) { selectPaths(names.filter(n => n).map(n => Fs.join(path, n))); }
    function debugKey(spec) {
        // "ctrl+shift+n", "space", "return", "down"…
        if (renamingPath) { renamingPath = ""; focusStage(); }
        const parts = spec.toLowerCase().split("+");
        let mods = 0;
        const keys = { space: Qt.Key_Space, "return": Qt.Key_Return, escape: Qt.Key_Escape, up: Qt.Key_Up, down: Qt.Key_Down,
                       left: Qt.Key_Left, right: Qt.Key_Right, backspace: Qt.Key_Backspace, home: Qt.Key_Home, end: Qt.Key_End,
                       tab: Qt.Key_Tab, period: Qt.Key_Period, slash: Qt.Key_Slash, bracketleft: Qt.Key_BracketLeft };
        let key = 0, text = "";
        for (const p of parts) {
            if (p === "ctrl" || p === "cmd") mods |= Qt.ControlModifier;
            else if (p === "meta") mods |= Qt.MetaModifier;
            else if (p === "shift") mods |= Qt.ShiftModifier;
            else if (p === "alt" || p === "opt") mods |= Qt.AltModifier;
            else if (keys[p] !== undefined) key = keys[p];
            else { key = p.toUpperCase().charCodeAt(0); text = p; }
        }
        handleKey({ key: key, modifiers: mods, text: text });
    }
    function debugOverflow() { toolbar.debugOverflow(); }
    function debugScroll(dy) { if (view.item && view.item.debugScroll) view.item.debugScroll(dy); }
    function debugExpand(name) { if (view.item && view.item.toggleExpanded) view.item.toggleExpanded(Fs.join(path, name)); }
}
