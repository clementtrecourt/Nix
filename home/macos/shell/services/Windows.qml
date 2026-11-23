pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Fenêtres Hyprland, regroupées par application (classe), à la macOS.
// Minimiser = envoyer sur le special workspace "minimized" (restauré au clic Dock).
Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels.values
    readonly property var activeToplevel: Hyprland.activeToplevel
    // Classe de l'app au premier plan ("" = bureau / Finder)
    readonly property string activeClass: activeToplevel?.lastIpcObject?.class ?? ""

    function classOf(t) { return t?.lastIpcObject?.class ?? ""; }
    function addressOf(t) { return "0x" + t.address; }
    function isMinimized(t) { return t?.workspace?.name === "special:minimized"; }

    // Fenêtres d'une app (par classe)
    function windowsOf(cls) {
        return toplevels.filter(t => classOf(t).toLowerCase() === (cls ?? "").toLowerCase());
    }
    function isRunning(cls) { return windowsOf(cls).length > 0; }

    // Liste des classes ouvertes, dans l'ordre d'apparition
    readonly property var runningClasses: {
        const seen = [];
        for (const t of toplevels) {
            const c = classOf(t);
            if (c && !seen.includes(c)) seen.push(c);
        }
        return seen;
    }

    function dispatch(cmd) { Hyprland.dispatch(cmd); }

    function focus(t) {
        if (isMinimized(t)) restore(t);
        else dispatch("focuswindow address:" + addressOf(t));
    }
    function close(t) { dispatch("closewindow address:" + addressOf(t)); }
    function minimize(t) { dispatch("movetoworkspacesilent special:minimized,address:" + addressOf(t)); }
    function restore(t) {
        dispatch("movetoworkspace " + (Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1) + ",address:" + addressOf(t));
        dispatch("focuswindow address:" + addressOf(t));
    }

    // Clic sur une icône du Dock : lance, focalise, ou fait défiler les fenêtres.
    function activateApp(cls, launcher) {
        const ws = windowsOf(cls);
        if (ws.length === 0) { launcher(); return; }
        const cur = ws.findIndex(t => t === activeToplevel);
        focus(ws[(cur + 1) % ws.length]);
    }
    function quitApp(cls) { for (const t of windowsOf(cls)) close(t); }
}
