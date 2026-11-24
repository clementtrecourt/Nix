pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.controlcenter as CC

// Réglages propres à l'app Réglages Système, persistés dans l'état du shell
// (Quickshell.statePath("system-settings.json")), et leurs effets sur le
// système :
//  - Apparence : Light / Dark (controlcenter/Appearance : Theme.dark + gsettings)
//    et Auto (clair de 7 h à 19 h, réévalué chaque minute) ; couleur d'accent
//    (gsettings accent-color, GNOME 47+) ;
//  - Clavier / souris / trackpad / écrans : `hyprctl keyword` à chaud, et
//    persistance dans ~/.config/hypr/macos-settings.conf (à sourcer en fin de
//    configuration Hyprland). Seules les clés modifiées ici y sont écrites :
//    le reste suit hyprland.nix.
//
// MACOS_SHELL_DEV=1 (banc de test) : ni gsettings, ni fichier Hyprland de
// l'utilisateur (le fichier va dans l'état du shell de dev) ; hyprctl vise
// l'instance imbriquée.
Singleton {
    id: root

    readonly property bool devMode: (Quickshell.env("MACOS_SHELL_DEV") ?? "") !== ""
    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string hyprConf: devMode ? Quickshell.statePath("macos-settings-dev.conf")
                                               : ((Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")) + "/hypr/macos-settings.conf")

    // ---- Valeurs (défauts d'une installation neuve de Tahoe) ----
    property var v: ({
        appearance: "",            // "" = suit Theme.dark (light | dark | auto)
        accent: "multicolor",
        highlight: "automatic",
        iconStyle: "default",
        folderColor: "automatic",
        sidebarIconSize: "medium",
        tintWindow: true,
        scrollBars: "auto",
        clickScrollBar: "page",
        alertSound: "Tink",
        alertVolume: 0.75,
        startupSound: true,
        uiSounds: true,
        volumeFeedback: false,
        notifPreviews: "unlocked",
        notifSleeping: false,
        notifLocked: true,
        notifMirroring: false,
        // Valeurs de hypridle (hyprland.nix) tant que l'utilisateur n'a rien changé
        screenSaverAfter: 600,
        displayOffAfter: 900,
        lockManaged: true,          // délais gérés par le shell (hypridle n'a plus de minuteries)
        requirePassword: 0,
        lockMessage: false,
        passwordHints: false,
        loginWindowShows: "list",
        powerButtons: true,
        menuBarAutohide: "fullscreen",   // Tahoe : In Full Screen Only
        menuBarBackground: false,
        recentItems: 10,
        menuControls: ({ wifi: "show", bluetooth: "active", focus: "active", sound: "active", display: "active", nowPlaying: "active", battery: "show", spotlight: "show", siri: "hide", userSwitch: "hide", screenMirroring: "active" }),
        shareAcrossDevices: true,
        focusStatus: true,
        askToJoin: "notify",
        askToJoinHotspots: "ask",
        clock24: false,
        hypr: ({}),                // clés Hyprland choisies ici : { "input:repeat_rate": 25, … }
        monitors: ({})             // { "DP-1": { w, h, r, scale } }
    })
    property bool loaded: false

    function get(k) { return v[k]; }
    function set(k, val) {
        const o = Object.assign({}, v);
        o[k] = val;
        v = o;
        save();
    }
    function setIn(k, sub, val) {
        const inner = Object.assign({}, v[k] ?? {});
        inner[sub] = val;
        set(k, inner);
    }
    function save() { if (loaded) store.setText(JSON.stringify(v, null, 2)); }

    FileView {
        id: store
        path: Quickshell.statePath("system-settings.json")
        printErrors: false
        onLoaded: {
            try {
                const o = JSON.parse(text());
                root.v = Object.assign({}, root.v, o);
            } catch (e) {}
            root.loaded = true;
            root.applyAppearance();
        }
        onLoadFailed: root.loaded = true
    }

    // ---------------------------------------------------------------- apparence
    readonly property string appearance: v.appearance || (Theme.dark ? "dark" : "light")
    function setAppearance(mode) {
        set("appearance", mode);
        applyAppearance();
    }
    function applyAppearance() {
        const m = v.appearance;
        if (!m) return;
        const want = m === "dark" || (m === "auto" && autoIsDark());
        if (want !== Theme.dark) CC.Appearance.setDark(want);
    }
    function autoIsDark() {
        const h = new Date().getHours();
        return h < 7 || h >= 19;
    }
    Timer {
        interval: 60000
        repeat: true
        running: root.v.appearance === "auto"
        onTriggered: root.applyAppearance()
    }

    // Couleurs d'accent de Tahoe (controlAccentColor), clair / sombre
    readonly property var accents: [
        { id: "multicolor", name: "Multicolor", light: "#007AFF", dark: "#0A84FF", gnome: "blue" },
        { id: "blue", name: "Blue", light: "#007AFF", dark: "#0A84FF", gnome: "blue" },
        { id: "purple", name: "Purple", light: "#953D96", dark: "#A550A7", gnome: "purple" },
        { id: "pink", name: "Pink", light: "#F74F9E", dark: "#F74F9E", gnome: "pink" },
        { id: "red", name: "Red", light: "#E0383E", dark: "#FF5257", gnome: "red" },
        { id: "orange", name: "Orange", light: "#F7821B", dark: "#F7821B", gnome: "orange" },
        { id: "yellow", name: "Yellow", light: "#FFC600", dark: "#FFC600", gnome: "yellow" },
        { id: "green", name: "Green", light: "#62BA46", dark: "#62BA46", gnome: "green" },
        { id: "graphite", name: "Graphite", light: "#989898", dark: "#8C8C8C", gnome: "slate" }
    ]
    function accentInfo(id) { return accents.find(a => a.id === id) ?? accents[0]; }
    readonly property color accentColor: { const a = accentInfo(v.accent); return Theme.dark ? a.dark : a.light; }
    function setAccent(id) {
        set("accent", id);
        if (devMode) return;
        Quickshell.execDetached(["sh", "-c", 'gsettings set org.gnome.desktop.interface accent-color "$1" 2>/dev/null || dconf write /org/gnome/desktop/interface/accent-color "\'$1\'" 2>/dev/null; true', "sh", accentInfo(id).gnome]);
    }

    // ---------------------------------------------------------------- Hyprland
    // Valeurs courantes lues dans Hyprland (getoption) : { "input:repeat_rate": 25, … }
    property var hyprNow: ({})
    readonly property var hyprKeys: ["input:repeat_rate", "input:repeat_delay", "input:sensitivity", "input:natural_scroll",
                                     "input:scroll_factor", "input:kb_layout", "input:kb_variant", "input:accel_profile", "input:touchpad:natural_scroll",
                                     "input:touchpad:tap-to-click", "input:touchpad:scroll_factor", "input:touchpad:clickfinger_behavior"]
    function hypr(k, fallback) {
        const set_ = v.hypr ?? {};
        if (set_[k] !== undefined) return set_[k];
        if (hyprNow[k] !== undefined) return hyprNow[k];
        return fallback;
    }
    function setHypr(k, val) {
        const val_ = typeof val === "boolean" ? (val ? 1 : 0) : val;
        setIn("hypr", k, val_);
        Quickshell.execDetached(["hyprctl", "keyword", k, String(val_)]);
        writeHyprConf();
    }
    function setMonitor(name, m) {
        setIn("monitors", name, m);
        Quickshell.execDetached(["hyprctl", "keyword", "monitor", monitorLine(name, m)]);
        writeHyprConf();
    }
    // « NOM,LxH@F,XxY,échelle[,transform,T][,mirror,AUTRE] »
    function monitorLine(name, m) {
        let l = name + "," + m.w + "x" + m.h + "@" + (Math.round(Number(m.r) * 100) / 100) + ","
                + (m.x !== undefined ? m.x + "x" + m.y : "auto") + "," + m.scale;
        if (m.transform) l += ",transform," + m.transform;
        if (m.mirror) l += ",mirror," + m.mirror;
        return l;
    }
    function writeHyprConf() {
        const h = v.hypr ?? {};
        const lines = ["# Généré par Réglages Système (shell macOS) : ne pas éditer à la main.",
                       "# Sourcé en fin de configuration Hyprland ; les réglages absents suivent hyprland.nix.", ""];
        for (const name of Object.keys(v.monitors ?? {}))
            lines.push("monitor = " + monitorLine(name, v.monitors[name]));
        const top = Object.keys(h).filter(k => k.split(":").length === 2);
        const pad = Object.keys(h).filter(k => k.startsWith("input:touchpad:"));
        if (top.length || pad.length) {
            lines.push("input {");
            for (const k of top) lines.push("    " + k.split(":")[1] + " = " + h[k]);
            if (pad.length) {
                lines.push("    touchpad {");
                for (const k of pad) lines.push("        " + k.split(":")[2] + " = " + h[k]);
                lines.push("    }");
            }
            lines.push("}");
        }
        confWriter.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', "sh", hyprConf, lines.join("\n")];
        confWriter.running = true;
    }
    Process { id: confWriter }

    function refreshHypr() {
        hyprProbe.command = ["sh", "-c", 'for k in "$@"; do printf "%s\\t%s\\n" "$k" "$(hyprctl getoption "$k" -j 2>/dev/null | tr -d "\\n")"; done', "sh"].concat(hyprKeys);
        hyprProbe.running = true;
    }
    Process {
        id: hyprProbe
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) {
                    const i = l.indexOf("\t");
                    if (i < 0) continue;
                    try {
                        const j = JSON.parse(l.slice(i + 1));
                        const val = j.int ?? j.float ?? j.str ?? j.custom;
                        o[l.slice(0, i)] = val === "[[EMPTY]]" ? "" : val;
                    } catch (e) {}
                }
                root.hyprNow = o;
            }
        }
    }
    Component.onCompleted: refreshHypr()

    // ---------------------------------------------------------------- sons d'alerte
    // Noms de Tahoe -> sons du thème freedesktop (sound-theme-freedesktop)
    readonly property var alertSounds: ["Boop", "Breeze", "Bubble", "Crystal", "Funky", "Heroine", "Jump", "Mezzo",
                                         "Pebble", "Pluck", "Pong", "Sonar", "Sonumi", "Submerge", "Basso", "Blow",
                                         "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr",
                                         "Sosumi", "Tink"]
    readonly property var _soundFiles: ["bell", "message", "message-new-instant", "complete", "dialog-information",
                                        "dialog-warning", "audio-volume-change", "window-attention", "window-question",
                                        "device-added", "device-removed", "power-plug", "power-unplug", "suspend-error",
                                        "dialog-error", "phone-incoming-call", "alarm-clock-elapsed", "bell", "camera-shutter",
                                        "message", "complete", "network-connectivity-established", "service-login",
                                        "screen-capture", "trash-empty", "service-logout", "audio-volume-change"]
    function playAlert(name) {
        const i = Math.max(0, alertSounds.indexOf(name ?? v.alertSound));
        const f = _soundFiles[i % _soundFiles.length];
        const vol = Math.max(0, Math.min(1, v.alertVolume ?? 0.75));
        Quickshell.execDetached(["sh", "-c",
            'for d in ${XDG_DATA_DIRS:-/run/current-system/sw/share}; do for e in oga ogg wav; do f="${d%/}/sounds/freedesktop/stereo/$1.$e"; ' +
            '[ -f "$f" ] && exec pw-play ${3:+--target "$3"} --volume "$2" "$f"; done; done; true',
            "sh", f, String(vol), v.effectsDevice ?? ""]);
    }
}
