import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.common

// Réglages Système (System Settings) de macOS Tahoe 26, dessiné par le shell.
//
// IPC : quickshell -c macos ipc call settings open <panneau>   (wifi, bluetooth,
//         network, general, about, appearance, displays, sound… ; noms de
//         gnome-control-center acceptés ; "" = dernier panneau)
//       quickshell -c macos ipc call settings toggle
// Raccourci global : appid "macos", name "settings".
// Lanceur : macos-settings [panneau] (aussi installé sous le nom gnome-control-center).
Scope {
    id: root

    // Réglages appliqués dès le démarrage du shell (apparence Auto, Night Shift
    // programmé) : instancie les singletons sans attendre la fenêtre
    Component.onCompleted: { Prefs.applyAppearance(); NightSchedule.evaluate(); }

    // Lock Screen : délais choisis dans Réglages (par défaut 10 min / 15 min ;
    // hypridle n'a plus de minuteries, il relaie lock-session). Économiseur d'écran = verrouillage du
    // shell (après le délai « Require password »), puis extinction de l'écran.
    IdleMonitor {
        enabled: Prefs.v.lockManaged && Prefs.v.screenSaverAfter > 0 && !Prefs.devMode
        timeout: Prefs.v.screenSaverAfter + Math.max(0, Prefs.v.requirePassword ?? 0)
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) Quickshell.execDetached(["loginctl", "lock-session"])
    }
    IdleMonitor {
        enabled: Prefs.v.lockManaged && Prefs.v.displayOffAfter > 0 && !Prefs.devMode
        timeout: Prefs.v.displayOffAfter
        respectInhibitors: true
        onIsIdleChanged: Quickshell.execDetached(["hyprctl", "dispatch", "dpms", isIdle ? "off" : "on"])
    }

    LazyLoader {
        active: Nav.shown
        SettingsWindow {}
    }

    IpcHandler {
        target: "settings"
        function open(pane: string): void { Nav.open(pane); }
        function toggle(): void { Nav.toggle(); }
        function close(): void { Nav.close(); }
        function current(): string { return Nav.shown ? Nav.pane : ""; }
    }

    // Débogage (banc de test : pas de clic souris dans l'instance imbriquée)
    IpcHandler {
        target: "settings-debug"
        function dark(on: bool): void { Theme.dark = on; }
        function search(q: string): void { Nav.search = q; }
        function scroll(y: int): void { const w = root.win(); if (w) w.flick.contentY = y; }
        function call(fn: string, arg: string): string {
            const w = root.win();
            const p = w ? w.paneItem : null;
            if (!p || typeof p[fn] !== "function") return "no " + fn;
            return String(p[fn](arg));
        }
        function back(): void { Nav.back(); }
        // Ouvre le n-ième pop-up button du panneau (sans saisie du pointeur)
        function popup(n: int): string {
            const w = root.win();
            if (!w || !w.paneItem) return "no pane";
            const found = [];
            const walk = (it) => { for (const c of it.children) { if (c.popup && c.options !== undefined && c.visible) found.push(c); walk(c); } };
            walk(w.paneItem);
            if (n >= found.length) return "only " + found.length;
            found[n].popup(true);
            return found[n].currentText;
        }
        function hypr(k: string, v: string): string { Prefs.setHypr(k, isNaN(Number(v)) ? v : Number(v)); return Prefs.hyprConf; }
        function closeMenu(): void { root.win()?.closeMenu(); }
    }
    function win() { return Nav.window; }

    GlobalShortcut {
        appid: "macos"
        name: "settings"
        description: "System Settings"
        onPressed: Nav.open("")
    }
}
