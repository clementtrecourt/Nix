import QtQuick
import Quickshell
import Quickshell.Io

// Contenu d'un dossier du Dock (Téléchargements) : liste lue par `find` (sans
// accès disque synchrone en QML), triée comme l'a choisi l'utilisateur
// (« Sort by » du menu de la pile) :
//   name          : nom, ordre alphabétique « naturel »
//   dateAdded     : date d'ajout au dossier, la plus récente d'abord. Linux ne la
//                   garde pas : on prend la date de changement d'état (ctime), mise
//                   à jour quand le fichier arrive dans le dossier (renommage du
//                   .part du navigateur, déplacement)
//   dateModified  : date de modification (mtime), la plus récente d'abord
//   dateCreated   : date de création (birth time, sinon mtime), la plus récente d'abord
//   kind          : type (dossiers, puis extension), puis nom
// Les aperçus viennent du cache de miniatures freedesktop (~/.cache/thumbnails,
// rempli par le gestionnaire de fichiers), sinon de l'icône du type de fichier.
Item {
    id: root
    visible: false

    property string folder: ""
    property string sortBy: "dateAdded"
    // Relecture périodique (seulement si quelqu'un regarde : pile ouverte, tuile en pile)
    property bool watching: true

    // [{ name, path, isDir, added, modified, created, ext }]
    property var entries: []
    readonly property var sorted: sortEntries(entries, sortBy)
    readonly property int count: entries.length

    function sortEntries(list, by) {
        const l = list.slice();
        const byName = (a, b) => a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: "base" });
        if (by === "name") l.sort(byName);
        else if (by === "dateModified") l.sort((a, b) => b.modified - a.modified || byName(a, b));
        else if (by === "dateCreated") l.sort((a, b) => b.created - a.created || byName(a, b));
        else if (by === "kind") l.sort((a, b) => (a.isDir === b.isDir ? 0 : a.isDir ? -1 : 1) || a.ext.localeCompare(b.ext) || byName(a, b));
        else l.sort((a, b) => b.added - a.added || byName(a, b));
        return l;
    }

    // Liste d'un dossier quelconque (sous-dossier ouvert dans la pile)
    function list(dir, cb) {
        const p = lister.createObject(root, { dir: dir });
        p.done.connect((items) => { cb(items); p.destroy(); });
        p.running = true;
    }

    function refresh() {
        if (!thumbProbe.running) thumbProbe.running = true;
        if (!folder || main.running) return;
        main.dir = folder;
        main.running = true;
    }
    // Miniatures présentes dans le cache (évite de charger des fichiers absents)
    property var thumbs: ({})
    Process {
        id: thumbProbe
        command: ["sh", "-c", "cd \"$1\" 2>/dev/null || exit 0; for d in large x-large; do [ -d $d ] && ls $d | sed \"s|^|$d/|\"; done; exit 0", "sh", root.thumbDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = {};
                for (const l of text.split("\n"))
                    if (l.endsWith(".png")) t[l] = true;
                if (JSON.stringify(t) !== JSON.stringify(root.thumbs)) root.thumbs = t;
            }
        }
    }
    onFolderChanged: refresh()
    Component.onCompleted: refresh()
    Timer {
        interval: 4000
        repeat: true
        running: root.watching && root.folder !== ""
        onTriggered: root.refresh()
    }

    function parse(text, dir) {
        const out = [];
        for (const line of text.split("\n")) {
            if (!line) continue;
            const f = line.split("\t");
            if (f.length < 5) continue;
            const name = f.slice(4).join("\t");
            const isDir = f[3] === "d";
            const dot = name.lastIndexOf(".");
            const created = parseFloat(f[2]);
            out.push({
                name: name,
                path: dir.replace(/\/$/, "") + "/" + name,
                isDir: isDir,
                added: parseFloat(f[0]) || 0,
                modified: parseFloat(f[1]) || 0,
                created: created > 0 ? created : (parseFloat(f[1]) || 0),
                ext: isDir ? "" : (dot > 0 ? name.slice(dot + 1).toLowerCase() : "")
            });
        }
        return out;
    }

    // %C@ ctime, %T@ mtime, %B@ création, %y type, %f nom (fichiers cachés exclus)
    readonly property var findArgs: ["-mindepth", "1", "-maxdepth", "1", "!", "-name", ".*",
                                     "-printf", "%C@\\t%T@\\t%B@\\t%y\\t%f\\n"]
    Process {
        id: main
        property string dir
        command: ["find", dir].concat(root.findArgs)
        stdout: StdioCollector {
            onStreamFinished: {
                const l = root.parse(text, main.dir);
                if (JSON.stringify(l) !== JSON.stringify(root.entries)) root.entries = l;
            }
        }
    }
    Component {
        id: lister
        Process {
            id: p
            property string dir
            signal done(var items)
            command: ["find", dir].concat(root.findArgs)
            stdout: StdioCollector { onStreamFinished: p.done(root.parse(text, p.dir)) }
        }
    }

    // ---- Aperçus ----
    function isImage(name) { return /\.(png|jpe?g|gif|webp|bmp|svg|avif)$/i.test(name); }
    // URI d'un chemin, échappée comme GLib (g_filename_to_uri) pour le cache de miniatures
    function uriOf(path) {
        return "file://" + path.split("/").map(s => encodeURIComponent(s)
            .replace(/%24/g, "$").replace(/%26/g, "&").replace(/%2B/g, "+").replace(/%2C/g, ",")
            .replace(/%3B/g, ";").replace(/%3D/g, "=").replace(/%3A/g, ":").replace(/%40/g, "@")).join("/");
    }
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/thumbnails/"
    // Miniature freedesktop (x-large si demandée et présente, sinon large), "" sinon
    function thumbFor(path, big) {
        const h = Qt.md5(uriOf(path)) + ".png";
        if (big && thumbs["x-large/" + h]) return "file://" + thumbDir + "x-large/" + h;
        if (thumbs["large/" + h]) return "file://" + thumbDir + "large/" + h;
        return "";
    }
    // Icône du thème d'après l'extension (pas de base MIME côté QML)
    function iconFor(name, isDir) {
        if (isDir) return Quickshell.iconPath("folder", "folder");
        const ext = (name.split(".").pop() || "").toLowerCase();
        const map = {
            pdf: "application-pdf", zip: "application-zip", gz: "application-x-compressed-tar",
            xz: "application-x-compressed-tar", tar: "application-x-tar", "7z": "application-x-7z-compressed",
            json: "application-json", txt: "text-plain", md: "text-markdown", html: "text-html",
            wav: "audio-x-wav", mp3: "audio-mpeg", flac: "audio-flac", ogg: "audio-x-vorbis+ogg",
            mp4: "video-mp4", mkv: "video-x-matroska", webm: "video-webm", mov: "video-quicktime",
            iso: "application-x-cd-image", deb: "application-x-deb", rpm: "application-x-rpm",
            dmg: "application-x-apple-diskimage",
            doc: "x-office-document", docx: "x-office-document", odt: "x-office-document",
            xls: "x-office-spreadsheet", xlsx: "x-office-spreadsheet", ods: "x-office-spreadsheet",
            ppt: "x-office-presentation", pptx: "x-office-presentation", odp: "x-office-presentation",
            py: "text-x-python", js: "text-x-javascript", sh: "application-x-shellscript",
            nix: "text-x-nix", safetensors: "application-octet-stream"
        };
        return Quickshell.iconPath(map[ext] ?? "text-x-generic", "text-x-generic");
    }
}
