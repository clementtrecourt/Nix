pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Captures d'écran façon macOS (grim + slurp, wf-recorder pour l'enregistrement).
//  - capture(mode) : "screen" (écran entier), "window" (fenêtre choisie), "area" (portion)
//  - record(mode)  : "screen" / "area" ; stopRecording()
//  - Fichiers : « Capture d'écran 2026-11-23 à 17.20.11.png » dans ~/Pictures/Screenshots
//    (ou le dossier choisi dans Options), comme macOS en français.
//  - Après chaque capture : vignette flottante (signal `captured`).
//
// IPC (utilisée par les raccourcis Hyprland Cmd+Maj+3/4) :
//   quickshell -c macos ipc call screenshot show <chemin.png>
//   quickshell -c macos ipc call screenshot capture screen|window|area
//   quickshell -c macos ipc call screenshot ui
Singleton {
    id: root

    // ---- Réglages (menu Options, persistés) ----
    property string saveTo: "screenshots"     // desktop | documents | screenshots | clipboard
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
        default: return home + "/Pictures/Screenshots";
        }
    }

    // « Capture d'écran 2026-11-23 à 17.20.11 »
    function baseName(prefix) {
        const d = new Date();
        return prefix + " " + Qt.formatDate(d, "yyyy-MM-dd") + " à " + Qt.formatTime(d, "HH.mm.ss");
    }

    // Script commun : sélection de la zone puis grim. Sort 2 si l'utilisateur annule.
    readonly property string captureScript: `
set -u
mode="$1"; out="$2"; delay="$3"; cursor="$4"; clip="$5"
c=""; [ "$cursor" = 1 ] && c="-c"
geom=""
case "$mode" in
  window)
    ws=$(hyprctl -j monitors | jq -r ".[] | select(.focused) | .activeWorkspace.id")
    geom=$(hyprctl -j clients | jq -r --argjson ws "$ws" '.[] | select(.workspace.id == $ws and .mapped and (.hidden | not)) | "\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"' \\
      | slurp -r -b "#00000000" -c "#0A84FFFF" -s "#0A84FF40" -w 0) || exit 2 ;;
  area)
    geom=$(slurp -d -b "#0000004D" -c "#FFFFFFE6" -s "#00000000" -w 1 -F "Inter") || exit 2 ;;
esac
[ "$delay" -gt 0 ] && sleep "$delay"
mkdir -p "$(dirname "$out")"
if [ "$mode" = screen ]; then
  mon=$(hyprctl -j monitors | jq -r ".[] | select(.focused) | .name")
  grim $c -o "$mon" "$out" || exit 1
else
  grim $c -g "$geom" "$out" || exit 1
fi
# Bruit d obturateur (si disponible)
if command -v pw-play >/dev/null && [ -f /run/current-system/sw/share/sounds/freedesktop/stereo/camera-shutter.oga ]; then
  pw-play /run/current-system/sw/share/sounds/freedesktop/stereo/camera-shutter.oga >/dev/null 2>&1 &
fi
if [ "$clip" = 1 ]; then wl-copy --type image/png < "$out"; rm -f "$out"; exit 0; fi
echo "$out"
`

    function capture(mode) {
        if (busy || recording) return;
        lastMode = mode;
        busy = true;
        toolbarOpen = false;
        const clip = saveTo === "clipboard";
        const out = clip ? ("/tmp/qs-capture-" + Date.now() + ".png")
                         : (saveDir() + "/" + baseName("Capture d'écran") + ".png");
        shotProc.command = ["sh", "-c", captureScript, "capture", mode, out,
                            String(delay), showPointer ? "1" : "0", clip ? "1" : "0"];
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
                if (p && root.showThumbnail) root.captured(p);
            }
        }
        onExited: root.busy = false
    }

    // ---- Enregistrement de l'écran ----
    readonly property string recordScript: `
set -u
mode="$1"; out="$2"; delay="$3"
geom=""
if [ "$mode" = area ]; then
  geom=$(slurp -d -b "#0000004D" -c "#FFFFFFE6" -s "#00000000" -w 1) || exit 2
fi
[ "$delay" -gt 0 ] && sleep "$delay"
mkdir -p "$(dirname "$out")"
echo START
if [ -n "$geom" ]; then exec wf-recorder -y -g "$geom" -f "$out"
else
  mon=$(hyprctl -j monitors | jq -r ".[] | select(.focused) | .name")
  exec wf-recorder -y -o "$mon" -f "$out"
fi
`
    function record(mode) {
        if (busy || recording) return;
        lastMode = "rec-" + mode;
        toolbarOpen = false;
        recordPath = saveDir() + "/" + baseName("Enregistrement de l'écran") + ".mp4";
        recProc.command = ["sh", "-c", recordScript, "record", mode, recordPath, String(delay)];
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

    // ---- Persistance des options ----
    FileView {
        id: settingsFile
        path: Quickshell.statePath("screenshot.json")
        printErrors: false
        blockLoading: true
        atomicWrites: true
    }
    function save() {
        settingsFile.setText(JSON.stringify({ saveTo, delay, showThumbnail, showPointer, lastMode }));
    }
    onSaveToChanged: Qt.callLater(save)
    onDelayChanged: Qt.callLater(save)
    onShowThumbnailChanged: Qt.callLater(save)
    onShowPointerChanged: Qt.callLater(save)
    Component.onCompleted: {
        try {
            const j = JSON.parse(settingsFile.text() || "{}");
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
        function show(path: string): void { root.captured(path); }
        function capture(mode: string): void { root.capture(mode); }
        function ui(): void { root.toolbarOpen = !root.toolbarOpen; }
        function stop(): void { root.stopRecording(); }
    }
}
