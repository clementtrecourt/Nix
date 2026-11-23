pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Captures d'écran façon macOS (grim + slurp, wf-recorder pour l'enregistrement).
//  - capture(mode) : "screen" (écran entier), "window" (fenêtre choisie), "area" (portion)
//  - record(mode)  : "screen" / "area" ; stopRecording()
//  - Fichiers : « Capture d’écran 2026-11-23 à 17.20.11.png » dans ~/Pictures/Screenshots
//    (apostrophe typographique, comme macOS et le script macos-screenshot des raccourcis)
//    (ou le dossier choisi dans Options), comme macOS en français.
//  - Après chaque capture : vignette flottante (signal `captured`).
//
// IPC (utilisée par les raccourcis Hyprland Cmd+Maj+3/4) :
//   quickshell -c macos ipc call -- screenshot show <chemin.png>   (ou : … screenshot thumb <chemin.png>)
//   quickshell -c macos ipc call screenshot capture screen|window|area
//   quickshell -c macos ipc call screenshot ui
Singleton {
    id: root

    // ---- Réglages (menu Options, persistés) ----
    // desktop | documents | clipboard | preview | screenshots | custom
    // (« screenshots » = ~/Pictures/Screenshots, dossier des raccourcis Cmd+Maj+3/4 :
    //  gardé par défaut pour que toutes les captures arrivent au même endroit ;
    //  macOS l'afficherait comme un emplacement choisi via « Autre emplacement… »)
    property string saveTo: "screenshots"
    property string customDir: 
    property int delay: 0                     // minuteur : 0, 5, 10 s
    property bool showThumbnail: true
    property bool showPointer: false
    property string lastMode: "area"          // dernier mode choisi dans la barre d'outils

    // ---- État ----
    property bool toolbarOpen: false
    property bool busy: false                 // capture en cours (barre masquée)
    property bool recording: false
    property real recordStart: 0
    property string recordPath: ""

    signal captured(string path)

    readonly property string home: Quickshell.env("HOME")
    function saveDir() {
        switch (saveTo) {
        case "desktop": return home + "/Desktop";
        case "documents": return home + "/Documents";
        case "custom": if (customDir) return customDir;
        default: return home + "/Pictures/Screenshots";
        }
    }

    // « Capture d’écran 2026-11-23 à 17.20.11 »
    function baseName(prefix) {
        const d = new Date();
        return prefix + " " + Qt.formatDate(d, "yyyy-MM-dd") + " à " + Qt.formatTime(d, "HH.mm.ss");
    }

    // Script commun : sélection de la zone puis grim. Sort 2 si l'utilisateur annule.
    // Écran et rectangles des fenêtres sont calculés côté QML (pas de jq requis).
    readonly property string captureScript: `
set -u
mode="$1"; out="$2"; delay="$3"; cursor="$4"; clip="$5"; mon="$6"; boxes="$7"
c=""; [ "$cursor" = 1 ] && c="-c"
geom=""
case "$mode" in
  window)
    geom=$(printf '%s\n' "$boxes" | slurp -r -b "#00000000" -c "#0A84FFFF" -s "#0A84FF40" -w 0) || exit 2 ;;
  area)
    geom=$(slurp -d -b "#00000000" -c "#FFFFFFE6" -s "#FFFFFF1F" -B "#00000000" -w 1 -F "Inter") || exit 2 ;;
esac
[ "$delay" -gt 0 ] && sleep "$delay"
mkdir -p "$(dirname "$out")"
if [ "$mode" = screen ]; then
  grim $c \${mon:+-o "$mon"} "$out" || exit 1
else
  grim $c -g "$geom" "$out" || exit 1
fi
# Bruit d’obturateur (si disponible)
# (thème sonore freedesktop cherché dans XDG_DATA_HOME puis XDG_DATA_DIRS)
if command -v pw-play >/dev/null; then
  IFS=:
  for d in "\${XDG_DATA_HOME:-$HOME/.local/share}" \${XDG_DATA_DIRS:-/run/current-system/sw/share}; do
    snd="$d/sounds/freedesktop/stereo/camera-shutter.oga"
    if [ -f "$snd" ]; then pw-play "$snd" >/dev/null 2>&1 & break; fi
  done
  unset IFS
fi
if [ "$clip" = 1 ]; then wl-copy --type image/png < "$out"; rm -f "$out"; exit 0; fi
echo "$out"
`

    // Écran focalisé (nom de sortie Hyprland)
    function focusedMonitor() { return Hyprland.focusedMonitor?.name ?? ""; }

    // Rectangles « x,y lxh » des fenêtres visibles de l'espace de travail actif,
    // proposés à slurp pour le mode « fenêtre » (survol = fenêtre surlignée).
    function windowBoxes() {
        const ws = Hyprland.focusedMonitor?.activeWorkspace?.id;
        const out = [];
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.at || !o.size || o.hidden === true || o.mapped === false) continue;
            if (o.workspace?.id !== ws) continue;
            out.push(o.at[0] + "," + o.at[1] + " " + o.size[0] + "x" + o.size[1]);
        }
        return out.join("\n");
    }

    function capture(mode) {
        if (busy || recording || !["screen", "window", "area"].includes(mode)) return;
        lastMode = mode;
        busy = true;
        toolbarOpen = false;
        const clip = saveTo === "clipboard";
        // Aperçu : l'image s'ouvre dans la visionneuse sans être rangée (comme macOS)
        const out = clip ? ("/tmp/qs-capture-" + Date.now() + ".png")
                  : saveTo === "preview" ? ("/tmp/" + baseName("Capture d’écran") + ".png")
                         : (saveDir() + "/" + baseName("Capture d’écran") + ".png");
        Hyprland.refreshToplevels();
        shotProc.command = ["sh", "-c", captureScript, "capture", mode, out,
                            String(delay), showPointer ? "1" : "0", clip ? "1" : "0",
                            focusedMonitor(), windowBoxes()];
        // Laisse le temps à la barre d'outils de disparaître de l'écran
        startTimer.restart();
    }
    Timer {
        id: startTimer
        interval: 220
        onTriggered: shotProc.running = true
    }
    Process {
        id: shotProc
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p && root.saveTo === "preview") root.open(p);
                else if (p && root.showThumbnail) root.captured(p);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("capture d'écran :", text.trim())
        }
        onExited: root.busy = false
    }

    // ---- Enregistrement de l'écran ----
    readonly property string recordScript: `
set -u
mode="$1"; out="$2"; delay="$3"; mon="$4"
command -v wf-recorder >/dev/null || { echo "wf-recorder introuvable" >&2; exit 3; }
geom=""
if [ "$mode" = area ]; then
  geom=$(slurp -d -b "#00000000" -c "#FFFFFFE6" -s "#FFFFFF1F" -B "#00000000" -w 1 -F "Inter") || exit 2
fi
[ "$delay" -gt 0 ] && sleep "$delay"
mkdir -p "$(dirname "$out")"
echo START
if [ -n "$geom" ]; then exec wf-recorder -y -g "$geom" -f "$out"
else exec wf-recorder -y \${mon:+-o "$mon"} -f "$out"
fi
`
    function record(mode) {
        if (busy || recording || !["screen", "area"].includes(mode)) return;
        lastMode = "rec-" + mode;
        toolbarOpen = false;
        recordPath = saveDir() + "/" + baseName("Enregistrement de l’écran") + ".mp4";
        recProc.command = ["sh", "-c", recordScript, "record", mode, recordPath, String(delay), focusedMonitor()];
        recStartTimer.restart();
    }
    Timer {
        id: recStartTimer
        interval: 220
        onTriggered: recProc.running = true
    }
    function stopRecording() {
        if (recProc.running) recProc.signal(2);   // SIGINT : wf-recorder finalise le fichier
    }
    Process {
        id: recProc
        stdout: SplitParser {
            onRead: line => {
                if (line === "START") { root.recording = true; root.recordStart = Date.now(); }
            }
        }
        stderr: SplitParser {
            onRead: line => { if (/error|fail|introuvable/i.test(line)) console.warn("enregistrement :", line); }
        }
        onExited: code => {
            const was = root.recording;
            root.recording = false;
            if (was && root.showThumbnail) thumbDelay.restart();
        }
    }
    // Le fichier mp4 est finalisé juste après la sortie de wf-recorder
    Timer {
        id: thumbDelay
        interval: 300
        onTriggered: root.captured(root.recordPath)
    }

    function open(path) { Quickshell.execDetached(["xdg-open", path]); }

    // « Autre emplacement… » : sélecteur de dossier (zenity)
    function chooseFolder() { if (!folderProc.running) folderProc.running = true; }
    Process {
        id: folderProc
        command: ["sh", "-c", "command -v zenity >/dev/null || { echo 'zenity introuvable' >&2; exit 3; }; "
                  + "zenity --file-selection --directory --title='Enregistrer les captures dans'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = text.trim();
                if (d) { root.customDir = d; root.saveTo = "custom"; }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (/introuvable/.test(text)) console.warn("capture d'écran :", text.trim())
        }
    }

    // ---- Persistance des options ----
    FileView {
        id: settingsFile
        path: Quickshell.statePath("screenshot.json")
        printErrors: false
        blockLoading: true
        atomicWrites: true
    }
    function save() {
        settingsFile.setText(JSON.stringify({ saveTo, customDir, delay, showThumbnail, showPointer, lastMode }));
    }
    onSaveToChanged: Qt.callLater(save)
    onCustomDirChanged: Qt.callLater(save)
    onDelayChanged: Qt.callLater(save)
    onShowThumbnailChanged: Qt.callLater(save)
    onShowPointerChanged: Qt.callLater(save)
    Component.onCompleted: {
        try {
            const j = JSON.parse(settingsFile.text() || "{}");
            if (j.customDir) customDir = j.customDir;
            if (j.saveTo) saveTo = j.saveTo;
            if (j.delay !== undefined) delay = j.delay;
            if (j.showThumbnail !== undefined) showThumbnail = j.showThumbnail;
            if (j.showPointer !== undefined) showPointer = j.showPointer;
            if (j.lastMode) lastMode = j.lastMode;
        } catch (e) {}
    }

    IpcHandler {
        target: "screenshot"
        // Vignette flottante après une capture faite ailleurs (raccourcis Hyprland)
        // NB : "show" est aussi une sous-commande de `quickshell ipc` ; appeler
        //   quickshell -c macos ipc call -- screenshot show <chemin>   (avec "--")
        // ou l'alias sans ambiguïté : ipc call screenshot thumb <chemin>
        function show(path: string): void { root.captured(path); }
        function thumb(path: string): void { root.captured(path); }
        function capture(mode: string): void { root.capture(mode); }
        function ui(): void { root.toolbarOpen = !root.toolbarOpen; }
        function stop(): void { root.stopRecording(); }
    }
}
