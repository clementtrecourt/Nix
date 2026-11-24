import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common
import qs.services
import qs.controlcenter
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
    // Liste plate pour la vue liste (filtrée par la pastille de groupe)
    readonly property var results: buildResults()
    // Grille de la vue Applications : [{ header, title } | app...] ou apps à plat
    readonly property var appGrid: buildAppGrid()

    // Applications visibles, dédoublonnées : une seule entrée par id .desktop
    // et par (nom, commande) — le même lanceur installé à plusieurs endroits,
    // ou un alias (ex. deux .desktop « kitty » au même Exec), n'apparaît
    // qu'une fois. Sont aussi écartées les entrées masquées pour Hyprland
    // (Hidden=true, OnlyShowIn= sans Hyprland, NotShowIn= avec Hyprland), que
    // DesktopEntries n'expose pas : relevées par `hiddenScan`.
    readonly property var apps: {
        const seenId = {}, seenCmd = {}, out = [];
        for (const e of Apps.all) {
            if (e.noDisplay || hiddenIds[e.id]) continue;
            const cmd = (e.execString ?? "").replace(/\s+%[a-zA-Z]/g, "").trim();
            const key = e.name.toLowerCase() + "\u0001" + cmd;
            if (seenId[e.id] || (cmd && seenCmd[key])) continue;
            seenId[e.id] = true;
            if (cmd) seenCmd[key] = true;
            out.push(e);
        }
        return out;
    }
    property var hiddenIds: ({})
    Process {
        id: hiddenScan
        running: true
        // id<TAB>Hidden<TAB>OnlyShowIn<TAB>NotShowIn pour chaque .desktop des
        // dossiers XDG (le premier dossier qui définit un id l'emporte)
        command: ["sh", "-c",
            "IFS=:; for d in ${XDG_DATA_HOME:-$HOME/.local/share} ${XDG_DATA_DIRS:-/usr/share}; do " +
            "[ -d \"$d/applications\" ] || continue; " +
            "find -L \"$d/applications\" -name '*.desktop' 2>/dev/null | while read -r f; do " +
            "id=${f#$d/applications/}; id=$(printf %s \"${id%.desktop}\" | tr / -); " +
            "h=$(sed -n '/^\\[Desktop Entry\\]/,/^\\[/{s/^Hidden=//p}' \"$f\" | head -1); " +
            "o=$(sed -n '/^\\[Desktop Entry\\]/,/^\\[/{s/^OnlyShowIn=//p}' \"$f\" | head -1); " +
            "n=$(sed -n '/^\\[Desktop Entry\\]/,/^\\[/{s/^NotShowIn=//p}' \"$f\" | head -1); " +
            "[ -n \"$h$o$n\" ] && printf '%s\\t%s\\t%s\\t%s\\n' \"$id\" \"$h\" \"$o\" \"$n\"; done; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const l of text.split("\n")) {
                    const f = l.split("\t");
                    if (f.length < 4) continue;
                    const only = f[2].split(";").filter(x => x);
                    const not = f[3].split(";").filter(x => x);
                    if (f[1] === "true" || (only.length && !only.includes("Hyprland")) || not.includes("Hyprland"))
                        out[f[0]] = true;
                }
                root.hiddenIds = out;
            }
        }
    }
    // Catégories présentes, des plus fournies aux moins fournies (pastilles)
    readonly property var appCategoriesPresent: {
        const count = {};
        for (const e of root.apps) {
            const c = Categories.categoryOf(e.categories);
            count[c] = (count[c] ?? 0) + 1;
        }
        return Categories.LIST.filter(c => count[c.id])
            .sort((a, b) => count[b.id] - count[a.id] || Categories.LIST.indexOf(a) - Categories.LIST.indexOf(b));
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
            kind: "app", section: section, group: "apps", entry: e, id: e.id,
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
        for (const e of root.apps) {
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
        { id: "lock", title: "Lock Screen", symbol: "lock.fill", tint: "#5e5ce6", keywords: "lock screen" },
        { id: "dark", title: Theme.dark ? "Turn Off Dark Mode" : "Turn On Dark Mode", symbol: "circle.lefthalf.filled", tint: "#1c1c1e", keywords: "dark mode light appearance theme" },
        { id: "sleep", title: "Sleep", symbol: "moon.zzz", tint: "#5856d6", keywords: "sleep suspend" },
        { id: "restart", title: "Restart…", symbol: "arrow.clockwise", tint: "#8e8e93", keywords: "restart reboot" },
        { id: "shutdown", title: "Shut Down…", symbol: "power", tint: "#ff3b30", keywords: "shut down shutdown power off" },
        { id: "logout", title: "Log Out " + root.userName + "…", symbol: "rectangle.portrait.and.arrow.right", tint: "#8e8e93", keywords: "log out logout sign out session" },
        { id: "screenshot", title: "Take Screenshot", symbol: "camera.viewfinder", tint: "#8e8e93", keywords: "screenshot screen capture" },
        { id: "missioncontrol", title: "Mission Control", symbol: "rectangle.3.group", tint: "#0a84ff", keywords: "mission control expose windows" },
        { id: "controlcenter", title: "Control Center", symbol: "switch.2", tint: "#636366", keywords: "control center" },
        { id: "notificationcenter", title: "Notification Center", symbol: "bell", tint: "#ff3b30", keywords: "notifications center widgets" },
        { id: "forcequit", title: "Force Quit…", symbol: "xmark.octagon", tint: "#ff9500", keywords: "force quit kill" },
        { id: "clearclip", title: "Clear Clipboard History", symbol: "trash", tint: "#8e8e93", keywords: "clipboard clear history" }
    ]

    // Nom complet de l'utilisateur pour « Log Out <nom>… » (menu Apple)
    property string userName: Quickshell.env("USER") ?? ""
    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$(id -un)\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector {
            onStreamFinished: { const n = text.trim(); if (n) root.userName = n; }
        }
    }

    function actionItem(a, section) {
        return { kind: "action", section: section, group: "actions", actionId: a.id, title: a.title,
                 subtitle: "System", symbol: a.symbol, tint: a.tint };
    }

    // Actions déclarées par les .desktop (ex. « New Private Window »)
    readonly property var appActions: {
        const out = [];
        for (const e of root.apps) {
            for (const a of (e.actions ?? [])) {
                out.push({ entry: e, action: a, title: a.name, app: e.name,
                           icon: Quickshell.iconPath(a.icon || e.icon || e.id, "application-x-executable") });
            }
        }
        return out;
    }

    function matchActions(limit) {
        const out = [];
        for (let i = 0; i < systemActions.length; i++) {
            const a = systemActions[i];
            // Mots-clés : seulement en début de mot (évite « fi » -> notiFIcations)
            const kw = q ? Fuzzy.score(q, a.keywords) : 0;
            const s = q ? Math.max(Fuzzy.score(q, a.title), kw >= 60 ? kw * 0.8 : 0) : 1;
            if (s > 0) out.push({ s: s + (usage.apps["action:" + a.id] ? usageBoost("action:" + a.id) : 0), item: actionItem(a, "Suggestions"), i: i });
        }
        for (const a of appActions) {
            const s = q ? Fuzzy.score(q, a.title) : 0.5;
            if (s > 0) out.push({ s: s * 0.9, i: 1000 + out.length, item: {
                kind: "appaction", section: a.app, group: "actions", entry: a.entry, action: a.action,
                title: a.title, subtitle: a.app, icon: a.icon } });
        }
        // Tri stable : à score égal, ordre de déclaration
        out.sort((x, y) => y.s - x.s || x.i - y.i);
        return out.slice(0, limit ?? out.length).map(x => x.item);
    }

    function runAction(id) {
        recordLaunch("action:" + id);
        switch (id) {
        case "lock": Hyprland.dispatch("global macos:lock"); break;
        case "dark":
            // Même chemin que le Control Center (persistance + gsettings + thème GTK)
            Appearance.toggle();
            break;
        case "sleep": Quickshell.execDetached(["systemctl", "suspend"]); break;
        // Les dialogues de confirmation (Shut Down…, Restart…) relèvent de Session
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
            return { kind: "calc", section: "Conversion", group: "conversion", symbol: "arrow.left.arrow.right", tint: "#ff9500",
                     title: Calc.format(r.value, 4) + " " + r.unit,
                     subtitle: Calc.format(r.input) + " " + r.fromUnit,
                     copy: Calc.format(r.value, 4).replace(/,/g, "") };
        }
        return { kind: "calc", section: "Calculator", group: "calc",
                 icon: Quickshell.iconPath("accessories-calculator", "calc"),
                 symbol: "calculator", tint: "#ff9500",
                 title: "= " + Calc.format(r.value), subtitle: r.expr,
                 copy: Calc.format(r.value).replace(/,/g, "") };
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
    onQChanged: { refreshFiles(); if (!q) resultFilter = ""; }
    onModeChanged: { refreshFiles(); resultFilter = ""; }
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
        // fd liste les chemins (relatifs à $HOME), stat ajoute la date de
        // modification : « 1712345678\tDocuments/rapport.pdf »
        command: ["sh", "-c",
                  "cd \"$HOME\" && fd --strip-cwd-prefix --ignore-case --fixed-strings --max-results 80 --max-depth 8 " +
                  "--exclude node_modules --exclude .git --exclude target --exclude result " +
                  "--exclude .cache --exclude __pycache__ -0 -- \"$1\" | xargs -0 -r stat -c '%Y\t%s\t%n'",
                  "sh", root.fdQuery]
        stdout: StdioCollector {
            onStreamFinished: {
                const want = root.query.trim();
                if (root.fdQuery !== want) return;      // résultat périmé
                // « mtime<TAB>taille<TAB>chemin »
                root.fileHits = text.split("\n").filter(l => l.split("\t").length >= 3).map(l => {
                    const t1 = l.indexOf("\t"), t2 = l.indexOf("\t", t1 + 1);
                    const f = root.fileFromRel(l.slice(t2 + 1));
                    f.when = Number(l.slice(0, t1)) * 1000;
                    f.size = Number(l.slice(t1 + 1, t2));
                    return f;
                });
                root.fileHitsQuery = want;
                root.checkThumbs(root.fileHits);
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

    // Vignettes : chemin -> true quand le fichier est une vraie image PNG, JPEG,
    // GIF, BMP ou WebP (signature des premiers octets vérifiée)
    property var thumbOk: ({})
    function checkThumbs(files) {
        // (pas de WebP : le Qt du shell n'a pas le greffon de décodage)
        const todo = files.filter(f => !f.isDir && /\.(png|jpe?g|gif|bmp)$/i.test(f.name) && !(f.path in thumbOk))
                          .slice(0, 40).map(f => f.path);
        if (!todo.length) return;
        const p = thumbCheckComp.createObject(root, { paths: todo });
        p.running = true;
    }
    Component {
        id: thumbCheckComp
        Process {
            id: tp
            property var paths: []
            command: ["sh", "-c",
                "for f; do h=$(head -c 12 \"$f\" 2>/dev/null | od -An -tx1 | tr -d ' \\n'); " +
                "case $h in 89504e47*|ffd8ff*|47494638*|424d*|52494646????????57454250*) echo \"1$f\";; *) echo \"0$f\";; esac; done",
                "sh"].concat(paths)
            stdout: StdioCollector {
                onStreamFinished: {
                    const t = Object.assign({}, root.thumbOk);
                    for (const l of text.split("\n")) if (l.length > 1) t[l.slice(1)] = l[0] === "1";
                    root.thumbOk = t;
                    tp.destroy();
                }
            }
        }
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
                "for f; do if [ -d \"$f\" ]; then echo \"d 0 $f\"; elif [ -e \"$f\" ]; then echo \"f $(stat -c %s \"$f\") $f\"; fi; done",
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
                    // « d|f <taille> <chemin> »
                    const sp = line.indexOf(" ", 2);
                    if (line.length < 3 || sp < 0) continue;
                    const p = line.slice(sp + 1);
                    const f = root.fileFromRel(p.slice(root.home.length + 1) + (line[0] === "d" ? "/" : ""));
                    f.when = recentCheck.times[p] ?? 0;
                    f.size = Number(line.slice(2, sp));
                    res.push(f);
                    if (res.length >= 60) break;
                }
                root.recentFiles = res;
                root.checkThumbs(res);
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
    readonly property var fileKindNames: ({ folders: "Folders", images: "Images", pdf: "PDF Documents", documents: "Documents" })

    // Type affiché (Finder, « Kind ») : « PDF document », « PNG image »…
    function kindLabel(f) {
        if (f.isDir) return "Folder";
        const ext = (f.name.match(/\.([^.]+)$/)?.[1] ?? "").toLowerCase();
        const map = {
            pdf: "PDF document", png: "PNG image", jpg: "JPEG image", jpeg: "JPEG image", gif: "GIF image",
            webp: "WebP image", heic: "HEIC image", svg: "SVG image", bmp: "BMP image", tif: "TIFF image", tiff: "TIFF image",
            txt: "Plain Text", md: "Markdown Document", rtf: "Rich Text Document", html: "HTML text", css: "CSS",
            json: "JSON", js: "JavaScript script", ts: "TypeScript", py: "Python script", sh: "Shell script",
            nix: "Nix", qml: "QML", c: "C source", h: "C header", cpp: "C++ source", rs: "Rust source", go: "Go source",
            zip: "ZIP archive", gz: "gzip compressed archive", tar: "tar archive", xz: "XZ archive", "7z": "7-Zip archive",
            mp3: "MP3 audio", flac: "FLAC audio", wav: "Waveform audio", m4a: "Apple MPEG-4 audio", ogg: "Ogg audio",
            mp4: "MPEG-4 movie", mov: "QuickTime movie", mkv: "Matroska video", webm: "WebM video",
            doc: "Microsoft Word document", docx: "Microsoft Word document", odt: "OpenDocument text",
            xls: "Microsoft Excel spreadsheet", xlsx: "Microsoft Excel spreadsheet", csv: "CSV document",
            ppt: "Microsoft PowerPoint presentation", pptx: "Microsoft PowerPoint presentation",
            iso: "Disk Image", ttf: "TrueType font", otf: "OpenType font"
        };
        return map[ext] ?? (ext ? ext.toUpperCase() + " file" : "Document");
    }
    // Taille façon Finder (base 1000) : « 41 KB », « 5.6 MB »
    function sizeLabel(n) {
        if (n === undefined || n === null || isNaN(n)) return "";
        if (n < 1000) return n + " bytes";
        const units = ["KB", "MB", "GB", "TB"];
        let v = n, i = -1;
        do { v /= 1000; i++; } while (v >= 1000 && i < units.length - 1);
        return (v >= 100 || i === 0 ? Math.round(v) : Math.round(v * 10) / 10) + " " + units[i];
    }

    function fileIcon(f) {
        if (f.isDir) {
            const special = { "Documents": "folder-documents", "Downloads": "folder-download", "Pictures": "folder-pictures",
                              "Music": "folder-music", "Videos": "folder-videos", "Movies": "folder-videos", "Desktop": "user-desktop" };
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

    // Date du détail des fichiers, format court de macOS en anglais (US) :
    // « Today at 3:41 PM », « Yesterday at 9:12 AM », sinon « 1/30/2025, 4:13 PM »
    // (capture MacRumors « spotlight-kind » : « 30/01/2025, 4:13 pm » en UK).
    function fileDate(ms) {
        if (!ms) return "";
        const d = new Date(ms), now = new Date();
        const day = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
        const diff = Math.round((day(now) - day(d)) / 86400000);
        const hm = Qt.formatTime(d, "h:mm AP");
        if (diff === 0) return "Today at " + hm;
        if (diff === 1) return "Yesterday at " + hm;
        return Qt.formatDate(d, "M/d/yyyy") + ", " + hm;
    }

    function fileItem(f, section) {
        const k = fileKindOf(f);
        const folder = f.dir === "" ? root.home.split("/").pop() : f.dir.split("/").pop();
        const date = fileDate(f.when);
        const size = f.isDir ? "" : sizeLabel(f.size);
        return {
            kind: "file", section: section ?? fileKindNames[k], fileKind: k, group: k,
            title: f.name, path: f.path, isDir: f.isDir,
            // « PDF document · 41 KB · 10/3/2024, 8:49 PM · Finance »
            subtitle: [kindLabel(f), size, date].filter(x => x).join(" · "),
            folder: folder,
            location: "~/" + (f.dir ? f.dir + "/" : ""),
            icon: fileIcon(f),
            // Vignette seulement pour les images dont la signature a été vérifiée
            // (pas de SVG : un SVG géant ferait exploser le tampon de rendu ;
            // un faux .jpg remplirait le journal d'erreurs de décodage)
            thumb: thumbOk[f.path] ? "file://" + encodeURI(f.path) : ""
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
                                 meta: img ? (img[3] + " × " + img[4] + " · " + img[1]) : "",
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
            title: c.isImage ? c.ext.toUpperCase() + " Image" : c.text.replace(/\s+/g, " ").trim(),
            subtitle: c.isImage ? "Image · " + c.meta : (isUrl ? "Link" : isPath ? "File" : "Text"),
            symbol: c.isImage ? "photo" : isUrl ? "link" : isPath ? "doc" : "text.alignleft",
            // Comme Tahoe : icône de document du type copié
            icon: Quickshell.iconPath(c.isImage ? "image-x-generic" : isUrl ? "text-html" : "text-x-generic", "text-x-generic"),
            thumb: c.isImage && c.ext !== "webp" ? (clipThumbs[c.id] ?? "") : "",
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

    // Groupes de la recherche générale, dans l'ordre d'affichage. Tahoe ne met
    // plus d'en-têtes de section : les résultats restent groupés dans cet
    // ordre et chaque groupe présent devient une pastille de filtre sous le
    // champ (« Applications », « Actions », « Documents »…).
    readonly property var groupNames: ({
        apps: "Applications", calc: "Calculator", conversion: "Conversion", actions: "Actions",
        documents: "Documents", pdf: "PDF", folders: "Folders", images: "Images"
    })
    // Filtre de groupe choisi ("" = tous)
    property string resultFilter: ""

    // Tous les résultats de la recherche générale (sans filtre)
    readonly property var allResults: buildAll()
    // Pastilles : groupes présents (au moins deux, sinon inutile)
    readonly property var resultGroups: {
        const seen = [];
        for (const it of allResults) if (it.group && it.group !== "web" && !seen.includes(it.group)) seen.push(it.group);
        return seen.length > 1 ? seen.map(g => ({ id: g, name: groupNames[g] ?? g })) : [];
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
            const items = matchActions(q ? 40 : 80);
            if (q) { pushSection(out, "", items); return out; }
            // Sans saisie : sections « Suggestions » (actions système) puis une
            // par app, en-têtes en gras comme Tahoe (capture Cult of Mac
            // « Spotlight-Actions » : Suggestions, Books…)
            const order = [], by = {};
            for (const it of items) {
                if (!by[it.section]) { by[it.section] = []; order.push(it.section); }
                by[it.section].push(it);
            }
            order.sort((x, y) => (x === "Suggestions" ? -1 : y === "Suggestions" ? 1 : x.localeCompare(y)));
            for (const sec of order) pushSection(out, sec, by[sec]);
            return out;
        }
        if (mode !== "") return out;           // Applications / Fichiers : grilles
        if (!resultFilter) return allResults;
        return allResults.filter(it => it.group === resultFilter);
    }

    function buildAll() {
        const out = [];
        if (!active || mode !== "" || !q) return out;

        // Les correspondances trop lâches (sous-séquences éparses) sont écartées.
        const apps = matchApps(8).filter(a => a.s >= 35);
        const calc = calcItem();
        const actions = matchActions(8).filter(a => Fuzzy.score(q, a.title) >= 35 || a.kind === "action" && q.length >= 3
                                                   && Fuzzy.score(q, systemActions.find(x => x.id === a.actionId).keywords) >= 60).slice(0, 4);
        // Comme Spotlight : correspondance en début de mot uniquement
        const files = rankedFiles().filter(f => Fuzzy.score(q, f.name) >= 60);
        const fileTopScore = files.length ? Fuzzy.score(q, files[0].name) : 0;

        // Meilleur résultat (en tête, sélectionné) : calcul, sinon app très
        // pertinente, sinon document dont le nom commence par la requête,
        // sinon action exacte
        let top = null;
        if (calc) top = calc;
        else if (apps.length && apps[0].s >= 50) top = appItem(apps[0].e, "Top Hit");
        else if (fileTopScore >= 80) top = fileItem(files[0]);
        else if (actions.length && Fuzzy.score(q, actions[0].title) >= 80) top = actions[0];
        if (top) out.push(Object.assign({}, top, { top: true }));

        const appRest = apps.filter(a => !(top && top.kind === "app" && top.id === a.e.id)).slice(0, 5);
        pushSection(out, "", appRest.map(a => appItem(a.e, "Applications")));
        pushSection(out, "", actions.filter(a => a !== top).slice(0, 3));

        // Fichiers par type, 4 max par groupe
        const groups = { folders: [], documents: [], pdf: [], images: [] };
        for (const f of files) {
            if (top && top.kind === "file" && top.path === f.path) continue;
            const k = fileKindOf(f);
            if (groups[k].length < 4) groups[k].push(fileItem(f));
        }
        pushSection(out, "", groups.documents);
        pushSection(out, "", groups.pdf);
        pushSection(out, "", groups.folders);
        pushSection(out, "", groups.images);

        // Toujours en dernier : recherche sur le Web
        out.push({ kind: "web", group: "web", title: query.trim(), subtitle: "Search the Web",
                   symbol: "globe", tint: "#0a84ff" });
        return out;
    }

    // Vue Applications (Tahoe) : une rangée de suggestions (apps les plus
    // utilisées, complétée par celles du Dock), un trait, puis toutes les apps
    // par ordre alphabétique. Pastille = filtre de catégorie ; la saisie
    // filtre à l'intérieur de la catégorie choisie.
    readonly property int suggestionCount: Metrics.gridColumns
    // Grille (vrai) ou Liste (faux) : la rangée de suggestions est propre à la
    // grille (capture Cult of Mac « Spotlight-Applications » : Safari, Mona…,
    // Music, un trait, puis toutes les apps de A à Z, suggestions comprises)
    property bool withSuggestions: true
    function buildAppGrid() {
        if (!active || mode !== "apps") return [];
        if (q) {
            return matchApps(0).filter(a => a.s >= 30)
                .map(a => appItem(a.e, ""))
                .filter(a => !appCategory || a.category === appCategory);
        }
        const all = root.apps.map(e => appItem(e, ""));
        if (appCategory) return all.filter(a => a.category === appCategory);
        // Vue Liste : uniquement toutes les apps (la rangée de suggestions
        // n'existe que dans la grille, sinon chaque suggestion serait listée
        // deux fois sans trait pour les séparer)
        if (!withSuggestions) return all;
        const used = root.apps.filter(e => usage.apps[e.id])
            .sort((a, b) => usageBoost(b.id) - usageBoost(a.id))
            .slice(0, suggestionCount);
        for (const id of Apps.pinned) {
            if (used.length >= suggestionCount) break;
            const e = Apps.entryFor(id);
            if (e && root.apps.includes(e) && !used.includes(e)) used.push(e);
        }
        if (!used.length) return all;
        return used.map(e => appItem(e, "")).concat([{ separator: true }], all);
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
