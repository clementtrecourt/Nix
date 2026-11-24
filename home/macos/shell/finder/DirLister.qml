import QtQuick
import Quickshell
import Quickshell.Io

// Contenu d'un dossier (ou d'un emplacement virtuel : recents://,
// applications://, trash://, tag://<Tag>), lu en asynchrone avec find(1) et
// surveillé (inotifywait, sinon scrutation du mtime) : la liste se met à jour
// toute seule quand le dossier change.
//
// entries : [{ name, path, isDir, isLink, broken, size, mtime, atime, btime,
//              exec, blocks, hidden, target, ... }] (non trié)
Item {
    id: root

    property string path: ""
    property bool showHidden: false
    property bool watch: true
    // Le dossier est lisible (faux : n'existe pas / accès refusé)
    property bool ok: true
    property bool loading: false
    property var entries: []
    // Nombre d'éléments affichés (après filtrage des fichiers cachés)
    readonly property var visibleEntries: showHidden ? entries : entries.filter(e => !e.hidden)
    signal loaded()

    visible: false

    // Champs de find -printf (séparateur \037, fin d'élément \0)
    readonly property string _fmt: "%p\\037%y\\037%Y\\037%s\\037%T@\\037%m\\037%l\\037%b\\037%A@\\037%B@\\000"

    function reload() {
        if (!path) return;
        if (path === "applications://") { listApplications(); return; }
        loading = true;
        proc.running = false;
        if (path === "recents://") proc.command = ["sh", "-c", root._recentsScript, "sh", root._fmt];
        else if (path === "trash://") proc.command = ["sh", "-c", 'd="$2/files"; [ -d "$d" ] || exit 0; find "$d" -mindepth 1 -maxdepth 1 -printf "$1"', "sh", root._fmt, Fs.trashDir];
        else if (path.startsWith("tag://")) {
            const tag = path.slice(6);
            const ps = Object.keys(Fs.tags).filter(p => Fs.tags[p].includes(tag));
            proc.command = ["sh", "-c", 'f="$1"; shift; for p; do [ -e "$p" ] || [ -L "$p" ] && find "$p" -maxdepth 0 -printf "$f"; done; exit 0', "sh", root._fmt].concat(ps);
        } else if (path === "network://" || path === "computer://") {
            loading = false;
            entries = path === "computer://" ? computerEntries() : [];
            ok = true;
            loaded();
            return;
        } else proc.command = ["sh", "-c", '[ -d "$2" ] && [ -r "$2" ] && [ -x "$2" ] || { echo "#ERR"; exit 1; }; find "$2" -mindepth 1 -maxdepth 1 -printf "$1" 2>/dev/null; exit 0', "sh", root._fmt, root.path];
        proc.running = true;
    }

    // Récents : fichiers du journal recently-used.xbel (les plus récents d'abord)
    readonly property string _recentsScript: `
        f="$XDG_DATA_HOME"; [ -n "$f" ] || f="$HOME/.local/share"; f="$f/recently-used.xbel"
        [ -r "$f" ] || exit 0
        grep -o '<bookmark [^>]*>' "$f" | sed -En 's|.*href="file://([^"]*)".*visited="([^"]*)".*|\\2 \\1|p' | sort -r | head -n 200 |
        while read -r t u; do
            p=$(printf '%b' "$(printf '%s' "$u" | sed 's/%/\\\\x/g')")
            [ -f "$p" ] && find "$p" -maxdepth 0 -printf "$1"
        done
        exit 0`

    function computerEntries() {
        const l = [{ name: Fs.rootVolumeName, path: "/", isDir: true, volume: true, volumeIcon: "drive-harddisk-system", size: -1, mtime: 0 }];
        for (const v of Fs.volumes) l.push({ name: v.name, path: v.path, isDir: true, volume: true, volumeIcon: v.icon, size: -1, mtime: 0 });
        l.push({ name: "Network", path: "network://", isDir: true, icon: "network-workgroup", size: -1, mtime: 0 });
        return l;
    }

    // Applications : entrées .desktop visibles (lancées au double-clic)
    function listApplications() {
        const l = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue;
            l.push({ name: e.name, path: "app://" + e.id, isDir: false, app: e, icon: e.icon || "application-x-executable",
                     size: -1, mtime: 0, hidden: false });
        }
        entries = l;
        ok = true;
        loading = false;
        loaded();
    }

    function parse(text) {
        if (text.startsWith("#ERR")) { ok = false; entries = []; return; }
        ok = true;
        const out = [];
        const recs = text.split("\u0000");
        for (const r of recs) {
            if (!r) continue;
            const f = r.split("\u001f");
            if (f.length < 10) continue;
            const p = f[0];
            const name = p.slice(p.lastIndexOf("/") + 1);
            const isLink = f[1] === "l";
            const t = isLink ? f[2] : f[1];
            const mode = parseInt(f[5], 8);
            out.push({
                rank: out.length,
                name: name,
                path: p,
                isDir: t === "d",
                isLink: isLink,
                broken: isLink && (f[2] === "N" || f[2] === "L"),
                target: f[6],
                size: t === "d" ? -1 : Number(f[3]),
                mtime: Number(f[4]),
                atime: Number(f[8]),
                btime: Number(f[9]) || Number(f[4]),
                exec: t === "f" && (mode & 0o111) !== 0,
                mode: mode,
                blocks: Number(f[7]),
                hidden: name.startsWith(".")
            });
        }
        entries = out;
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                root.parse(text);
                root.loading = false;
                root.loaded();
            }
        }
    }

    onPathChanged: { entries = []; reload(); }
    onShowHiddenChanged: {}
    Component.onCompleted: reload()

    // Rafraîchissement demandé par une opération (Fs.changed)
    Connections {
        target: Fs
        function onChanged(dirs) {
            const p = root.path === "trash://" ? Fs.trashDir + "/files" : root.path;
            if (root.path === "recents://" || root.path.startsWith("tag://") || dirs.includes(p)) root.reload();
        }
        function onTagsChanged() { if (root.path.startsWith("tag://")) root.reload(); }
        function onVolumesChanged() { if (root.path === "computer://") root.reload(); }
    }

    // ---- Surveillance du dossier ----
    readonly property string _watchDir: path === "trash://" ? Fs.trashDir + "/files"
                                       : (path.indexOf("://") > 0 ? "" : path)
    Process {
        id: watcher
        running: root.watch && root._watchDir !== "" && root.ok
        command: ["sh", "-c", 'd="$1"; if command -v inotifywait >/dev/null 2>&1; then exec inotifywait -m -q -e create,delete,moved_to,moved_from,close_write,attrib --format x "$d"; else o=""; while :; do m=$(stat -c %Y "$d" 2>/dev/null); [ "$m" != "$o" ] && [ -n "$o" ] && echo x; o=$m; sleep 1.5; done; fi', "sh", root._watchDir]
        stdout: SplitParser {
            onRead: debounce.restart()
        }
    }
    // Regroupe les rafales d'événements (copie de nombreux fichiers…)
    Timer {
        id: debounce
        interval: 150
        onTriggered: root.reload()
    }
}
