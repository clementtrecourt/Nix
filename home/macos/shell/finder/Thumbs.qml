pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Vignettes des documents que Qt ne sait pas décoder (PDF, vidéos), générées
// en arrière-plan (pdftoppm, ffmpegthumbnailer / ffmpeg) dans
// ~/.cache/macos-shell/finder/<md5(chemin:mtime:taille)>.png, une à la fois.
// Les images sont décodées directement par Image (sourceSize) : rien ici.
Singleton {
    id: root

    // clé -> URL du PNG prêt ("" = échec : garder l'icône)
    property var ready: ({})
    property var _queue: []
    property var _pending: ({})

    function key(e, px) { return Qt.md5(e.path + ":" + e.mtime + ":" + (e.size ?? 0) + ":" + px); }

    function supported(e) {
        if (!e || e.isDir) return false;
        const c = Fs.category(e);
        return c === "pdf" || c === "movie";
    }

    // URL de la vignette si elle existe ("" sinon ; la demande est mise en file)
    function get(e, px) {
        if (!supported(e)) return "";
        const k = key(e, px);
        const v = ready[k];
        if (v !== undefined) return v;
        if (!_pending[k]) {
            _pending[k] = true;
            _queue.push({ k: k, path: e.path, cat: Fs.category(e), px: px });
            _next();
        }
        return "";
    }

    function _next() {
        if (proc.running || _queue.length === 0) return;
        const j = _queue.shift();
        proc.job = j;
        const out = Fs.cacheDir + "/" + j.k + ".png";
        proc.command = ["sh", "-c", `
            mkdir -p "$(dirname "$2")"
            [ -s "$2" ] && exit 0
            case "$3" in
              pdf) command -v pdftoppm >/dev/null && pdftoppm -png -singlefile -f 1 -l 1 -scale-to "$4" "$1" "\${2%.png}" ;;
              movie)
                if command -v ffmpegthumbnailer >/dev/null; then ffmpegthumbnailer -i "$1" -o "$2" -s "$4" -c png -q 8 >/dev/null 2>&1
                elif command -v ffmpeg >/dev/null; then ffmpeg -loglevel quiet -y -ss 1 -i "$1" -frames:v 1 -vf "scale=$4:-1" "$2"; fi ;;
            esac
            [ -s "$2" ]`, "sh", j.path, out, j.cat, String(j.px)];
        proc.running = true;
    }

    Process {
        id: proc
        property var job: null
        onExited: (code) => {
            const o = Object.assign({}, root.ready);
            o[job.k] = code === 0 ? "file://" + Fs.cacheDir + "/" + job.k + ".png" : "";
            root.ready = o;
            Qt.callLater(root._next);
        }
    }
}
