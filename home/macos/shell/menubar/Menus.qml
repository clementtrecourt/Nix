import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.UPower
import qs.services

// Contenu des menus de la barre, construit à l'ouverture (libellés d'un Mac en
// anglais US, raccourcis et pictos comme dans macOS Tahoe).
//
// Un élément de menu est un objet JS :
//   { text, icon: "<symbole>", iconSource: "<url>", shortcut: ["⇧⌘", "Z"],
//     enabled: true, checked: false, minimized: false, action: function,
//     submenu: [ ... ] | function () { return [ ... ] }, handle: <menu DBus> }
//   { separator: true }            séparateur
//   { header: true, text }         intitulé de section (petit, grisé)
//   { search: true }               champ « Rechercher » du menu Aide
Item {
    id: root

    // Fenêtre et app au premier plan ("" = bureau : Finder)
    // (au démarrage, Hyprland.activeToplevel reste vide jusqu'au premier changement
    // de focus : on se rabat sur la fenêtre marquée « activated »)
    readonly property var rawWin: Windows.activeToplevel
        ?? Windows.toplevels.find(t => t.activated || t.lastIpcObject?.focusHistoryID === 0) ?? null
    // Hyprland.activeToplevel garde la dernière fenêtre quand on passe sur un
    // bureau vide (hyprctl activewindow dit pourtant « Invalid ») : une fenêtre
    // qui n'est pas sur l'espace de travail affiché (ou un espace spécial) ne
    // compte pas, le bureau (Finder) passe alors au premier plan.
    readonly property var win: {
        const w = rawWin;
        if (!w) return null;
        const ws = w.workspace;
        if (!ws || ws === Hyprland.focusedWorkspace) return w;
        // (espace spécial ouvert par-dessus, sauf celui des fenêtres placées dans le Dock)
        return (ws.name ?? "").startsWith("special:") && !Windows.isMinimized(w) ? w : null;
    }
    readonly property string cls: Windows.classOf(win)
    readonly property string appName: cls ? Apps.displayName(cls) : "Finder"
    readonly property bool isFinder: cls === ""

    // Nom complet de l'utilisateur (champ GECOS), sinon identifiant capitalisé
    property string userName: {
        const u = Quickshell.env("USER") ?? "";
        return u.charAt(0).toUpperCase() + u.slice(1);
    }

    Process {
        running: true
        command: ["sh", "-c", 'getent passwd "$USER" | cut -d: -f5 | cut -d, -f1']
        stdout: StdioCollector {
            onStreamFinished: {
                const n = text.trim();
                if (n) root.userName = n;
            }
        }
    }

    // Documents récents (GTK) pour « Recent Items »
    FileView {
        id: recentFile
        path: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/recently-used.xbel"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }

    // ---- Aides de construction ----
    function sep() { return { separator: true }; }
    function hdr(t) { return { header: true, text: t }; }
    function it(text, opts) { return Object.assign({ text: text, enabled: true }, opts ?? {}); }

    function dispatch(cmd) { Hyprland.dispatch(cmd); }
    function addr() { return win ? Windows.addressOf(win) : ""; }

    // Raccourci envoyé à la fenêtre active (Édition, Présentation).
    // Les terminaux utilisent Ctrl+Maj pour copier / coller.
    readonly property bool isTerminal: /kitty|foot|alacritty|wezterm|ghostty|terminal|konsole|xterm/i.test(cls)
    function send(mods, key) { dispatch("sendshortcut " + mods + "," + key + ",activewindow"); }

    // Géométrie utile (hors barre / Dock) du moniteur de la fenêtre active
    function workArea() {
        const m = win?.monitor ?? Hyprland.focusedMonitor;
        if (!m) return null;
        const o = m.lastIpcObject ?? {};
        const r = o.reserved ?? [0, 0, 0, 0];
        const s = m.scale || 1;
        const w = Math.round(m.width / s), h = Math.round(m.height / s);
        return { x: m.x + r[0], y: m.y + r[1], w: w - r[0] - r[2], h: h - r[1] - r[3] };
    }
    // Place la fenêtre active dans une fraction de la zone utile
    function place(fx, fy, fw, fh) { if (win) placeWin(win, fx, fy, fw, fh); }

    // Géométrie d'avant le dernier placement, par adresse de fenêtre
    // (Fenêtre > Déplacer et redimensionner > Revenir à la taille précédente)
    property var prevGeom: ({})
    function remember(t) {
        const o = t?.lastIpcObject;
        if (!o || !o.at || !o.size) return;
        const g = Object.assign({}, prevGeom);
        // (copie des valeurs : lastIpcObject est un objet vivant, mis à jour sur place)
        g[Windows.addressOf(t)] = { at: [o.at[0], o.at[1]], size: [o.size[0], o.size[1]], floating: !!o.floating };
        prevGeom = g;
    }
    function hasPrev(t) { return !!t && !!prevGeom[Windows.addressOf(t)]; }
    function restorePrev(t) {
        const a = Windows.addressOf(t), g = prevGeom[a];
        if (!g) return;
        const target = ",address:" + a;
        if (!g.floating) dispatch("settiled address:" + a);
        else {
            dispatch("resizewindowpixel exact " + g.size[0] + " " + g.size[1] + target);
            dispatch("movewindowpixel exact " + g.at[0] + " " + g.at[1] + target);
        }
        const n = Object.assign({}, prevGeom);
        delete n[a];
        prevGeom = n;
    }

    // Place une fenêtre dans une fraction de la zone utile. La barre de titre
    // hyprbars (feux tricolores) est dessinée au-dessus de la fenêtre : on
    // interroge ses décorations pour la loger dans la zone utile. Les demandes
    // passent par une file (« Disposer » place plusieurs fenêtres).
    property var placeQueue: []
    function placeWin(t, fx, fy, fw, fh) {
        const a = workArea();
        if (!a || !t) return;
        remember(t);
        placeQueue = placeQueue.concat([{ a: a, fx: fx, fy: fy, fw: fw, fh: fh, address: Windows.addressOf(t), w: t }]);
        if (!decoProbe.running) nextPlacement();
    }
    function nextPlacement() {
        if (placeQueue.length === 0) return;
        const r = placeQueue[0];
        placeQueue = placeQueue.slice(1);
        decoProbe.request = r;
        // (sans hyprctl : liste vide, pas de décalage)
        decoProbe.command = ["sh", "-c", 'hyprctl -j decorations "address:$1" 2>/dev/null || echo "[]"', "sh", r.address];
        decoProbe.running = true;
    }
    // Autres fenêtres visibles de l'espace de travail, de la plus récemment
    // active à la plus ancienne (pour « Disposer »)
    function recentOthers(w) {
        const ws = w?.workspace;
        return Windows.toplevels
            .filter(t => t !== w && t.workspace === ws && !Windows.isMinimized(t))
            .sort((x, y) => (x.lastIpcObject?.focusHistoryID ?? 99) - (y.lastIpcObject?.focusHistoryID ?? 99));
    }
    property int titlebarHeight: 32
    Process {
        running: true
        command: ["sh", "-c", "hyprctl -j getoption plugin:hyprbars:bar_height 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const o = JSON.parse(text); if (o.int > 0) root.titlebarHeight = o.int; } catch (e) {}
            }
        }
    }
    Process {
        id: decoProbe
        property var request: null
        stdout: StdioCollector {
            onStreamFinished: {
                const r = decoProbe.request;
                if (!r) return;
                let bar = 0;
                try {
                    if (JSON.parse(text).some(d => /hyprbar/i.test(d.decorationName ?? ""))) bar = root.titlebarHeight;
                } catch (e) {}
                const a = r.a, target = ",address:" + r.address;
                if (!(r.w.lastIpcObject?.floating ?? true)) root.dispatch("setfloating address:" + r.address);
                if ((r.w.lastIpcObject?.fullscreen ?? 0) !== 0) root.dispatch("fullscreenstate 0 0");
                const x = Math.round(a.x + a.w * r.fx), y = Math.round(a.y + a.h * r.fy);
                const w = Math.round(a.w * r.fw), h = Math.round(a.h * r.fh);
                root.dispatch("resizewindowpixel exact " + w + " " + (h - bar) + target);
                root.dispatch("movewindowpixel exact " + x + " " + (y + bar) + target);
            }
        }
        onExited: Qt.callLater(root.nextPlacement)
    }

    // ---- Menus ----
    function build(id) {
        switch (id) {
        case "logo": return logoMenu();
        case "app": return appMenu();
        case "file": return fileMenu();
        case "edit": return editMenu();
        case "view": return viewMenu();
        case "go": return goMenu();
        case "window": return windowMenu();
        case "help": return helpMenu();
        }
        return [];
    }

    // Titres de la barre, dans l'ordre
    function titles() {
        return [
            { id: "file", text: "File" },
            { id: "edit", text: "Edit" },
            { id: "view", text: "View" },
            ...(isFinder ? [{ id: "go", text: "Go" }] : []),
            { id: "window", text: "Window" },
            { id: "help", text: "Help" }
        ];
    }

    // Menu Apple ()
    function logoMenu() {
        // Tahoe : chaque élément du menu Apple a son picto (capture du menu
        // Apple de macOS 26, jimnielsen.com « Tahoe's icons »)
        const store = DesktopEntries.byId("org.gnome.Software");
        return [
            it("About This Mac", { icon: "laptopcomputer", action: () => ShellState.open("about") }),
            sep(),
            it("System Settings…", { icon: "gear", action: () => Apps.launch("org.gnome.Settings") }),
            it("App Store", { icon: "appstore", enabled: !!store, action: () => Apps.launch("org.gnome.Software") }),
            sep(),
            it("Recent Items", { icon: "clock", submenu: () => recentMenu() }),
            sep(),
            it("Force Quit…", { icon: "xmark.octagon", shortcut: ["⌥⌘", "⎋"], action: () => ShellState.open("forcequit") }),
            sep(),
            it("Sleep", { icon: "powersleep", action: () => Quickshell.execDetached(["systemctl", "suspend"]) }),
            it("Restart…", { icon: "restart", action: () => ShellState.open("restart") }),
            it("Shut Down…", { icon: "power", action: () => ShellState.open("shutdown") }),
            sep(),
            it("Lock Screen", { icon: "lock", shortcut: ["⌃⌘", "Q"], action: () => ShellState.open("lock") }),
            it("Log Out " + userName + "…", { icon: "person.crop.circle", shortcut: ["⇧⌘", "Q"], action: () => ShellState.open("logout") })
        ];
    }

    // Apps utilisées pendant la session, de la plus récente à la plus ancienne
    // (section « Applications » des Recent Items)
    property var recentApps: []
    onClsChanged: {
        if (!cls) return;
        recentApps = [cls].concat(recentApps.filter(c => c.toLowerCase() !== cls.toLowerCase())).slice(0, 10);
    }

    function recentMenu() {
        const out = [hdr("Applications")];
        // (apps ouvertes en tête de session : complétées par celles qui tournent)
        const apps = recentApps.concat(Windows.runningClasses.filter(c => !recentApps.some(r => r.toLowerCase() === c.toLowerCase()))).slice(0, 10);
        for (const c of apps) {
            const cc = c;
            out.push(it(Apps.displayName(c), { iconSource: Apps.icon(c), action: () => Apps.launch(cc) }));
        }

        // Documents (et dossiers) récents de GTK, avec leur type MIME
        const txt = recentFile.text() ?? "";
        const re = /<bookmark\s+href="([^"]+)"[^>]*?modified="([^"]+)"[^>]*>([\s\S]*?)<\/bookmark>/g;
        const docs = [];
        let m;
        while ((m = re.exec(txt)) !== null) {
            if (!m[1].startsWith("file://")) continue;
            const mime = /<mime:mime-type\s+type="([^"]+)"/.exec(m[3]);
            docs.push({ href: m[1], when: m[2], mime: mime ? mime[1] : "" });
        }
        docs.sort((a, b) => (a.when < b.when ? 1 : -1));
        // (« Clear Menu » : seuls les documents ouverts depuis comptent)
        const fresh = docs.filter(d => !clearedAt || d.when > clearedAt);
        out.push(sep());
        out.push(hdr("Documents"));
        const seen = {};
        let n = 0;
        for (const d of fresh) {
            if (n >= 10) break;
            if (seen[d.href]) continue;
            seen[d.href] = true;
            let name = d.href.replace(/\/$/, "").split("/").pop();
            try { name = decodeURIComponent(name); } catch (e) {}
            const href = d.href;
            out.push(it(name, {
                iconSource: mimeIconPath(d.mime, name),
                action: () => Quickshell.execDetached(["xdg-open", href])
            }));
            n++;
        }
        out.push(sep());
        out.push(hdr("Servers"));
        out.push(sep());
        out.push(it("Clear Menu", { enabled: n > 0 || apps.length > 0, action: () => root.clearRecent() }));
        return out;
    }

    // « Clear Menu » : vide les listes affichées sans toucher au fichier GTK
    // partagé avec les autres apps (horodatage ISO, comparable aux dates xbel)
    property string clearedAt: ""
    function clearRecent() {
        recentApps = [];
        clearedAt = new Date().toISOString();
    }

    // Icône de type de fichier (thème d'icônes) : type MIME exact
    // (« application/pdf » -> application-pdf), puis icône générique de la
    // famille (image-x-generic…), puis déduction par l'extension.
    function mimeIconPath(mime, name) {
        const cands = [];
        // Type inconnu (application/octet-stream) : l'extension en dit plus
        if (!mime || mime === "application/octet-stream") cands.push(extIcon(name));
        if (mime === "inode/directory") cands.push("folder");
        else if (mime) {
            cands.push(mime.replace("/", "-"));
            const major = mime.split("/")[0];
            if (["image", "audio", "video", "text", "font"].includes(major)) cands.push(major + "-x-generic");
            if (/zip|rar|tar|7z|compressed|archive/.test(mime)) cands.push("package-x-generic");
            if (/msdownload|executable|x-ms/.test(mime)) cands.push("application-x-executable");
        }
        cands.push(mimeIcon(name));
        for (const c of cands) {
            const p = Quickshell.iconPath(c, true);
            if (p) return p;
        }
        return Quickshell.iconPath("text-x-generic");
    }

    // Icône précise d'après l'extension (types que GTK enregistre souvent en
    // application/octet-stream)
    function extIcon(name) {
        const ext = (name.split(".").pop() ?? "").toLowerCase();
        const map = {
            jar: "application-x-java-archive", appimage: "application-x-appimage",
            flatpakref: "application-vnd.flatpak.ref", exe: "application-x-ms-dos-executable",
            msi: "application-x-msi", rar: "application-vnd.rar", zip: "application-zip",
            deb: "application-vnd.debian.binary-package", iso: "application-x-cd-image"
        };
        return map[ext] ?? mimeIcon(name);
    }

    // Repli d'après l'extension (fichier sans type MIME connu)
    function mimeIcon(name) {
        const ext = (name.split(".").pop() ?? "").toLowerCase();
        if (["png", "jpg", "jpeg", "webp", "gif", "svg", "heic", "avif"].includes(ext)) return "image-x-generic";
        if (ext === "pdf") return "application-pdf";
        if (["mp4", "mkv", "webm", "mov"].includes(ext)) return "video-x-generic";
        if (["mp3", "flac", "ogg", "wav", "m4a"].includes(ext)) return "audio-x-generic";
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar", "jar"].includes(ext)) return "package-x-generic";
        if (["exe", "msi"].includes(ext)) return "application-x-executable";
        return "text-x-generic";
    }

    // Menu de l'app (nom en gras)
    function appMenu() {
        const others = Windows.toplevels.filter(t => Windows.classOf(t) !== cls && !Windows.isMinimized(t));
        const hidden = Windows.toplevels.filter(t => Windows.isMinimized(t));
        const mine = cls ? Windows.windowsOf(cls) : [];
        const c = cls;
        return [
            // (pictos du menu de l'app : capture du menu Safari de macOS 26)
            it("About " + appName, { icon: "info.circle", action: () => root.showAbout(c) }),
            sep(),
            it("Settings…", {
                icon: "gear", shortcut: ["⌘", ","], enabled: !isFinder,
                action: () => send("CTRL", "comma")
            }),
            ...(isFinder ? [
                sep(),
                it("Empty Trash…", {
                    icon: "trash", shortcut: ["⇧⌘", "⌫"], enabled: trashCount > 0,
                    action: () => root.emptyTrashRequested(trashCount)
                })
            ] : []),
            sep(),
            it("Services", { icon: "gearshape.2", submenu: [it("No Services Apply", { enabled: false }), it("Services Settings…", { enabled: false })] }),
            sep(),
            it("Hide " + appName, {
                icon: "macwindow.dashed", shortcut: ["⌘", "H"], enabled: mine.length > 0,
                action: () => { for (const t of mine) Windows.minimize(t); }
            }),
            it("Hide Others", {
                icon: "macwindow.on.rectangle.dashed", shortcut: ["⌥⌘", "H"], enabled: others.length > 0,
                action: () => { for (const t of others) Windows.minimize(t); }
            }),
            it("Show All", {
                icon: "macwindow.on.rectangle.solid", enabled: hidden.length > 0,
                action: () => { for (const t of hidden) Windows.restore(t); }
            }),
            ...(isFinder ? [] : [
                sep(),
                it("Quit " + appName, { icon: "xmark.square", shortcut: ["⌘", "Q"], action: () => Windows.quitApp(c) })
            ])
        ];
    }

    function fileMenu() {
        const c = cls;
        const w = win;
        const mine = cls ? Windows.windowsOf(cls) : [];
        if (isFinder) {
            // Menu Fichier du Finder de Tahoe (Macworld, comparaison 15 / 26) ;
            // sans sélection sur le bureau, presque tout est grisé
            const off = { enabled: false };
            return [
                it("New Finder Window", { icon: "macwindow.badge.plus", shortcut: ["⌘", "N"], action: () => Quickshell.execDetached(["quickshell", "-p", Quickshell.shellDir, "ipc", "call", "finder", "newWindow"]) }),
                it("New Folder", Object.assign({ icon: "folder.badge.plus", shortcut: ["⇧⌘", "N"] }, off)),
                it("New Folder with Selection", Object.assign({ shortcut: ["⌃⌘", "N"] }, off)),
                it("New Smart Folder", off),
                it("New Tab", Object.assign({ icon: "plus.square.on.square", shortcut: ["⌘", "T"] }, off)),
                it("Open", Object.assign({ shortcut: ["⌘", "O"] }, off)),
                it("Open With", Object.assign({ submenu: [] }, off)),
                it("Close Window", Object.assign({ icon: "xmark", shortcut: ["⌘", "W"] }, off)),
                sep(),
                it("Get Info", Object.assign({ icon: "info.circle", shortcut: ["⌘", "I"] }, off)),
                it("Rename", Object.assign({ icon: "pencil" }, off)),
                it("Compress", Object.assign({ icon: "doc.zipper" }, off)),
                it("Duplicate", Object.assign({ icon: "plus.square.on.square", shortcut: ["⌘", "D"] }, off)),
                it("Make Alias", Object.assign({ shortcut: ["⌃⌘", "A"] }, off)),
                it("Quick Look", Object.assign({ icon: "eye", shortcut: ["⌘", "Y"] }, off)),
                it("Print", Object.assign({ icon: "printer", shortcut: ["⌘", "P"] }, off)),
                sep(),
                it("Share…", Object.assign({ icon: "square.and.arrow.up" }, off)),
                sep(),
                it("Show Original", Object.assign({ shortcut: ["⌘", "R"] }, off)),
                it("Add to Dock", Object.assign({ shortcut: ["⌃⇧⌘", "T"] }, off)),
                sep(),
                it("Move to Trash", Object.assign({ icon: "trash", shortcut: ["⌘", "⌫"] }, off)),
                it("Eject", Object.assign({ icon: "eject.fill", shortcut: ["⌘", "E"] }, off)),
                sep(),
                it("Tags…", Object.assign({ icon: "tag" }, off)),
                sep(),
                it("Find", { icon: "magnifyingglass", shortcut: ["⌘", "F"], action: () => ShellState.open("spotlight") })
            ];
        }
        return [
            it("New Window", { icon: "macwindow.badge.plus", shortcut: ["⌘", "N"], action: () => Apps.launch(c) }),
            it("Open…", { icon: "folder", shortcut: ["⌘", "O"], action: () => send("CTRL", "O") }),
            sep(),
            it("Close Window", { icon: "xmark", shortcut: ["⌘", "W"], enabled: !!w, action: () => Windows.close(w) }),
            it("Close All", {
                shortcut: ["⌥⌘", "W"], enabled: mine.length > 1,
                action: () => { for (const t of mine) Windows.close(t); }
            }),
            sep(),
            it("Print…", { icon: "printer", shortcut: ["⌘", "P"], action: () => send("CTRL", "P") })
        ];
    }

    function editMenu() {
        const on = !isFinder;
        const cm = isTerminal ? "CTRL SHIFT" : "CTRL";
        return [
            it("Undo", { icon: "arrow.uturn.backward", shortcut: ["⌘", "Z"], enabled: on, action: () => send("CTRL", "Z") }),
            it("Redo", { icon: "arrow.uturn.forward", shortcut: ["⇧⌘", "Z"], enabled: on, action: () => send("CTRL SHIFT", "Z") }),
            sep(),
            it("Cut", { icon: "scissors", shortcut: ["⌘", "X"], enabled: on, action: () => send(cm, "X") }),
            it("Copy", { icon: "doc.on.doc", shortcut: ["⌘", "C"], enabled: on, action: () => send(cm, "C") }),
            it("Paste", { icon: "doc.on.clipboard", shortcut: ["⌘", "V"], enabled: on, action: () => send(cm, "V") }),
            ...(isFinder ? [] : [it("Delete", { icon: "trash", enabled: on, action: () => send("", "Delete") })]),
            it("Select All", { icon: "character.textbox", shortcut: ["⌘", "A"], enabled: on, action: () => send(cm, "A") }),
            sep(),
            // (Finder : presse-papiers au lieu de Rechercher)
            ...(isFinder ? [it("Show Clipboard", { icon: "doc.on.clipboard", enabled: false })] : [it("Find", {
                icon: "magnifyingglass", enabled: on, submenu: [
                    it("Find…", { shortcut: ["⌘", "F"], action: () => send("CTRL", "F") }),
                    it("Find Next", { shortcut: ["⌘", "G"], action: () => send("CTRL", "G") }),
                    it("Find Previous", { shortcut: ["⇧⌘", "G"], action: () => send("CTRL SHIFT", "G") })
                ]
            })]),
            sep(),
            it("AutoFill", { enabled: false }),
            it("Start Dictation…", { enabled: false }),
            it("Emoji & Symbols", { icon: "globe", shortcut: ["", "🌐E"], enabled: false })
        ];
    }

    // Présentation du Finder (bureau au premier plan) : options d'affichage,
    // sans objet ici sauf « Show View Options » absent : tout est grisé
    function finderViewMenu() {
        const off = { enabled: false };
        return [
            it("as Icons", Object.assign({ icon: "square.grid.2x2", shortcut: ["⌘", "1"] }, off)),
            it("as List", Object.assign({ icon: "list.bullet", shortcut: ["⌘", "2"] }, off)),
            it("as Columns", Object.assign({ shortcut: ["⌘", "3"] }, off)),
            it("as Gallery", Object.assign({ shortcut: ["⌘", "4"] }, off)),
            sep(),
            it("Use Stacks", { shortcut: ["⌃⌘", "0"], enabled: false }),
            it("Sort By", { submenu: [], enabled: false }),
            it("Clean Up", { enabled: false }),
            it("Clean Up By", { submenu: [], enabled: false }),
            sep(),
            it("Hide Sidebar", { shortcut: ["⌃⌘", "S"], enabled: false }),
            it("Show Preview", { shortcut: ["⇧⌘", "P"], enabled: false }),
            sep(),
            it("Hide Toolbar", { shortcut: ["⌥⌘", "T"], enabled: false }),
            it("Show All Tabs", { shortcut: ["⇧⌘", "\\"], enabled: false }),
            it("Show Tab Bar", { shortcut: ["⇧⌘", "T"], enabled: false }),
            it("Show Path Bar", { shortcut: ["⌥⌘", "P"], enabled: false }),
            it("Show Status Bar", { shortcut: ["⌘", "/"], enabled: false }),
            sep(),
            it("Customize Toolbar…", { enabled: false }),
            sep(),
            it("Show View Options", { shortcut: ["⌘", "J"], enabled: false }),
            sep(),
            it("Enter Full Screen", { icon: "arrow.up.left.and.arrow.down.right", shortcut: ["", "🌐F"], enabled: false })
        ];
    }

    function viewMenu() {
        if (isFinder) return finderViewMenu();
        const on = !isFinder;
        const fs = (win?.lastIpcObject?.fullscreen ?? 0) === 2;
        return [
            it("Show Tab Bar", { enabled: false }),
            it("Show All Tabs", { shortcut: ["⇧⌘", "\\"], enabled: false }),
            sep(),
            it("Zoom In", { icon: "plus.magnifyingglass", shortcut: ["⌘", "+"], enabled: on, action: () => send(isTerminal ? "CTRL SHIFT" : "CTRL", "equal") }),
            it("Zoom Out", { icon: "minus.magnifyingglass", shortcut: ["⌘", "-"], enabled: on, action: () => send(isTerminal ? "CTRL SHIFT" : "CTRL", "minus") }),
            it("Actual Size", { shortcut: ["⌘", "0"], enabled: on, action: () => send(isTerminal ? "CTRL SHIFT" : "CTRL", "0") }),
            sep(),
            it(fs ? "Exit Full Screen" : "Enter Full Screen", {
                icon: "arrow.up.left.and.arrow.down.right", shortcut: ["", "🌐F"], enabled: !!win,
                action: () => dispatch("fullscreen 0")
            })
        ];
    }

    // Disposer : fenêtre active dans la 1re case, les précédentes dans les suivantes
    function arrange(cells) {
        const w = win;
        if (!w) return;
        const list = [w].concat(recentOthers(w));
        for (let i = 0; i < cells.length && i < list.length; i++)
            placeWin(list[i], cells[i][0], cells[i][1], cells[i][2], cells[i][3]);
        Windows.focus(w);
    }

    // Dossier utilisateur XDG (Documents, Desktop…) ouvert dans le gestionnaire de fichiers
    function openUserDir(kind) {
        Quickshell.execDetached(["sh", "-c", 'xdg-open "$(xdg-user-dir "$1" 2>/dev/null || echo "$HOME")"', "sh", kind]);
    }
    function openPath(path) { Quickshell.execDetached(["xdg-open", path]); }

    // Aller (barre du Finder, c.-à-d. quand le bureau est au premier plan)
    function goMenu() {
        const home = Quickshell.env("HOME");
        return [
            it("Back", { shortcut: ["⌘", "["], enabled: false }),
            it("Forward", { shortcut: ["⌘", "]"], enabled: false }),
            it("Enclosing Folder", { shortcut: ["⌘", "↑"], enabled: false }),
            sep(),
            it("Recents", { icon: "clock", shortcut: ["⇧⌘", "F"], action: () => openPath("recent:///") }),
            it("Documents", { icon: "doc", shortcut: ["⇧⌘", "O"], action: () => openUserDir("DOCUMENTS") }),
            it("Desktop", { icon: "menubar.dock.rectangle", shortcut: ["⇧⌘", "D"], action: () => openUserDir("DESKTOP") }),
            it("Downloads", { icon: "arrow.down.circle", shortcut: ["⌥⌘", "L"], action: () => openUserDir("DOWNLOAD") }),
            it("Home", { icon: "house", shortcut: ["⇧⌘", "H"], action: () => openPath(home) }),
            it("Computer", { icon: "desktopcomputer", shortcut: ["⇧⌘", "C"], action: () => openPath("computer:///") }),
            it("AirDrop", { icon: "airdrop", shortcut: ["⇧⌘", "R"], enabled: false }),
            it("Network", { icon: "network", shortcut: ["⇧⌘", "K"], action: () => openPath("network:///") }),
            it("iCloud Drive", { icon: "icloud", shortcut: ["⇧⌘", "I"], enabled: false }),
            it("Applications", { icon: "square.grid.3x3", shortcut: ["⇧⌘", "A"], action: () => ShellState.open("apps") }),
            it("Utilities", { icon: "wrench.and.screwdriver", shortcut: ["⇧⌘", "U"], enabled: false }),
            sep(),
            it("Recent Folders", { submenu: () => recentFolders() }),
            sep(),
            it("Go to Folder…", { shortcut: ["⇧⌘", "G"], action: () => ShellState.open("spotlight") }),
            it("Connect to Server…", { shortcut: ["⌘", "K"], enabled: false })
        ];
    }

    // Dossiers des documents récents (GTK), sans doublon
    function recentFolders() {
        const txt = recentFile.text() ?? "";
        const re = /<bookmark\s+href="(file:\/\/[^"]+)"[^>]*?modified="([^"]+)"/g;
        const dirs = [];
        let m;
        while ((m = re.exec(txt)) !== null) {
            const dir = m[1].replace(/\/[^/]*$/, "");
            dirs.push({ dir: dir, when: m[2] });
        }
        dirs.sort((a, b) => (a.when < b.when ? 1 : -1));
        const out = [];
        const seen = {};
        for (const d of dirs) {
            if (out.length >= 10) break;
            if (seen[d.dir]) continue;
            seen[d.dir] = true;
            let name = d.dir.split("/").pop();
            try { name = decodeURIComponent(name); } catch (e) {}
            const dir = d.dir;
            out.push(it(name, { iconSource: Quickshell.iconPath("folder"), action: () => openPath(dir) }));
        }
        if (out.length) out.push(sep());
        out.push(it("Clear Menu", { enabled: out.length > 0, action: () => root.clearRecent() }));
        return out;
    }

    function windowMenu() {
        const w = win;
        const has = !!w;
        const others = recentOthers(w);
        const mine = cls ? Windows.windowsOf(cls) : [];
        const out = [
            it("Minimize", { icon: "minus.rectangle", shortcut: ["⌘", "M"], enabled: has, action: () => Windows.minimize(w) }),
            it("Zoom", { icon: "viewfinder.rectangle", enabled: has, action: () => dispatch("fullscreen 1") }),
            it("Fill", { icon: "rectangle.inset.filled", shortcut: ["⌃", "🌐F"], enabled: has, action: () => place(0, 0, 1, 1) }),
            it("Center", { icon: "rectangle.center.inset.filled", shortcut: ["⌃", "🌐C"], enabled: has, action: () => dispatch("centerwindow 1") }),
            sep(),
            it("Move & Resize", {
                icon: "rectangle.lefthalf.inset.filled", enabled: has, submenu: [
                    // (flèches pleines ◀ ▶ ▲ ▼ comme sur Tahoe : ⌃ 🌐 ◀)
                    hdr("Halves"),
                    it("Left", { icon: "rectangle.lefthalf.inset.filled", shortcut: ["⌃", "🌐◀"], action: () => place(0, 0, 0.5, 1) }),
                    it("Right", { icon: "rectangle.righthalf.inset.filled", shortcut: ["⌃", "🌐▶"], action: () => place(0.5, 0, 0.5, 1) }),
                    it("Top", { icon: "rectangle.tophalf.inset.filled", shortcut: ["⌃", "🌐▲"], action: () => place(0, 0, 1, 0.5) }),
                    it("Bottom", { icon: "rectangle.bottomhalf.inset.filled", shortcut: ["⌃", "🌐▼"], action: () => place(0, 0.5, 1, 0.5) }),
                    sep(),
                    hdr("Quarters"),
                    it("Top Left", { icon: "rectangle.inset.topleft.filled", action: () => place(0, 0, 0.5, 0.5) }),
                    it("Top Right", { icon: "rectangle.inset.topright.filled", action: () => place(0.5, 0, 0.5, 0.5) }),
                    it("Bottom Left", { icon: "rectangle.inset.bottomleft.filled", action: () => place(0, 0.5, 0.5, 0.5) }),
                    it("Bottom Right", { icon: "rectangle.inset.bottomright.filled", action: () => place(0.5, 0.5, 0.5, 0.5) }),
                    sep(),
                    // Disposer : la fenêtre active et la (les) précédente(s)
                    hdr("Arrange"),
                    it("Left & Right", { icon: "rectangle.split.leftright", shortcut: ["⌃⇧", "🌐◀"], enabled: others.length > 0, action: () => arrange([[0, 0, 0.5, 1], [0.5, 0, 0.5, 1]]) }),
                    it("Right & Left", { icon: "rectangle.split.rightleft", shortcut: ["⌃⇧", "🌐▶"], enabled: others.length > 0, action: () => arrange([[0.5, 0, 0.5, 1], [0, 0, 0.5, 1]]) }),
                    it("Top & Bottom", { icon: "rectangle.split.topbottom", shortcut: ["⌃⇧", "🌐▲"], enabled: others.length > 0, action: () => arrange([[0, 0, 1, 0.5], [0, 0.5, 1, 0.5]]) }),
                    it("Bottom & Top", { icon: "rectangle.split.bottomtop", shortcut: ["⌃⇧", "🌐▼"], enabled: others.length > 0, action: () => arrange([[0, 0.5, 1, 0.5], [0, 0, 1, 0.5]]) }),
                    it("Quarters", { icon: "rectangle.split.2x2.filled", enabled: others.length > 0, action: () => arrange([[0, 0, 0.5, 0.5], [0.5, 0, 0.5, 0.5], [0, 0.5, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]]) }),
                    sep(),
                    it("Return to Previous Size", { shortcut: ["⌃", "🌐R"], enabled: hasPrev(w), action: () => restorePrev(w) })
                ]
            }),
            it("Full Screen Tile", {
                icon: "rectangle.split.leftright", enabled: has, submenu: [
                    it("Left of Screen", { icon: "rectangle.lefthalf.inset.filled", action: () => place(0, 0, 0.5, 1) }),
                    it("Right of Screen", { icon: "rectangle.righthalf.inset.filled", action: () => place(0.5, 0, 0.5, 1) })
                ]
            }),
            sep(),
            it("Remove Window from Set", { icon: "rectangle.3.group", enabled: false }),
            sep(),
            // ⌘` : fenêtre suivante de la même app
            it("Cycle Through Windows", {
                icon: "arrow.left.arrow.right", shortcut: ["⌘", "`"], enabled: mine.length > 1,
                action: () => {
                    const vis = mine.filter(t => !Windows.isMinimized(t));
                    const k = vis.indexOf(w);
                    if (vis.length > 1) Windows.focus(vis[(k + 1) % vis.length]);
                }
            }),
            sep(),
            it("Bring All to Front", {
                icon: "square.stack.3d.up", enabled: mine.length > 0,
                action: () => {
                    for (const t of mine) {
                        if (Windows.isMinimized(t)) Windows.restore(t);
                        else dispatch("alterzorder top,address:" + Windows.addressOf(t));
                    }
                    if (w) Windows.focus(w);
                }
            })
        ];
        if (mine.length > 0) {
            out.push(sep());
            for (const t of mine) {
                const tt = t;
                out.push(it(t.title || appName, {
                    icon: "macwindow", checked: t === w,
                    minimized: Windows.isMinimized(t),
                    action: () => Windows.focus(tt)
                }));
            }
        }
        return out;
    }

    function helpMenu() {
        return [
            { search: true, provider: () => root.searchable() },
            it(isFinder ? "macOS Help" : appName + " Help", { enabled: false })
        ];
    }

    // ---- Menus des icônes d'état ----

    // Batterie : « Battery   85% », source d'alimentation, réglages
    function batteryMenu(dev) {
        const pct = Math.round((dev?.percentage ?? 0) * 100) + "%";
        const st = dev?.state;
        const onAC = dev?.demo ? false : !UPower.onBattery;
        let src = onAC ? "Power Adapter" : "Battery";
        // (macOS n'affiche plus le temps restant dans ce menu depuis 10.12.2)
        let note = "";
        if (st === UPowerDeviceState.FullyCharged) note = "Battery Is Charged";
        const out = [
            it("Battery", { info: true, bold: true, pathText: pct }),
            it("Power Source: " + src, { info: true, secondary: true })
        ];
        if (note) out.push(it(note, { info: true, secondary: true }));
        out.push(sep());
        out.push(it("Low Power Mode", {
            toggle: PowerProfiles.profile === PowerProfile.PowerSaver,
            keepOpen: true,
            action: () => {
                PowerProfiles.profile = PowerProfiles.profile === PowerProfile.PowerSaver
                    ? PowerProfile.Balanced : PowerProfile.PowerSaver;
            }
        }));
        out.push(sep());
        out.push(it("Battery Settings…", { action: () => ShellState.open("controlcenter") }));
        return out;
    }

    // Wi-Fi : interrupteur, réseau actuel, réseaux connus, autres réseaux
    function wifiMenu(device, current) {
        const on = Networking.wifiEnabled;
        const out = [
            it("Wi-Fi", {
                bold: true, toggle: on, keepOpen: true,
                action: () => { Networking.wifiEnabled = !Networking.wifiEnabled; }
            })
        ];
        if (on && device) {
            const nets = (device.networks?.values ?? []).filter(n => n.name);
            const level = n => {
                const s = n.signalStrength ?? 0;
                return s > 0.6 ? 3 : s > 0.3 ? 2 : 1;
            };
            const secure = n => n.security !== undefined && n.security !== WifiSecurityType.Open;
            const row = n => it(n.name, {
                network: true, wifiLevel: level(n), connected: n.connected, locked: secure(n),
                action: () => { if (!n.connected) n.connect(); }
            });
            if (current) {
                out.push(sep());
                out.push(row(current));
            }
            const known = nets.filter(n => n.known && !n.connected)
                .sort((a, b) => (b.signalStrength ?? 0) - (a.signalStrength ?? 0));
            if (known.length) {
                out.push(sep());
                out.push(hdr("Known Networks"));
                for (const n of known.slice(0, 6)) out.push(row(n));
            }
            const others = nets.filter(n => !n.known && !n.connected)
                .sort((a, b) => (b.signalStrength ?? 0) - (a.signalStrength ?? 0));
            out.push(sep());
            // Section dépliable sur place (chevron qui pivote), pas un sous-menu
            out.push(it("Other Networks", {
                disclosure: true,
                children: others.length ? others.slice(0, 12).map(row) : [it("No Networks Found", { enabled: false })]
            }));
        }
        out.push(sep());
        out.push(it("Wi-Fi Settings…", { action: () => ShellState.open("controlcenter") }));
        return out;
    }

    // Tous les éléments actionnables des menus de l'app (recherche du menu Aide)
    function searchable() {
        const out = [];
        const walk = (list, path) => {
            for (const e of list) {
                if (!e || e.separator || e.header || e.search) continue;
                if (e.enabled === false) continue;
                if (Array.isArray(e.submenu)) walk(e.submenu, path.concat([e.text]));
                else if (typeof e.action === "function" && e.enabled !== false) out.push(Object.assign({}, e, { path: path }));
            }
        };
        const names = [["app", appName], ["file", "File"], ["edit", "Edit"], ["view", "View"]]
            .concat(isFinder ? [["go", "Go"]] : []).concat([["window", "Window"]]);
        for (const n of names) walk(build(n[0]), [n[1]]);
        return out;
    }

    // « About <App> » : petit panneau du composant (AppAbout.qml)
    signal aboutRequested(string cls)
    // « Empty Trash… » : alerte de confirmation (Alert.qml)
    signal emptyTrashRequested(int count)

    // Nombre d'éléments dans la corbeille (rafraîchi à l'ouverture des menus)
    property int trashCount: 0
    Process {
        id: trashProbe
        command: ["sh", "-c", 'ls -A "${XDG_DATA_HOME:-$HOME/.local/share}/Trash/files" 2>/dev/null | wc -l']
        stdout: StdioCollector {
            onStreamFinished: root.trashCount = parseInt(text.trim()) || 0
        }
    }
    function refreshTrash() { if (!trashProbe.running) trashProbe.running = true; }
    Component.onCompleted: refreshTrash()
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.refreshTrash()
    }
    function showAbout(c) { root.aboutRequested(c); }
}
