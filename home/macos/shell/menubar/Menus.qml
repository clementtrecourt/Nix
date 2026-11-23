import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.UPower
import qs.services

// Contenu des menus de la barre, construit à l'ouverture (libellés d'un Mac en
// français, raccourcis et pictos comme dans macOS Tahoe).
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
    readonly property string appName: cls ? Apps.name(cls) : "Finder"
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

    // Documents récents (GTK) pour « Éléments récents »
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
            { id: "file", text: "Fichier" },
            { id: "edit", text: "Édition" },
            { id: "view", text: "Présentation" },
            ...(isFinder ? [{ id: "go", text: "Aller" }] : []),
            { id: "window", text: "Fenêtre" },
            { id: "help", text: "Aide" }
        ];
    }

    // Menu  (ici le flocon NixOS)
    function logoMenu() {
        return [
            it("À propos de ce Mac", { action: () => ShellState.open("about") }),
            sep(),
            it("Réglages Système…", { action: () => Apps.launch("org.gnome.Settings") }),
            it("App Store…", { enabled: false }),
            sep(),
            it("Éléments récents", { submenu: () => recentMenu() }),
            sep(),
            it("Forcer à quitter…", { shortcut: ["⌥⌘", "⎋"], action: () => ShellState.open("forcequit") }),
            sep(),
            it("Suspendre", { action: () => Quickshell.execDetached(["systemctl", "suspend"]) }),
            it("Redémarrer…", { action: () => ShellState.open("restart") }),
            it("Éteindre…", { action: () => ShellState.open("shutdown") }),
            sep(),
            it("Verrouiller l’écran", { shortcut: ["⌃⌘", "Q"], action: () => ShellState.open("lock") }),
            it("Fermer la session de " + userName + "…", { shortcut: ["⇧⌘", "Q"], action: () => ShellState.open("logout") })
        ];
    }

    // Apps utilisées pendant la session, de la plus récente à la plus ancienne
    // (section « Applications » des Éléments récents)
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
            out.push(it(Apps.name(c), { iconSource: Apps.icon(c), action: () => Apps.launch(cc) }));
        }
        if (apps.length === 0) out.push(it("Aucun élément", { enabled: false }));

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
        out.push(sep());
        out.push(hdr("Documents"));
        const seen = {};
        let n = 0;
        for (const d of docs) {
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
        if (n === 0) out.push(it("Aucun élément", { enabled: false }));
        out.push(sep());
        out.push(it("Effacer le menu", { enabled: false }));
        return out;
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
            // (un Mac en français dit « À propos du Finder »)
            it(isFinder ? "À propos du Finder" : "À propos de " + appName, { icon: "info.circle", action: () => root.showAbout(c) }),
            sep(),
            it("Réglages…", {
                icon: "gearshape", shortcut: ["⌘", ","], enabled: !isFinder,
                action: () => send("CTRL", "comma")
            }),
            ...(isFinder ? [
                sep(),
                it("Vider la corbeille…", {
                    icon: "trash", shortcut: ["⇧⌘", "⌫"], enabled: trashCount > 0,
                    action: () => root.emptyTrashRequested(trashCount)
                })
            ] : []),
            sep(),
            it("Services", { submenu: [it("Aucun service ne s’applique", { enabled: false }), sep(), it("Préférences des services…", { enabled: false })] }),
            sep(),
            it("Masquer " + appName, {
                icon: "eye.slash", shortcut: ["⌘", "H"], enabled: mine.length > 0,
                action: () => { for (const t of mine) Windows.minimize(t); }
            }),
            it("Masquer les autres", {
                shortcut: ["⌥⌘", "H"], enabled: others.length > 0,
                action: () => { for (const t of others) Windows.minimize(t); }
            }),
            it("Tout afficher", {
                enabled: hidden.length > 0,
                action: () => { for (const t of hidden) Windows.restore(t); }
            }),
            ...(isFinder ? [] : [
                sep(),
                it("Quitter " + appName, { icon: "xmark.rectangle", shortcut: ["⌘", "Q"], action: () => Windows.quitApp(c) })
            ])
        ];
    }

    function fileMenu() {
        const c = cls;
        const w = win;
        const mine = cls ? Windows.windowsOf(cls) : [];
        if (isFinder) {
            return [
                it("Nouvelle fenêtre Finder", { icon: "macwindow.badge.plus", shortcut: ["⌘", "N"], action: () => Apps.launch("nemo") }),
                it("Nouveau dossier", { icon: "folder.badge.plus", shortcut: ["⇧⌘", "N"], enabled: false }),
                it("Ouvrir", { shortcut: ["⌘", "O"], enabled: false }),
                sep(),
                it("Fermer la fenêtre", { icon: "xmark", shortcut: ["⌘", "W"], enabled: false })
            ];
        }
        return [
            it("Nouvelle fenêtre", { icon: "macwindow.badge.plus", shortcut: ["⌘", "N"], action: () => Apps.launch(c) }),
            it("Ouvrir…", { icon: "folder", shortcut: ["⌘", "O"], action: () => send("CTRL", "O") }),
            sep(),
            it("Fermer la fenêtre", { icon: "xmark", shortcut: ["⌘", "W"], enabled: !!w, action: () => Windows.close(w) }),
            it("Tout fermer", {
                shortcut: ["⌥⌘", "W"], enabled: mine.length > 1,
                action: () => { for (const t of mine) Windows.close(t); }
            }),
            sep(),
            it("Imprimer…", { icon: "printer", shortcut: ["⌘", "P"], action: () => send("CTRL", "P") })
        ];
    }

    function editMenu() {
        const on = !isFinder;
        const cm = isTerminal ? "CTRL SHIFT" : "CTRL";
        return [
            it("Annuler", { icon: "arrow.uturn.backward", shortcut: ["⌘", "Z"], enabled: on, action: () => send("CTRL", "Z") }),
            it("Rétablir", { icon: "arrow.uturn.forward", shortcut: ["⇧⌘", "Z"], enabled: on, action: () => send("CTRL SHIFT", "Z") }),
            sep(),
            it("Couper", { icon: "scissors", shortcut: ["⌘", "X"], enabled: on, action: () => send(cm, "X") }),
            it("Copier", { icon: "doc.on.doc", shortcut: ["⌘", "C"], enabled: on, action: () => send(cm, "C") }),
            it("Coller", { icon: "doc.on.clipboard", shortcut: ["⌘", "V"], enabled: on, action: () => send(cm, "V") }),
            it("Supprimer", { icon: "trash", enabled: on, action: () => send("", "Delete") }),
            it("Tout sélectionner", { icon: "character.textbox", shortcut: ["⌘", "A"], enabled: on, action: () => send(cm, "A") }),
            sep(),
            it("Rechercher", {
                icon: "magnifyingglass", enabled: on, submenu: [
                    it("Rechercher…", { shortcut: ["⌘", "F"], action: () => send("CTRL", "F") }),
                    it("Rechercher le suivant", { shortcut: ["⌘", "G"], action: () => send("CTRL", "G") }),
                    it("Rechercher le précédent", { shortcut: ["⇧⌘", "G"], action: () => send("CTRL SHIFT", "G") })
                ]
            }),
            sep(),
            it("Recopie automatique", { enabled: false }),
            it("Démarrer la dictée…", { enabled: false }),
            it("Emoji et symboles", { icon: "globe", shortcut: ["", "🌐E"], enabled: false })
        ];
    }

    function viewMenu() {
        const on = !isFinder;
        const fs = (win?.lastIpcObject?.fullscreen ?? 0) === 2;
        return [
            it("Afficher la barre d’onglets", { enabled: false }),
            it("Afficher tous les onglets", { shortcut: ["⇧⌘", "\\"], enabled: false }),
            sep(),
            it("Agrandir", { icon: "plus.magnifyingglass", shortcut: ["⌘", "+"], enabled: on, action: () => send(isTerminal ? "CTRL SHIFT" : "CTRL", "equal") }),
            it("Réduire", { icon: "minus.magnifyingglass", shortcut: ["⌘", "-"], enabled: on, action: () => send(isTerminal ? "CTRL SHIFT" : "CTRL", "minus") }),
            it("Taille réelle", { shortcut: ["⌘", "0"], enabled: on, action: () => send(isTerminal ? "CTRL SHIFT" : "CTRL", "0") }),
            sep(),
            it(fs ? "Quitter le mode plein écran" : "Passer en mode plein écran", {
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

    // Dossier utilisateur XDG (Documents, Bureau…) ouvert dans le gestionnaire de fichiers
    function openUserDir(kind) {
        Quickshell.execDetached(["sh", "-c", 'xdg-open "$(xdg-user-dir "$1" 2>/dev/null || echo "$HOME")"', "sh", kind]);
    }
    function openPath(path) { Quickshell.execDetached(["xdg-open", path]); }

    // Aller (barre du Finder, c.-à-d. quand le bureau est au premier plan)
    function goMenu() {
        const home = Quickshell.env("HOME");
        return [
            it("Précédent", { shortcut: ["⌘", "["], enabled: false }),
            it("Suivant", { shortcut: ["⌘", "]"], enabled: false }),
            it("Dossier parent", { shortcut: ["⌘", "↑"], enabled: false }),
            sep(),
            it("Récents", { icon: "clock", shortcut: ["⇧⌘", "F"], action: () => openPath("recent:///") }),
            it("Documents", { icon: "doc", shortcut: ["⇧⌘", "O"], action: () => openUserDir("DOCUMENTS") }),
            it("Bureau", { icon: "menubar.dock.rectangle", shortcut: ["⇧⌘", "D"], action: () => openUserDir("DESKTOP") }),
            it("Téléchargements", { icon: "arrow.down.circle", shortcut: ["⌥⌘", "L"], action: () => openUserDir("DOWNLOAD") }),
            it("Départ", { icon: "house", shortcut: ["⇧⌘", "H"], action: () => openPath(home) }),
            it("Ordinateur", { icon: "desktopcomputer", shortcut: ["⇧⌘", "C"], action: () => openPath("computer:///") }),
            it("AirDrop", { icon: "airdrop", shortcut: ["⇧⌘", "R"], enabled: false }),
            it("Réseau", { icon: "network", shortcut: ["⇧⌘", "K"], action: () => openPath("network:///") }),
            it("iCloud Drive", { icon: "icloud", shortcut: ["⇧⌘", "I"], enabled: false }),
            it("Applications", { icon: "square.grid.3x3", shortcut: ["⇧⌘", "A"], action: () => ShellState.open("apps") }),
            it("Utilitaires", { icon: "wrench.and.screwdriver", shortcut: ["⇧⌘", "U"], enabled: false }),
            sep(),
            it("Dossiers récents", { submenu: () => recentFolders() }),
            sep(),
            it("Aller au dossier…", { shortcut: ["⇧⌘", "G"], action: () => ShellState.open("spotlight") }),
            it("Se connecter au serveur…", { shortcut: ["⌘", "K"], enabled: false })
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
        if (out.length === 0) out.push(it("Aucun élément", { enabled: false }));
        out.push(sep());
        out.push(it("Effacer le menu", { enabled: false }));
        return out;
    }

    function windowMenu() {
        const w = win;
        const has = !!w;
        const others = recentOthers(w);
        const mine = cls ? Windows.windowsOf(cls) : [];
        const out = [
            it("Placer dans le Dock", { icon: "minus.rectangle", shortcut: ["⌘", "M"], enabled: has, action: () => Windows.minimize(w) }),
            it("Zoom", { icon: "plus.rectangle", enabled: has, action: () => dispatch("fullscreen 1") }),
            sep(),
            it("Remplir", { icon: "rectangle.inset.filled", shortcut: ["⌃", "🌐F"], enabled: has, action: () => place(0, 0, 1, 1) }),
            it("Centrer", { icon: "rectangle.center.inset.filled", shortcut: ["⌃", "🌐C"], enabled: has, action: () => dispatch("centerwindow 1") }),
            sep(),
            it("Déplacer et redimensionner", {
                icon: "rectangle.lefthalf.inset.filled", enabled: has, submenu: [
                    // (flèches pleines ◀ ▶ ▲ ▼ comme sur Tahoe : ⌃ 🌐 ◀)
                    hdr("Moitiés"),
                    it("Gauche", { icon: "rectangle.lefthalf.inset.filled", shortcut: ["⌃", "🌐◀"], action: () => place(0, 0, 0.5, 1) }),
                    it("Droite", { icon: "rectangle.righthalf.inset.filled", shortcut: ["⌃", "🌐▶"], action: () => place(0.5, 0, 0.5, 1) }),
                    it("Haut", { icon: "rectangle.tophalf.inset.filled", shortcut: ["⌃", "🌐▲"], action: () => place(0, 0, 1, 0.5) }),
                    it("Bas", { icon: "rectangle.bottomhalf.inset.filled", shortcut: ["⌃", "🌐▼"], action: () => place(0, 0.5, 1, 0.5) }),
                    sep(),
                    hdr("Quarts"),
                    it("En haut à gauche", { icon: "rectangle.inset.topleft.filled", action: () => place(0, 0, 0.5, 0.5) }),
                    it("En haut à droite", { icon: "rectangle.inset.topright.filled", action: () => place(0.5, 0, 0.5, 0.5) }),
                    it("En bas à gauche", { icon: "rectangle.inset.bottomleft.filled", action: () => place(0, 0.5, 0.5, 0.5) }),
                    it("En bas à droite", { icon: "rectangle.inset.bottomright.filled", action: () => place(0.5, 0.5, 0.5, 0.5) }),
                    sep(),
                    // Disposer : la fenêtre active et la (les) précédente(s)
                    hdr("Disposer"),
                    it("Gauche et droite", { icon: "rectangle.split.leftright", shortcut: ["⌃⇧", "🌐◀"], enabled: others.length > 0, action: () => arrange([[0, 0, 0.5, 1], [0.5, 0, 0.5, 1]]) }),
                    it("Droite et gauche", { icon: "rectangle.split.rightleft", shortcut: ["⌃⇧", "🌐▶"], enabled: others.length > 0, action: () => arrange([[0.5, 0, 0.5, 1], [0, 0, 0.5, 1]]) }),
                    it("Haut et bas", { icon: "rectangle.split.topbottom", shortcut: ["⌃⇧", "🌐▲"], enabled: others.length > 0, action: () => arrange([[0, 0, 1, 0.5], [0, 0.5, 1, 0.5]]) }),
                    it("Bas et haut", { icon: "rectangle.split.bottomtop", shortcut: ["⌃⇧", "🌐▼"], enabled: others.length > 0, action: () => arrange([[0, 0.5, 1, 0.5], [0, 0, 1, 0.5]]) }),
                    it("Quarts", { icon: "rectangle.split.2x2.filled", enabled: others.length > 0, action: () => arrange([[0, 0, 0.5, 0.5], [0.5, 0, 0.5, 0.5], [0, 0.5, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]]) }),
                    sep(),
                    it("Revenir à la taille précédente", { shortcut: ["⌃", "🌐R"], enabled: hasPrev(w), action: () => restorePrev(w) })
                ]
            }),
            sep(),
            it("Tout ramener au premier plan", {
                enabled: mine.length > 0,
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
                    checked: t === w,
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
            it("Aide " + appName, { enabled: false })
        ];
    }

    // ---- Menus des icônes d'état ----

    // Batterie : « Batterie   85 % », source d'alimentation, réglages
    function batteryMenu(dev) {
        const pct = Math.round((dev?.percentage ?? 0) * 100) + " %";
        const st = dev?.state;
        const onAC = dev?.demo ? false : !UPower.onBattery;
        let src = onAC ? "Adaptateur secteur" : "Batterie";
        // (macOS n'affiche plus le temps restant dans ce menu depuis 10.12.2)
        let note = "";
        if (st === UPowerDeviceState.FullyCharged) note = "Batterie chargée";
        const out = [
            it("Batterie", { info: true, bold: true, pathText: pct }),
            it("Source d’alimentation : " + src, { info: true, secondary: true })
        ];
        if (note) out.push(it(note, { info: true, secondary: true }));
        out.push(sep());
        out.push(it("Mode économie d’énergie", {
            toggle: PowerProfiles.profile === PowerProfile.PowerSaver,
            keepOpen: true,
            action: () => {
                PowerProfiles.profile = PowerProfiles.profile === PowerProfile.PowerSaver
                    ? PowerProfile.Balanced : PowerProfile.PowerSaver;
            }
        }));
        out.push(sep());
        out.push(it("Réglages de la batterie…", { action: () => ShellState.open("controlcenter") }));
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
                out.push(hdr("Réseaux connus"));
                for (const n of known.slice(0, 6)) out.push(row(n));
            }
            const others = nets.filter(n => !n.known && !n.connected)
                .sort((a, b) => (b.signalStrength ?? 0) - (a.signalStrength ?? 0));
            out.push(sep());
            // Section dépliable sur place (chevron qui pivote), pas un sous-menu
            out.push(it("Autres réseaux", {
                disclosure: true,
                children: others.length ? others.slice(0, 12).map(row) : [it("Aucun réseau", { enabled: false })]
            }));
        }
        out.push(sep());
        out.push(it("Réglages Wi-Fi…", { action: () => ShellState.open("controlcenter") }));
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
        const names = [["app", appName], ["file", "Fichier"], ["edit", "Édition"], ["view", "Présentation"]]
            .concat(isFinder ? [["go", "Aller"]] : []).concat([["window", "Fenêtre"]]);
        for (const n of names) walk(build(n[0]), [n[1]]);
        return out;
    }

    // « À propos de <App> » : petit panneau du composant (AppAbout.qml)
    signal aboutRequested(string cls)
    // « Vider la corbeille… » : alerte de confirmation (Alert.qml)
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
