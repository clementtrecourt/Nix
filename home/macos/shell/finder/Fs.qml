pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Outils du Finder partagés par toutes les fenêtres : types de fichiers
// (« Kind » de macOS, déduit de l'extension comme les UTI), icônes du thème,
// formats de taille / date au format macOS (anglais US), presse-papiers de
// fichiers, opérations (corbeille, copie, déplacement, duplication, alias,
// compression, renommage), tags, emplacements de la barre latérale.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/root"
    readonly property string user: Quickshell.env("USER") || home.split("/").pop()
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")) + "/macos-shell/finder"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/macos-shell"
    readonly property string trashDir: (Quickshell.env("XDG_DATA_HOME") || (home + "/.local/share")) + "/Trash"

    // Dossiers XDG (lus dans ~/.config/user-dirs.dirs, sinon noms anglais)
    property var xdg: ({
        DESKTOP: home + "/Desktop",
        DOCUMENTS: home + "/Documents",
        DOWNLOAD: home + "/Downloads",
        MUSIC: home + "/Music",
        PICTURES: home + "/Pictures",
        VIDEOS: home + "/Videos"
    })
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")) + "/user-dirs.dirs"
        printErrors: false
        onLoaded: {
            const o = Object.assign({}, root.xdg);
            for (const l of text().split("\n")) {
                const m = /^XDG_([A-Z]+)_DIR="?([^"]*)"?/.exec(l.trim());
                if (m) o[m[1]] = m[2].replace("$HOME", root.home);
            }
            root.xdg = o;
        }
    }

    // ---------------------------------------------------------------- chemins
    function basename(p) {
        if (!p || p === "/") return "/";
        const s = p.endsWith("/") ? p.slice(0, -1) : p;
        return s.slice(s.lastIndexOf("/") + 1);
    }
    function dirname(p) {
        if (!p || p === "/") return "/";
        const s = p.endsWith("/") ? p.slice(0, -1) : p;
        const i = s.lastIndexOf("/");
        return i <= 0 ? "/" : s.slice(0, i);
    }
    function join(dir, name) { return dir === "/" ? "/" + name : dir + "/" + name; }
    function ext(name) {
        const i = name.lastIndexOf(".");
        return i > 0 ? name.slice(i + 1).toLowerCase() : "";
    }
    function stem(name) {
        const i = name.lastIndexOf(".");
        return i > 0 ? name.slice(0, i) : name;
    }
    function fileUrl(p) { return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F"); }
    function isVirtual(p) { return p.indexOf("://") > 0; }

    // Nom affiché d'un dossier (barre de titre, barre de chemin) comme le Finder
    function displayName(p) {
        if (p === "recents://") return "Recents";
        if (p === "applications://") return "Applications";
        if (p === "trash://") return "Trash";
        if (p === "network://") return "Network";
        if (p === "computer://") return root.computerName;
        if (p.startsWith("tag://")) return p.slice(6);
        if (p === "/") return root.rootVolumeName;
        return basename(p);
    }

    // Nom de l'ordinateur et du disque système (« Macintosh HD »)
    property string computerName: "Mac"
    property string rootVolumeName: "Macintosh HD"

    // ---------------------------------------------------------------- types
    // Extension -> [Kind macOS (en), type MIME (icône du thème), catégorie]
    // Catégories : image, movie, audio, text, pdf, archive, code, doc, app, font, disk
    readonly property var kinds: ({
        png: ["PNG image", "image/png", "image"],
        jpg: ["JPEG image", "image/jpeg", "image"],
        jpeg: ["JPEG image", "image/jpeg", "image"],
        gif: ["GIF image", "image/gif", "image"],
        webp: ["WebP Image", "image/webp", "image"],
        heic: ["HEIF image", "image/heif", "image"],
        heif: ["HEIF image", "image/heif", "image"],
        avif: ["AVIF image", "image/avif", "image"],
        bmp: ["Windows BMP image", "image/bmp", "image"],
        tif: ["TIFF image", "image/tiff", "image"],
        tiff: ["TIFF image", "image/tiff", "image"],
        ico: ["Windows icon image", "image/x-ico", "image"],
        svg: ["SVG image", "image/svg+xml", "image"],
        psd: ["Adobe Photoshop file", "image/vnd.adobe.photoshop", "image"],
        raw: ["Raw image", "image/x-dcraw", "image"],
        dng: ["DNG image", "image/x-adobe-dng", "image"],
        xcf: ["GIMP image", "image/x-xcf", "doc"],
        pdf: ["PDF Document", "application/pdf", "pdf"],
        txt: ["Plain Text", "text/plain", "text"],
        text: ["Plain Text", "text/plain", "text"],
        log: ["Log File", "text/x-log", "text"],
        md: ["Markdown", "text/markdown", "text"],
        markdown: ["Markdown", "text/markdown", "text"],
        rtf: ["RTF Document", "application/rtf", "text"],
        csv: ["comma-separated values", "text/csv", "text"],
        tsv: ["tab-separated values", "text/tab-separated-values", "text"],
        html: ["HTML text", "text/html", "code"],
        htm: ["HTML text", "text/html", "code"],
        xml: ["XML text", "application/xml", "code"],
        json: ["JSON", "application/json", "code"],
        yaml: ["YAML", "application/x-yaml", "code"],
        yml: ["YAML", "application/x-yaml", "code"],
        toml: ["TOML", "application/toml", "code"],
        ini: ["Configuration settings", "text/plain", "code"],
        conf: ["Configuration settings", "text/plain", "code"],
        css: ["CSS style sheet", "text/css", "code"],
        js: ["JavaScript script", "application/javascript", "code"],
        mjs: ["JavaScript script", "application/javascript", "code"],
        ts: ["TypeScript source", "text/x-typescript", "code"],
        tsx: ["TypeScript source", "text/x-typescript", "code"],
        jsx: ["JavaScript script", "application/javascript", "code"],
        py: ["Python Script", "text/x-python", "code"],
        sh: ["Shell Script", "application/x-shellscript", "code"],
        bash: ["Shell Script", "application/x-shellscript", "code"],
        zsh: ["Shell Script", "application/x-shellscript", "code"],
        fish: ["Shell Script", "application/x-shellscript", "code"],
        c: ["C Source", "text/x-csrc", "code"],
        h: ["C Header Source", "text/x-chdr", "code"],
        cpp: ["C++ Source", "text/x-c++src", "code"],
        cc: ["C++ Source", "text/x-c++src", "code"],
        hpp: ["C++ Header Source", "text/x-c++hdr", "code"],
        m: ["Objective-C Source", "text/x-objcsrc", "code"],
        swift: ["Swift Source", "text/x-swift", "code"],
        rs: ["Rust Source", "text/rust", "code"],
        go: ["Go Source", "text/x-go", "code"],
        java: ["Java Source", "text/x-java", "code"],
        rb: ["Ruby Script", "application/x-ruby", "code"],
        php: ["PHP Script", "application/x-php", "code"],
        lua: ["Lua Script", "text/x-lua", "code"],
        nix: ["Nix Expression", "text/x-nix", "code"],
        qml: ["QML Source", "text/x-qml", "code"],
        sql: ["SQL Source", "application/sql", "code"],
        diff: ["Patch file", "text/x-patch", "code"],
        patch: ["Patch file", "text/x-patch", "code"],
        zip: ["ZIP archive", "application/zip", "archive"],
        tar: ["tar archive", "application/x-tar", "archive"],
        gz: ["gzip compressed archive", "application/gzip", "archive"],
        tgz: ["gzip compressed tar archive", "application/x-compressed-tar", "archive"],
        bz2: ["bzip2 compressed archive", "application/x-bzip", "archive"],
        xz: ["XZ compressed archive", "application/x-xz", "archive"],
        zst: ["Zstandard archive", "application/zstd", "archive"],
        "7z": ["7-Zip archive", "application/x-7z-compressed", "archive"],
        rar: ["RAR archive", "application/vnd.rar", "archive"],
        dmg: ["Disk Image", "application/x-apple-diskimage", "disk"],
        iso: ["Disk Image", "application/x-cd-image", "disk"],
        img: ["Disk Image", "application/x-raw-disk-image", "disk"],
        mp3: ["MP3 audio", "audio/mpeg", "audio"],
        m4a: ["Apple MPEG-4 audio", "audio/mp4", "audio"],
        aac: ["ADTS audio", "audio/aac", "audio"],
        wav: ["Waveform audio", "audio/x-wav", "audio"],
        flac: ["FLAC audio", "audio/flac", "audio"],
        ogg: ["Ogg Vorbis audio", "audio/x-vorbis+ogg", "audio"],
        opus: ["Opus audio", "audio/x-opus+ogg", "audio"],
        aiff: ["AIFF-C audio", "audio/x-aiff", "audio"],
        mp4: ["MPEG-4 movie", "video/mp4", "movie"],
        m4v: ["MPEG-4 movie", "video/mp4", "movie"],
        mov: ["QuickTime movie", "video/quicktime", "movie"],
        mkv: ["Matroska video", "video/x-matroska", "movie"],
        webm: ["WebM video", "video/webm", "movie"],
        avi: ["AVI movie", "video/x-msvideo", "movie"],
        doc: ["Microsoft Word 97 - 2004 document", "application/msword", "doc"],
        docx: ["Microsoft Word document", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "doc"],
        xls: ["Microsoft Excel 97 - 2004 workbook", "application/vnd.ms-excel", "doc"],
        xlsx: ["Microsoft Excel workbook", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "doc"],
        ppt: ["PowerPoint 97 - 2004 presentation", "application/vnd.ms-powerpoint", "doc"],
        pptx: ["PowerPoint presentation", "application/vnd.openxmlformats-officedocument.presentationml.presentation", "doc"],
        odt: ["OpenDocument text", "application/vnd.oasis.opendocument.text", "doc"],
        ods: ["OpenDocument spreadsheet", "application/vnd.oasis.opendocument.spreadsheet", "doc"],
        odp: ["OpenDocument presentation", "application/vnd.oasis.opendocument.presentation", "doc"],
        pages: ["Pages Document", "application/x-iwork-pages-sffpages", "doc"],
        numbers: ["Numbers Spreadsheet", "application/x-iwork-numbers-sffnumbers", "doc"],
        key: ["Keynote Presentation", "application/x-iwork-keynote-sffkey", "doc"],
        epub: ["EPUB document", "application/epub+zip", "doc"],
        ttf: ["TrueType® font", "font/ttf", "font"],
        otf: ["OpenType® font", "font/otf", "font"],
        woff: ["Web Open Font Format", "font/woff", "font"],
        woff2: ["Web Open Font Format 2", "font/woff2", "font"],
        desktop: ["Desktop entry", "application/x-desktop", "app"],
        appimage: ["AppImage", "application/vnd.appimage", "app"],
        exe: ["Windows executable", "application/x-ms-dos-executable", "app"],
        deb: ["Debian package", "application/vnd.debian.binary-package", "archive"],
        rpm: ["RPM package", "application/x-rpm", "archive"],
        torrent: ["BitTorrent document", "application/x-bittorrent", "doc"],
        ics: ["ICS file", "text/calendar", "doc"],
        vcf: ["vCard", "text/vcard", "doc"],
        pem: ["certificate", "application/x-pem-file", "doc"],
        crt: ["certificate", "application/x-x509-ca-cert", "doc"],
        db: ["Document", "application/x-sqlite3", "doc"],
        sqlite: ["SQLite database", "application/vnd.sqlite3", "doc"]
    })

    // Description d'un élément de liste : { name, isDir, isLink, exec, ... }
    function kindOf(e) {
        if (e.app) return "Application";
        if (e.isLink && e.broken) return "Alias";
        if (e.isDir) return e.isLink ? "Alias" : (e.volume ? "Volume" : "Folder");
        if (e.isLink) return "Alias";
        const k = kinds[ext(e.name)];
        if (k) return k[0];
        if (e.exec) return "Unix executable File";
        return "Document";
    }
    function mimeOf(e) {
        if (e.isDir) return "inode/directory";
        const k = kinds[ext(e.name)];
        if (k) return k[1];
        if (e.exec) return "application/x-executable";
        return "text/plain";
    }
    function category(e) {
        if (e.app) return "app";
        if (e.isDir) return "folder";
        const k = kinds[ext(e.name)];
        if (k) return k[2];
        return e.exec ? "exec" : "other";
    }
    function isImage(e) { return !e.isDir && category(e) === "image" && ext(e.name) !== "psd" && ext(e.name) !== "raw" && ext(e.name) !== "dng"; }
    function isText(e) { const c = category(e); return !e.isDir && (c === "text" || c === "code" || (c === "other" && e.size < 512 * 1024)); }

    // Icône de dossier : les dossiers spéciaux ont leur pictogramme (Tahoe)
    function folderIcon(p) {
        const special = {};
        special[root.home] = "user-home";
        special[root.xdg.DESKTOP] = "user-desktop";
        special[root.xdg.DOCUMENTS] = "folder-documents";
        special[root.xdg.DOWNLOAD] = "folder-download";
        special[root.xdg.MUSIC] = "folder-music";
        special[root.xdg.PICTURES] = "folder-pictures";
        special[root.xdg.VIDEOS] = "folder-videos";
        special[root.home + "/Applications"] = "folder-applications";
        special[root.home + "/Public"] = "folder-publicshare";
        special[root.home + "/Movies"] = "folder-videos";
        special[root.trashDir + "/files"] = "user-trash";
        return special[p] ?? "folder";
    }

    // Chemin d'icône du thème pour un élément (mis en cache par nom d'icône)
    property var _iconCache: ({})
    function themeIcon(name, fallback) {
        const key = name + "|" + fallback;
        let v = _iconCache[key];
        if (v === undefined) {
            v = Quickshell.iconPath(name, true);
            if (!v) v = Quickshell.iconPath(fallback, "text-x-generic");
            _iconCache[key] = v;
        }
        return v;
    }
    function iconFor(e) {
        if (e.icon) return e.icon.startsWith("/") ? "file://" + e.icon : themeIcon(e.icon, "application-x-executable");
        if (e.volume) return themeIcon(e.volumeIcon ?? "drive-harddisk", "drive-harddisk");
        if (e.isDir) return themeIcon(folderIcon(e.path), "folder");
        const m = mimeOf(e);
        const generic = m.split("/")[0] + "-x-generic";
        const c = category(e);
        const fb = c === "archive" ? "package-x-generic" : c === "code" ? "text-x-script" : c === "exec" ? "application-x-executable" : generic;
        return themeIcon(m.replace("/", "-"), fb);
    }

    // ---------------------------------------------------------------- formats
    // Tailles comme le Finder (base 1000) : « Zero bytes », « 923 bytes »,
    // « 46 KB », « 1.6 MB », « 2 MB », « 15.5 MB »
    function formatSize(n) {
        if (n === undefined || n === null || n < 0) return "--";
        if (n === 0) return "Zero bytes";
        if (n === 1) return "1 byte";
        if (n < 1000) return n + " bytes";
        if (n < 1e6) return Math.round(n / 1e3) + " KB";
        const units = ["MB", "GB", "TB", "PB"];
        let v = n / 1e6, i = 0;
        while (v >= 1000 && i < units.length - 1) { v /= 1000; ++i; }
        return (Math.round(v * 10) / 10).toString() + " " + units[i];
    }
    // Espace disponible (barre d'état) : deux décimales (« 2.27 TB available »)
    function formatAvail(n) {
        if (n < 1e9) return formatSize(n);
        const units = ["GB", "TB", "PB"];
        let v = n / 1e9, i = 0;
        while (v >= 1000 && i < units.length - 1) { v /= 1000; ++i; }
        return v.toFixed(2) + " " + units[i];
    }
    // Taille exacte (Lire les informations) : « 46,201 bytes (49 KB on disk) »
    function formatBytes(n) { return Number(n).toLocaleString(Qt.locale("en_US"), "f", 0) + " bytes"; }

    readonly property var _months: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    readonly property var _monthsLong: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var _days: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    // Heure macOS en anglais : « 9:12 AM » (espace fine insécable avant AM/PM)
    function formatTime(d) {
        let h = d.getHours();
        const ap = h >= 12 ? "PM" : "AM";
        h = h % 12;
        if (h === 0) h = 12;
        return h + ":" + String(d.getMinutes()).padStart(2, "0") + " " + ap;
    }
    // Colonne « Date Modified » : « Today at 9:12 AM », « Yesterday at … »,
    // « Sep 9, 2025 at 8:29 PM »
    property real now: Date.now()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.now = Date.now() }
    function formatDate(secs) {
        if (!secs) return "--";
        const d = new Date(secs * 1000);
        const today = new Date(root.now);
        today.setHours(0, 0, 0, 0);
        const day = new Date(d);
        day.setHours(0, 0, 0, 0);
        const diff = Math.round((today - day) / 86400000);
        if (diff === 0) return "Today at " + formatTime(d);
        if (diff === 1) return "Yesterday at " + formatTime(d);
        return _months[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear() + " at " + formatTime(d);
    }
    // Forme longue (Lire les informations, Coup d'œil) :
    // « Wednesday, June 25, 2025 at 10:46 AM »
    function formatDateLong(secs) {
        if (!secs) return "--";
        const d = new Date(secs * 1000);
        return _days[d.getDay()] + ", " + _monthsLong[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear() + " at " + formatTime(d);
    }
    // Date courte de la présentation Galerie / Colonnes (aperçu)
    function formatDateMedium(secs) {
        if (!secs) return "--";
        const d = new Date(secs * 1000);
        return _monthsLong[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear() + " at " + formatTime(d);
    }
    function itemsLabel(n) { return n === 1 ? "1 item" : n + " items"; }

    // ---------------------------------------------------------------- tags
    // Tags du Finder (couleurs macOS), persistés dans un JSON : { chemin: [tags] }
    readonly property var tagList: [
        { name: "Red", color: "#FF3B30", darkColor: "#FF453A" },
        { name: "Orange", color: "#FF9500", darkColor: "#FF9F0A" },
        { name: "Yellow", color: "#FFCC00", darkColor: "#FFD60A" },
        { name: "Green", color: "#28CD41", darkColor: "#32D74B" },
        { name: "Blue", color: "#007AFF", darkColor: "#0A84FF" },
        { name: "Purple", color: "#AF52DE", darkColor: "#BF5AF2" },
        { name: "Gray", color: "#8E8E93", darkColor: "#98989D" }
    ]
    function tagColor(name) {
        const t = tagList.find(x => x.name === name);
        return t ? (Theme.dark ? t.darkColor : t.color) : Theme.labelSecondary;
    }
    property var tags: ({})
    readonly property string tagsFile: stateDir + "/finder-tags.json"
    FileView {
        id: tagsView
        path: root.tagsFile
        printErrors: false
        onLoaded: { try { root.tags = JSON.parse(text()); } catch (e) { root.tags = {}; } }
    }
    function tagsOf(p) { return tags[p] ?? []; }
    function toggleTag(paths, name) {
        const o = Object.assign({}, tags);
        const allHave = paths.every(p => (o[p] ?? []).includes(name));
        for (const p of paths) {
            const cur = (o[p] ?? []).filter(t => t !== name);
            if (!allHave) cur.push(name);
            if (cur.length) o[p] = cur; else delete o[p];
        }
        tags = o;
        run(["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$3"', "sh", stateDir, JSON.stringify(o), tagsFile]);
    }
    // Les tags suivent un renommage / déplacement
    function moveTags(from, to) {
        if (!tags[from]) return;
        const o = Object.assign({}, tags);
        o[to] = o[from];
        delete o[from];
        tags = o;
        run(["sh", "-c", 'mkdir -p "$1" && printf "%s" "$2" > "$3"', "sh", stateDir, JSON.stringify(o), tagsFile]);
    }

    // ---------------------------------------------------------------- presse-papiers
    // Copier (⌘C) puis Coller (⌘V) ; ⌥⌘V déplace (« Move Item Here »)
    property var clipboard: []
    function copyToClipboard(paths) {
        clipboard = paths.slice();
        // Aussi dans le presse-papiers Wayland (text/uri-list) pour les autres apps
        run(["sh", "-c", 'command -v wl-copy >/dev/null && printf "%s" "$1" | wl-copy -t text/uri-list', "sh",
             paths.map(p => fileUrl(p)).join("\r\n")]);
    }

    // ---------------------------------------------------------------- opérations
    // Les fenêtres se rafraîchissent d'elles-mêmes (surveillance du dossier) ;
    // `changed` force un rafraîchissement immédiat de tous les dossiers ouverts.
    signal changed(var dirs)

    component Job: Process {
        property var dirs: []
        property var done: null
        onExited: (code) => {
            root.changed(dirs);
            if (done) done(code);
            destroy();
        }
    }
    Component { id: jobComp; Job {} }

    // Lance une commande ; `dirs` : dossiers touchés ; `done(code)` : rappel
    function run(cmd, dirs, done) {
        const j = jobComp.createObject(root, { command: cmd, dirs: dirs ?? [], done: done ?? null });
        j.running = true;
        return j;
    }

    // Nom libre dans un dossier : « name 2.ext », « name 3.ext »… (ou suffixe)
    function uniqueName(existing, base, extension, firstSuffix) {
        const set = new Set(existing);
        const dot = extension ? "." + extension : "";
        let cand = base + (firstSuffix ?? "") + dot;
        if (!set.has(cand)) return cand;
        for (let i = 2; i < 10000; ++i) {
            cand = base + (firstSuffix ?? "") + " " + i + dot;
            if (!set.has(cand)) return cand;
        }
        return base + " " + Date.now() + dot;
    }
    // Sépare nom et extension comme le Finder (un dossier n'a pas d'extension)
    function splitName(name, isDir) {
        const e = isDir ? "" : ext(name);
        return { base: e ? name.slice(0, name.length - e.length - 1) : name, ext: e ? name.slice(name.length - e.length) : "" };
    }

    function trash(paths, done) {
        if (!paths.length) return;
        run(["gio", "trash", "--"].concat(paths), paths.map(p => dirname(p)), done);
    }
    function mkdir(path, done) { run(["mkdir", "-p", "--", path], [dirname(path)], done); }
    function rename(from, to, done) {
        moveTags(from, to);
        run(["mv", "-n", "--", from, to], [dirname(from)], done);
    }
    // Copie / déplacement vers destDir ; existing : noms déjà présents.
    // Même dossier (copie) : « name copy », sinon conflit -> « name 2 ».
    function transfer(paths, destDir, existing, move, done) {
        const names = existing.slice();
        const script = [];
        const args = [];
        for (const p of paths) {
            if (move && dirname(p) === destDir) continue;
            if (destDir === p || destDir.startsWith(p + "/")) continue;   // dans lui-même
            const sp = splitName(basename(p), false);
            let n = basename(p);
            if (names.includes(n)) n = dirname(p) === destDir ? uniqueName(names, sp.base, sp.ext, " copy") : uniqueName(names, sp.base, sp.ext);
            names.push(n);
            args.push(p, join(destDir, n));
            if (move) moveTags(p, join(destDir, n));
        }
        if (!args.length) { if (done) done(0, []); return; }
        const op = move ? 'mv -n -- "$1" "$2"' : 'cp -a --reflink=auto -- "$1" "$2"';
        const created = [];
        for (let i = 1; i < args.length; i += 2) created.push(args[i]);
        run(["sh", "-c", 'while [ $# -gt 1 ]; do ' + op + '; shift 2; done', "sh"].concat(args),
            [destDir].concat(paths.map(p => dirname(p))), code => { if (done) done(code, created); });
    }
    function duplicate(paths, existing, done) {
        const names = existing.slice();
        const args = [];
        const created = [];
        for (const p of paths) {
            const sp = splitName(basename(p), false);
            const n = uniqueName(names, sp.base, sp.ext, " copy");
            names.push(n);
            args.push(p, join(dirname(p), n));
            created.push(join(dirname(p), n));
        }
        run(["sh", "-c", 'while [ $# -gt 1 ]; do cp -a --reflink=auto -- "$1" "$2"; shift 2; done', "sh"].concat(args),
            paths.map(p => dirname(p)), code => { if (done) done(code, created); });
    }
    function makeAlias(paths, existing, done) {
        const names = existing.slice();
        const args = [];
        const created = [];
        for (const p of paths) {
            const n = uniqueName(names, basename(p) + " alias", "", "");
            names.push(n);
            args.push(p, join(dirname(p), n));
            created.push(join(dirname(p), n));
        }
        run(["sh", "-c", 'while [ $# -gt 1 ]; do ln -s -- "$1" "$2"; shift 2; done', "sh"].concat(args),
            paths.map(p => dirname(p)), code => { if (done) done(code, created); });
    }
    // Compresser : un élément -> « name.zip », plusieurs -> « Archive.zip »
    function compress(paths, existing, done) {
        if (!paths.length) return;
        const dir = dirname(paths[0]);
        const base = paths.length === 1 ? basename(paths[0]) : "Archive";
        const n = uniqueName(existing, base, "zip");
        run(["sh", "-c", 'cd "$1" && shift && out="$1" && shift && zip -qry "$out" "$@"', "sh", dir, n]
            .concat(paths.map(p => basename(p))), [dir], code => { if (done) done(code, [join(dir, n)]); });
    }
    function open(path) { run(["sh", "-c", 'gio open "$1" 2>/dev/null || xdg-open "$1"', "sh", path]); }
    function openWith(path, desktopId) {
        run(["sh", "-c", 'gio launch "$1" "$2" 2>/dev/null || gtk-launch "$(basename "$1" .desktop)" "$2"', "sh", desktopId, path]);
    }
    function emptyTrash() {
        run(["sh", "-c", 'gio trash --empty 2>/dev/null || rm -rf -- "$1"/files/* "$1"/info/*', "sh", trashDir], [trashDir + "/files"]);
    }
    function restoreFromTrash(names) {
        // Lit Path= dans le .trashinfo et remet l'élément à sa place
        run(["sh", "-c", `d="$1"; shift
            for n in "$@"; do
                p=$(sed -n 's/^Path=//p' "$d/info/$n.trashinfo" | head -1)
                p=$(printf '%b' "$(printf '%s' "$p" | sed 's/%/\\\\x/g')")
                [ -n "$p" ] && mkdir -p "$(dirname "$p")" && mv -n -- "$d/files/$n" "$p" && rm -f "$d/info/$n.trashinfo"
            done`, "sh", trashDir].concat(names), [trashDir + "/files"]);
    }
    function revealInTerminal(dir) { run(["sh", "-c", 'cd "$1" && exec ${TERMINAL:-kitty}', "sh", dir]); }

    // ---------------------------------------------------------------- emplacements
    // Disques montés (barre latérale > Locations) : [{ name, path, removable, icon }]
    property var volumes: []
    property var _volProc: Process {
        command: ["sh", "-c", "cat /proc/sys/kernel/hostname; echo '--'; lsblk -J -b -o NAME,LABEL,MOUNTPOINTS,SIZE,RM,HOTPLUG,TYPE,FSTYPE,MODEL 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const i = text.indexOf("--");
                const host = text.slice(0, i).trim();
                if (host) root.computerName = host;
                const vols = [];
                try {
                    const j = JSON.parse(text.slice(i + 2));
                    const walk = (dev, parentRm) => {
                        const rm = dev.rm || dev.hotplug || parentRm;
                        const mps = (dev.mountpoints ?? []).filter(m => m);
                        for (const m of mps) {
                            if (m === "/" ) {
                                if (dev.label) root.rootVolumeName = dev.label;
                                continue;
                            }
                            if (m.startsWith("/boot") || m === "/nix" || m.startsWith("/nix/") || m === "[SWAP]" || m.startsWith("/var") || m === "/home") continue;
                            if (!rm && !m.startsWith("/run/media") && !m.startsWith("/media") && !m.startsWith("/mnt")) continue;
                            vols.push({ name: dev.label || basename(m), path: m, removable: !!rm, icon: rm ? "drive-removable-media" : "drive-harddisk" });
                        }
                        for (const c of dev.children ?? []) walk(c, rm);
                    };
                    for (const d of j.blockdevices ?? []) walk(d, false);
                } catch (e) {}
                root.volumes = vols;
            }
        }
    }
    function refreshVolumes() { _volProc.running = true; }
    Component.onCompleted: refreshVolumes()
    // Montages / démontages : rafraîchit la liste toutes les 5 s (léger)
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refreshVolumes() }
    function eject(path) { run(["sh", "-c", 'gio mount -u "$1" 2>/dev/null || umount "$1"', "sh", path], [], () => root.refreshVolumes()); }
}
