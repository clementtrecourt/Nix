import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common
import qs.services
import "fuzzy.js" as Fuzzy
import "calc.js" as Calc
import "categories.js" as Categories

// Moteur de recherche de Spotlight : agrège applications, fichiers (fd),
// calculs/conversions, actions et presse-papiers (cliphist) et produit une
// liste plate (en-têtes de section + éléments) consommée par la vue.
//
// Élément : { kind, title, subtitle, icon, symbol, tint, thumb, path, ... }
// En-tête  : { header: true, title }
Scope {
    id: root

    // ---- Entrées ----
    property string query: ""
    // "" (recherche générale), "apps", "files", "actions", "clipboard"
    property string mode: ""
    // Filtre de la vue Applications (id de catégorie, "" = toutes)
    property string appCategory: ""
    // Filtre de la vue Fichiers ("", "folders", "images", "pdf", "documents")
    property string fileKind: ""
    property bool active: false

    readonly property string home: Quickshell.env("HOME") ?? "/root"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/macos-shell"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")) + "/macos-shell/spotlight"

    readonly property string q: Fuzzy.fold(query.trim())

    // ---- Sorties ----
    // Liste plate pour la vue liste (en-têtes inclus)
    readonly property var results: buildResults()
    // Grille de la vue Applications : [{ header, title } | app...] ou apps à plat
    readonly property var appGrid: buildAppGrid()
    readonly property var appCategoriesPresent: {
        const present = {};
        for (const e of Apps.all) present[Categories.categoryOf(e.categories)] = true;
        return Categories.LIST.filter(c => present[c.id]);
    }

    // =====================================================================
    // Fréquence d'utilisation (~/.local/state/macos-shell/spotlight.json)
    // =====================================================================
    FileView {
        id: usageFile
        path: root.stateDir + "/spotlight.json"
        atomicWrites: true
        blockLoading: false
        printErrors: false
        onLoadFailed: err => {
            // Premier lancement : crée le dossier puis le fichier
            mkdirState.running = true;
        }
        JsonAdapter {
            id: usage
            // id .desktop -> { n: nombre de lancements, t: dernier lancement (ms) }
            property var apps: ({})
            // Requêtes récentes (flèche Haut, comme Tahoe)
            property list<string> history: []
        }
    }
    Process {
        id: mkdirState
        command: ["mkdir", "-p", root.stateDir, root.cacheDir]
        onExited: usageFile.writeAdapter()
    }

    function usageBoost(id) {
        const u = usage.apps[id];
        if (!u) return 0;
        // log du nombre de lancements + récence (demi-vie ~ 1 semaine)
        const ageDays = (Date.now() - (u.t ?? 0)) / 86400000;
        return Math.log2(1 + (u.n ?? 0)) * 6 + 8 * Math.pow(0.5, ageDays / 7);
    }
    function recordLaunch(id) {
        const a = Object.assign({}, usage.apps);
        const u = a[id] ?? { n: 0, t: 0 };
        a[id] = { n: (u.n ?? 0) + 1, t: Date.now() };
        usage.apps = a;
        saveTimer.restart();
    }
    function recordQuery(text) {
        const t = text.trim();
        if (!t) return;
        const h = [t].concat(Array.from(usage.history).filter(x => x !== t)).slice(0, 30);
        usage.history = h;
        saveTimer.restart();
    }
    function historyAt(i) { return usage.history.length > i ? usage.history[i] : ""; }
    readonly property int historyCount: usage.history.length
    Timer { id: saveTimer; interval: 400; onTriggered: usageFile.writeAdapter() }

    // =====================================================================
    // Applications
    // =====================================================================
    function appItem(e, section) {
        return {
            kind: "app", section: section, entry: e, id: e.id,
            title: e.name,
            subtitle: "Application",
            icon: Quickshell.iconPath(e.icon || e.id, "application-x-executable"),
            category: Categories.categoryOf(e.categories)
        };
    }

    function scoreApp(e) {
        let s = Fuzzy.score(q, e.name);
        if (e.genericName) s = Math.max(s, Fuzzy.score(q, e.genericName) * 0.75);
        for (const k of (e.keywords ?? [])) s = Math.max(s, Fuzzy.score(q, k) * 0.65);
        s = Math.max(s, Fuzzy.score(q, e.id) * 0.6);
        return s;
    }

    function matchApps(limit) {
        const out = [];
        for (const e of Apps.all) {
            const s = scoreApp(e);
            if (s > 0) out.push({ e: e, s: s + usageBoost(e.id) * (s >= 50 ? 1 : 0.3) });
        }
        out.sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name));
        return limit ? out.slice(0, limit) : out;
    }

    // =====================================================================
    // Actions (Tahoe : actions système + actions des apps)
    // =====================================================================
    // tint : couleur de la tuile façon Raccourcis derrière le symbole blanc
    readonly property var systemActions: [
        { id: "lock", title: "Verrouiller l’écran", symbol: "lock.fill", tint: "#5e5ce6", keywords: "lock verrouiller ecran" },
        { id: "dark", title: Theme.dark ? "Désactiver le mode sombre" : "Activer le mode sombre", symbol: "circle.lefthalf.filled", tint: "#1c1c1e", keywords: "dark mode sombre clair apparence theme" },
        { id: "sleep", title: "Suspendre l’activité", symbol: "moon.zzz", tint: "#5856d6", keywords: "sleep suspendre veille" },
        { id: "restart", title: "Redémarrer…", symbol: "arrow.clockwise", tint: "#8e8e93", keywords: "restart reboot redemarrer" },
        { id: "shutdown", title: "Éteindre…", symbol: "power", tint: "#ff3b30", keywords: "shutdown poweroff eteindre arreter" },
        { id: "logout", title: "Fermer la session…", symbol: "rectangle.portrait.and.arrow.right", tint: "#8e8e93", keywords: "logout deconnexion session quitter" },
        { id: "screenshot", title: "Capture d’écran", symbol: "camera.viewfinder", tint: "#8e8e93", keywords: "screenshot capture ecran" },
        { id: "missioncontrol", title: "Mission Control", symbol: "rectangle.3.group", tint: "#0a84ff", keywords: "mission control expose fenetres" },
        { id: "controlcenter", title: "Centre de contrôle", symbol: "switch.2", tint: "#636366", keywords: "control center centre controle" },
        { id: "notificationcenter", title: "Centre de notifications", symbol: "bell", tint: "#ff3b30", keywords: "notifications centre widgets" },
        { id: "forcequit", title: "Forcer à quitter…", symbol: "xmark.octagon", tint: "#ff9500", keywords: "force quit forcer quitter tuer kill" },
        { id: "clearclip", title: "Effacer l’historique du presse-papiers", symbol: "trash", tint: "#8e8e93", keywords: "clipboard presse papiers effacer vider historique" }
    ]

    function actionItem(a, section) {
        return { kind: "action", section: section, actionId: a.id, title: a.title, subtitle: "Action système",
                 symbol: a.symbol, tint: a.tint };
    }

    // Actions déclarées par les .desktop (ex. « Nouvelle fenêtre privée »)
    readonly property var appActions: {
        const out = [];
        for (const e of Apps.all) {
            for (const a of (e.actions ?? [])) {
                out.push({ entry: e, action: a, title: a.name, app: e.name,
                           icon: Quickshell.iconPath(a.icon || e.icon || e.id, "application-x-executable") });
            }
        }
        return out;
    }

    function matchActions(limit) {
        const out = [];
        for (const a of systemActions) {
            // Mots-clés : seulement en début de mot (évite « fi » -> notiFIcations)
            const kw = q ? Fuzzy.score(q, a.keywords) : 0;
            const s = q ? Math.max(Fuzzy.score(q, a.title), kw >= 60 ? kw * 0.8 : 0) : 1;
            if (s > 0) out.push({ s: s + (usage.apps["action:" + a.id] ? usageBoost("action:" + a.id) : 0), item: actionItem(a, "Actions") });
        }
        for (const a of appActions) {
            const s = q ? Fuzzy.score(q, a.title) : 0.5;
            if (s > 0) out.push({ s: s * 0.9, item: {
                kind: "appaction", section: "Actions", entry: a.entry, action: a.action,
                title: a.title, subtitle: a.app, icon: a.icon } });
        }
        out.sort((x, y) => y.s - x.s);
        return out.slice(0, limit ?? out.length).map(x => x.item);
    }

    function runAction(id) {
        recordLaunch("action:" + id);
        switch (id) {
        case "lock": Hyprland.dispatch("global macos:lock"); break;
        case "dark":
            Theme.dark = !Theme.dark;
            Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme",
                                     Theme.dark ? "prefer-dark" : "prefer-light"]);
            break;
        case "sleep": Quickshell.execDetached(["systemctl", "suspend"]); break;
        // Les dialogues de confirmation (Éteindre…, Redémarrer…) relèvent de Session
        case "restart": ShellState.open("restart"); break;
        case "shutdown": ShellState.open("shutdown"); break;
        case "logout": ShellState.open("logout"); break;
        case "screenshot": Hyprland.dispatch("global macos:screenshot-ui"); break;
        case "missioncontrol": Hyprland.dispatch("global macos:missioncontrol"); break;
        case "controlcenter": ShellState.open("controlcenter"); break;
        case "notificationcenter": ShellState.open("notificationcenter"); break;
        case "forcequit": Hyprland.dispatch("global macos:forcequit"); break;
        case "clearclip": Quickshell.execDetached(["cliphist", "wipe"]); clipItems = []; break;
        }
    }

    // =====================================================================
    // Calculatrice / conversions
    // =====================================================================
    readonly property var calcResult: Calc.evaluate(query)
    function calcItem() {
        const r = calcResult;
        if (!r) return null;
        if (r.kind === "convert") {
            return { kind: "calc", section: "Conversion", symbol: "arrow.left.arrow.right", tint: "#ff9500",
                     title: Calc.format(r.value, 4) + " " + r.unit,
                     subtitle: Calc.format(r.input) + " " + r.fromUnit,
                     copy: Calc.format(r.value, 4).replace(/ /g, "") };
        }
        return { kind: "calc", section: "Calculatrice", icon: Quickshell.iconPath("accessories-calculator", "calc"),
                 symbol: "calculator", tint: "#ff9500",
                 title: Calc.format(r.value), subtitle: r.expr,
                 copy: Calc.format(r.value).replace(/ /g, "") };
    }

    // =====================================================================
    // Fichiers (fd, asynchrone) + récents (recently-used.xbel)
    // =====================================================================
    property var fileHits: []          // [{ path, rel, dir, name }]
    property string fileHitsQuery: ""
    property string fdQuery: ""

    // (Re)lance fd quand la requête, le mode ou l'activité change. Calculé ici
    // plutôt que lu dans une liaison : l'ordre d'évaluation n'est pas garanti.
    function refreshFiles() {
        const want = active && (mode === "" || mode === "files") && q.length >= 2;
        if (want) fdTimer.restart();
        else { fdTimer.stop(); fdProc.running = false; fileHits = []; fileHitsQuery = ""; }
    }
    onQChanged: refreshFiles()
    onModeChanged: refreshFiles()
    onActiveChanged: refreshFiles()

    Timer {
        id: fdTimer
        interval: 90
        onTriggered: {
            fdProc.running = false;
            root.fdQuery = root.query.trim();
            fdProc.running = true;
        }
    }
    Process {
        id: fdProc
        command: ["fd", "--base-directory", root.home, "--ignore-case", "--fixed-strings",
                  "--max-results", "80", "--max-depth", "8",
                  "--exclude", "node_modules", "--exclude", ".git", "--exclude", "target",
                  "--exclude", "result", "--exclude", ".cache", "--exclude", "__pycache__",
                  "--", root.fdQuery]
        stdout: StdioCollector {
            onStreamFinished: {
                const want = root.query.trim();
                if (root.fdQuery !== want) return;      // résultat périmé
                root.fileHits = text.split("\n").filter(l => l.length).map(root.fileFromRel);
                root.fileHitsQuery = want;
            }
        }
    }

    function fileFromRel(rel) {
        const isDir = rel.endsWith("/");
        const clean = isDir ? rel.slice(0, -1) : rel;
        const slash = clean.lastIndexOf("/");
        return { path: home + "/" + clean, rel: clean, isDir: isDir,
                 name: clean.slice(slash + 1), dir: slash >= 0 ? clean.slice(0, slash) : "" };
    }

    // Fichiers récents (vue Fichiers sans requête, comme les suggestions de Tahoe)
    property var recentFiles: []
    FileView {
        id: recentXbel
        path: (Quickshell.env("XDG_DATA_HOME") || (root.home + "/.local/share")) + "/recently-used.xbel"
        blockLoading: false
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const txt = text();
            const re = /<bookmark href="file:\/\/([^"]+)"[^>]*modified="([^"]+)"/g;
            const out = [];
            let m;
            while ((m = re.exec(txt)) !== null) {
                let p;
                try { p = decodeURIComponent(m[1]); } catch (e) { continue; }
                if (!p.startsWith(root.home + "/")) continue;
                out.push({ p: p, t: Date.parse(m[2]) });
            }
            out.sort((a, b) => b.t - a.t);
            // Ne garde que les fichiers encore présents (et repère les dossiers)
            recentCheck.times = {};
            for (const x of out) recentCheck.times[x.p] = x.t;
            recentCheck.command = ["sh", "-c",
                "for f; do if [ -d \"$f\" ]; then echo \"d $f\"; elif [ -e \"$f\" ]; then echo \"f $f\"; fi; done",
                "sh"].concat(out.slice(0, 120).map(x => x.p));
            recentCheck.running = true;
        }
    }
    Process {
        id: recentCheck
        property var times: ({})
        stdout: StdioCollector {
            onStreamFinished: {
                const res = [];
                for (const line of text.split("\n")) {
                    if (line.length < 3) continue;
                    const p = line.slice(2);
                    const f = root.fileFromRel(p.slice(root.home.length + 1) + (line[0] === "d" ? "/" : ""));
                    f.when = recentCheck.times[p] ?? 0;
                    res.push(f);
                    if (res.length >= 60) break;
                }
                root.recentFiles = res;
            }
        }
    }

    // Type de fichier -> (section, icône du thème)
    function fileKindOf(f) {
        if (f.isDir) return "folders";
        const ext = (f.name.match(/\.([^.]+)$/)?.[1] ?? "").toLowerCase();
        if (["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "heic", "avif", "tif", "tiff"].includes(ext)) return "images";
        if (ext === "pdf") return "pdf";
        return "documents";
    }
    readonly property var fileKindNames: ({ folders: "Dossiers", images: "Images", pdf: "Documents PDF", documents: "Documents" })

    function fileIcon(f) {
        if (f.isDir) {
            const special = { "Documents": "folder-documents", "Downloads": "folder-download", "Téléchargements": "folder-download",
                              "Pictures": "folder-pictures", "Images": "folder-pictures", "Music": "folder-music", "Musique": "folder-music",
                              "Videos": "folder-videos", "Vidéos": "folder-videos", "Desktop": "user-desktop", "Bureau": "user-desktop" };
            return Quickshell.iconPath(f.dir === "" && special[f.name] ? special[f.name] : "folder", "folder");
        }
        const ext = (f.name.match(/\.([^.]+)$/)?.[1] ?? "").toLowerCase();
        const map = {
            png: "image-x-generic", jpg: "image-x-generic", jpeg: "image-x-generic", webp: "image-x-generic",
            gif: "image-x-generic", heic: "image-x-generic", avif: "image-x-generic", svg: "image-svg+xml",
            pdf: "application-pdf", txt: "text-plain", md: "text-markdown", nix: "text-x-script",
            sh: "text-x-script", fish: "text-x-script", py: "text-x-python", js: "text-x-javascript",
            ts: "text-x-javascript", qml: "text-x-generic", json: "application-json", html: "text-html",
            css: "text-css", c: "text-x-csrc", h: "text-x-chdr", cpp: "text-x-c++src", rs: "text-rust",
            go: "text-x-go", java: "text-x-java", zip: "application-zip", gz: "application-x-gzip",
            tar: "application-x-tar", xz: "application-x-xz", "7z": "application-x-7z-compressed",
            iso: "application-x-cd-image", deb: "application-x-deb", rpm: "application-x-rpm",
            mp3: "audio-x-generic", flac: "audio-x-generic", ogg: "audio-x-generic", wav: "audio-x-generic", m4a: "audio-x-generic",
            mp4: "video-x-generic", mkv: "video-x-generic", webm: "video-x-generic", mov: "video-x-generic", avi: "video-x-generic",
            doc: "x-office-document", docx: "x-office-document", odt: "x-office-document", rtf: "x-office-document",
            xls: "x-office-spreadsheet", xlsx: "x-office-spreadsheet", ods: "x-office-spreadsheet", csv: "text-csv",
            ppt: "x-office-presentation", pptx: "x-office-presentation", odp: "x-office-presentation",
            torrent: "application-x-bittorrent", ttf: "font-x-generic", otf: "font-x-generic", desktop: "application-x-desktop"
        };
        return Quickshell.iconPath(map[ext] ?? "text-x-generic", "text-x-generic");
    }

    function fileItem(f, section) {
        const k = fileKindOf(f);
        return {
            kind: "file", section: section ?? fileKindNames[k], fileKind: k,
            title: f.name, path: f.path, isDir: f.isDir,
            subtitle: f.dir === "" ? "Dossier de départ" : f.dir.split("/").pop(),
            location: "~/" + (f.dir ? f.dir + "/" : ""),
            icon: fileIcon(f),
            thumb: /\.(png|jpe?g|gif|bmp|svg)$/i.test(f.name) ? "file://" + encodeURI(f.path) : ""
        };
    }

    function rankedFiles() {
        if (fileHitsQuery === "" ) return [];
        const out = [];
        for (const f of fileHits) {
            let s = Fuzzy.score(q, f.name);
            if (s <= 0) s = 10;   // fd a trouvé la requête dans le nom
            // Pénalise la profondeur et les dossiers techniques
            s -= f.rel.split("/").length * 2;
            if (/(^|\/)\./.test(f.rel)) s -= 20;
            out.push({ f: f, s: s });
        }
        out.sort((a, b) => b.s - a.s);
        return out.map(x => x.f);
    }

    // =====================================================================
    // Presse-papiers (cliphist)
    // =====================================================================
    property var clipItems: []         // [{ id, text, isImage, meta }]
    readonly property bool wantClip: active && mode === "clipboard"
    onWantClipChanged: if (wantClip) { clipProc.running = false; clipProc.running = true; }
    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const items = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const id = line.slice(0, tab);
                    const preview = line.slice(tab + 1);
                    const img = preview.match(/^\[\[ binary data (.+?) (png|jpe?g|webp|gif|bmp) (\d+)x(\d+) \]\]$/);
                    items.push({ id: id, text: preview, isImage: !!img,
                                 meta: img ? (img[2].toUpperCase() + " · " + img[3] + " × " + img[4] + " · " + img[1]) : "",
                                 ext: img ? img[2] : "" });
                    if (items.length >= 150) break;
                }
                root.clipItems = items;
                root.ensureClipThumbs();
            }
        }
    }
    // Vignettes des images : cliphist decode <id> > cache/<id>.<ext> (une fois)
    property var clipThumbs: ({})
    function ensureClipThumbs() {
        const todo = clipItems.filter(c => c.isImage && !clipThumbs[c.id]).slice(0, 24);
        if (!todo.length) return;
        const script = "mkdir -p \"$1\"; shift; for x in \"$@\"; do f=\"$D/${x%%:*}.${x##*:}\"; [ -s \"$f\" ] || cliphist decode \"${x%%:*}\" > \"$f\"; echo \"$f\"; done";
        thumbProc.command = ["sh", "-c", script.replace(/\$D/g, root.cacheDir), "sh", root.cacheDir]
            .concat(todo.map(c => c.id + ":" + c.ext));
        thumbProc.running = true;
    }
    Process {
        id: thumbProc
        stdout: StdioCollector {
            onStreamFinished: {
                const t = Object.assign({}, root.clipThumbs);
                for (const f of text.split("\n").filter(l => l.length)) {
                    const id = f.split("/").pop().split(".")[0];
                    t[id] = "file://" + f;
                }
                root.clipThumbs = t;
            }
        }
    }

    function clipItem(c) {
        const isUrl = /^(https?|ftp):\/\/\S+$/.test(c.text.trim());
        const isPath = /^(file:\/\/|\/)\S+$/.test(c.text.trim());
        return {
            kind: "clip", section: "", clipId: c.id,
            title: c.isImage ? "Image" : c.text.replace(/\s+/g, " ").trim(),
            subtitle: c.isImage ? c.meta : (isUrl ? "Lien" : isPath ? "Fichier" : "Texte"),
            symbol: c.isImage ? "photo" : isUrl ? "link" : isPath ? "doc" : "text.alignleft",
            thumb: c.isImage ? (clipThumbs[c.id] ?? "") : "",
            fullText: c.text
        };
    }

    // =====================================================================
    // Assemblage
    // =====================================================================
    function pushSection(out, title, items) {
        if (!items.length) return;
        if (title) out.push({ header: true, title: title });
        for (const it of items) out.push(it);
    }

    function buildResults() {
        const out = [];
        if (!active) return out;

        if (mode === "clipboard") {
            const items = clipItems.filter(c => !q || Fuzzy.fold(c.text).includes(q));
            pushSection(out, "", items.slice(0, 100).map(clipItem));
            return out;
        }
        if (mode === "actions") {
            pushSection(out, q ? "" : "Suggestions", matchActions(q ? 40 : 60));
            return out;
        }
        if (mode === "files") return out;      // vue en icônes : voir fileGrid
        if (mode === "apps") return out;       // vue grille : voir appGrid
        if (!q) return out;

        // --- Recherche générale ---
        // Les correspondances trop lâches (sous-séquences éparses) sont écartées.
        const apps = matchApps(8).filter(a => a.s >= 35);
        const calc = calcItem();
        const actions = matchActions(8).filter(a => Fuzzy.score(q, a.title) >= 35 || a.kind === "action" && q.length >= 3
                                                   && Fuzzy.score(q, systemActions.find(x => x.id === a.actionId).keywords) >= 60).slice(0, 4);
        // Comme Spotlight : correspondance en début de mot uniquement
        const files = rankedFiles().filter(f => Fuzzy.score(q, f.name) >= 60);
        const fileTopScore = files.length ? Fuzzy.score(q, files[0].name) : 0;

        // Meilleur résultat : calcul, sinon app très pertinente, sinon document
        // dont le nom commence par la requête, sinon action exacte
        let top = null;
        if (calc) top = calc;
        else if (apps.length && apps[0].s >= 50) top = appItem(apps[0].e, "Meilleur résultat");
        else if (fileTopScore >= 80) top = fileItem(files[0]);
        else if (actions.length && Fuzzy.score(q, actions[0].title) >= 80) top = actions[0];
        if (top) pushSection(out, "Meilleur résultat", [Object.assign({}, top, { top: true })]);

        const appRest = apps.filter(a => !(top && top.kind === "app" && top.id === a.e.id)).slice(0, 5);
        pushSection(out, "Applications", appRest.map(a => appItem(a.e, "Applications")));
        pushSection(out, "Actions", actions.filter(a => a !== top).slice(0, 3));

        // Fichiers par type, 4 max par section
        const groups = { folders: [], documents: [], pdf: [], images: [] };
        for (const f of files) {
            if (top && top.kind === "file" && top.path === f.path) continue;
            const k = fileKindOf(f);
            if (groups[k].length < 4) groups[k].push(fileItem(f));
        }
        pushSection(out, "Documents", groups.documents);
        pushSection(out, "Documents PDF", groups.pdf);
        pushSection(out, "Dossiers", groups.folders);
        pushSection(out, "Images", groups.images);

        // Toujours en dernier : recherche sur le Web
        pushSection(out, "Rechercher sur le Web", [{
            kind: "web", title: query.trim(), subtitle: "Rechercher sur le Web", symbol: "globe", tint: "#0a84ff"
        }]);
        return out;
    }

    // Vue Applications (Tahoe) : suggestions (apps les plus utilisées) puis
    // toutes les apps par ordre alphabétique ; pastille = filtre de catégorie,
    // la saisie filtre à l'intérieur de la catégorie choisie.
    function buildAppGrid() {
        if (!active || mode !== "apps") return [];
        if (q) {
            return matchApps(0).filter(a => a.s >= 30)
                .map(a => appItem(a.e, ""))
                .filter(a => !appCategory || a.category === appCategory);
        }
        const all = Apps.all.map(e => appItem(e, ""));
        if (appCategory) return all.filter(a => a.category === appCategory);
        const out = [];
        const used = Apps.all.filter(e => usage.apps[e.id])
            .sort((a, b) => usageBoost(b.id) - usageBoost(a.id))
            .slice(0, 7);
        if (used.length) {
            out.push({ header: true, title: "Suggestions" });
            for (const e of used) out.push(appItem(e, ""));
            out.push({ header: true, title: "Toutes les apps" });
        }
        return out.concat(all);
    }

    readonly property var fileGrid: {
        if (!active || mode !== "files") return [];
        const src = q ? rankedFiles() : recentFiles;
        return src.map(f => fileItem(f, "")).filter(f => !fileKind || f.fileKind === fileKind).slice(0, 60);
    }
    readonly property bool filesLoading: mode === "files" && q.length >= 2 && (fdProc.running || fdTimer.running)

    // =====================================================================
    // Exécution d'un élément
    // =====================================================================
    // reveal : ⌘Entrée = afficher dans le gestionnaire de fichiers
    function activate(item, reveal) {
        if (!item || item.header) return;
        recordQuery(query);
        switch (item.kind) {
        case "app":
            // (⌘Entrée sur une app : pas d'emplacement Finder sous NixOS, on lance)
            recordLaunch(item.id);
            launchApp(item.entry);
            break;
        case "appaction":
            recordLaunch(item.entry.id);
            item.action.execute();
            break;
        case "action":
            runAction(item.actionId);
            break;
        case "file":
            if (reveal) {
                // Ouvre le dossier parent en sélectionnant le fichier (FileManager1 DBus)
                Quickshell.execDetached(["dbus-send", "--session", "--dest=org.freedesktop.FileManager1",
                    "--type=method_call", "/org/freedesktop/FileManager1",
                    "org.freedesktop.FileManager1.ShowItems",
                    "array:string:file://" + encodeURI(item.path), "string:"]);
            } else {
                Quickshell.execDetached(["xdg-open", item.path]);
            }
            break;
        case "calc":
            Quickshell.execDetached(["wl-copy", "--", item.copy]);
            break;
        case "web":
            Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(item.title)]);
            break;
        case "clip":
            pasteClip(item.clipId);
            break;
        }
    }

    // Lance l'app, ou la ramène au premier plan si elle tourne déjà (comme macOS)
    function launchApp(entry) {
        for (const t of Windows.toplevels) {
            const cls = Windows.classOf(t);
            const e = cls ? Apps.entryFor(cls) : null;
            if (e && e.id === entry.id) { Windows.focus(t); return; }
        }
        entry.execute();
    }

    // Entrée sur un élément du presse-papiers : le recopie puis le colle dans
    // l'app au premier plan (Ctrl+V, Ctrl+Maj+V dans les terminaux).
    property string pendingPaste: ""
    function pasteClip(id) {
        pasteProc.command = ["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", id];
        pasteProc.running = true;
    }
    Process {
        id: pasteProc
        onExited: pasteTimer.restart()
    }
    Timer {
        id: pasteTimer
        interval: 180
        onTriggered: {
            const cls = (Windows.activeClass ?? "").toLowerCase();
            const term = /kitty|foot|alacritty|wezterm|ghostty|konsole|terminal/.test(cls);
            Hyprland.dispatch(term ? "sendshortcut CTRL SHIFT, V, activewindow" : "sendshortcut CTRL, V, activewindow");
        }
    }
    function copyClip(id) {
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", id]);
    }
    function deleteClip(id) {
        Quickshell.execDetached(["sh", "-c", "cliphist list | grep -m1 \"^$1\t\" | cliphist delete", "sh", id]);
        clipItems = clipItems.filter(c => c.id !== id);
    }
}
