import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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
    readonly property var win: Windows.activeToplevel
    readonly property string cls: Windows.activeClass
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
    function place(fx, fy, fw, fh) {
        const a = workArea();
        if (!a || !win) return;
        const target = ",address:" + addr();
        if (!(win.lastIpcObject?.floating ?? true)) dispatch("setfloating address:" + addr());
        if ((win.lastIpcObject?.fullscreen ?? 0) !== 0) dispatch("fullscreenstate 0 0");
        dispatch("resizewindowpixel exact " + Math.round(a.w * fw) + " " + Math.round(a.h * fh) + target);
        dispatch("movewindowpixel exact " + Math.round(a.x + a.w * fx) + " " + Math.round(a.y + a.h * fy) + target);
    }

    // ---- Menus ----
    function build(id) {
        switch (id) {
        case "logo": return logoMenu();
        case "app": return appMenu();
        case "file": return fileMenu();
        case "edit": return editMenu();
        case "view": return viewMenu();
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

    function recentMenu() {
        const txt = recentFile.text() ?? "";
        const re = /<bookmark\s+href="([^"]+)"[^>]*?modified="([^"]+)"/g;
        const docs = [];
        let m;
        while ((m = re.exec(txt)) !== null) {
            if (!m[1].startsWith("file://")) continue;
            docs.push({ href: m[1], when: m[2] });
        }
        docs.sort((a, b) => (a.when < b.when ? 1 : -1));
        const out = [hdr("Documents")];
        const seen = {};
        for (const d of docs) {
            if (out.length > 11) break;
            if (seen[d.href]) continue;
            seen[d.href] = true;
            let name = d.href.split("/").pop();
            try { name = decodeURIComponent(name); } catch (e) {}
            const href = d.href;
            out.push(it(name, {
                iconSource: Quickshell.iconPath(mimeIcon(name), "text-x-generic"),
                action: () => Quickshell.execDetached(["xdg-open", href])
            }));
        }
        if (out.length === 1) out.push(it("Aucun élément", { enabled: false }));
        out.push(sep());
        out.push(it("Effacer le menu", { enabled: false }));
        return out;
    }

    // Icône de type de fichier (thème d'icônes) d'après l'extension
    function mimeIcon(name) {
        const ext = (name.split(".").pop() ?? "").toLowerCase();
        if (["png", "jpg", "jpeg", "webp", "gif", "svg", "heic", "avif"].includes(ext)) return "image-x-generic";
        if (ext === "pdf") return "application-pdf";
        if (["mp4", "mkv", "webm", "mov"].includes(ext)) return "video-x-generic";
        if (["mp3", "flac", "ogg", "wav", "m4a"].includes(ext)) return "audio-x-generic";
        if (["zip", "tar", "gz", "xz", "zst", "7z"].includes(ext)) return "package-x-generic";
        return "text-x-generic";
    }

    // Menu de l'app (nom en gras)
    function appMenu() {
        const others = Windows.toplevels.filter(t => Windows.classOf(t) !== cls && !Windows.isMinimized(t));
        const hidden = Windows.toplevels.filter(t => Windows.isMinimized(t));
        const mine = cls ? Windows.windowsOf(cls) : [];
        const c = cls;
        return [
            it("À propos de " + appName, { icon: "info.circle", action: () => root.showAbout(c) }),
            sep(),
            it("Réglages…", {
                icon: "gearshape", shortcut: ["⌘", ","], enabled: !isFinder,
                action: () => send("CTRL", "comma")
            }),
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

    function windowMenu() {
        const w = win;
        const has = !!w;
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
                    hdr("Moitiés"),
                    it("Gauche", { icon: "rectangle.lefthalf.inset.filled", shortcut: ["⌃", "🌐←"], action: () => place(0, 0, 0.5, 1) }),
                    it("Droite", { icon: "rectangle.righthalf.inset.filled", shortcut: ["⌃", "🌐→"], action: () => place(0.5, 0, 0.5, 1) }),
                    it("Haut", { icon: "rectangle.tophalf.inset.filled", shortcut: ["⌃", "🌐↑"], action: () => place(0, 0, 1, 0.5) }),
                    it("Bas", { icon: "rectangle.bottomhalf.inset.filled", shortcut: ["⌃", "🌐↓"], action: () => place(0, 0.5, 1, 0.5) }),
                    sep(),
                    hdr("Quarts"),
                    it("En haut à gauche", { action: () => place(0, 0, 0.5, 0.5) }),
                    it("En haut à droite", { action: () => place(0.5, 0, 0.5, 0.5) }),
                    it("En bas à gauche", { action: () => place(0, 0.5, 0.5, 0.5) }),
                    it("En bas à droite", { action: () => place(0.5, 0.5, 0.5, 0.5) })
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
            { search: true },
            it("Aide " + appName, { enabled: false })
        ];
    }

    // Tous les éléments actionnables des menus de l'app (recherche du menu Aide)
    function searchable() {
        const out = [];
        const walk = (list, path) => {
            for (const e of list) {
                if (!e || e.separator || e.header || e.search) continue;
                if (Array.isArray(e.submenu)) walk(e.submenu, path.concat([e.text]));
                else if (typeof e.action === "function") out.push(Object.assign({}, e, { path: path }));
            }
        };
        const names = [["app", appName], ["file", "Fichier"], ["edit", "Édition"], ["view", "Présentation"], ["window", "Fenêtre"]];
        for (const n of names) walk(build(n[0]), [n[1]]);
        return out;
    }

    // « À propos de <App> » : petit panneau du composant (AppAbout.qml)
    signal aboutRequested(string cls)
    function showAbout(c) { root.aboutRequested(c); }
}
