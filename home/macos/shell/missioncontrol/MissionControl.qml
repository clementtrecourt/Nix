import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common
import qs.services

// Mission Control (Ctrl+Haut, F3, geste 4 doigts) et App Exposé (Ctrl+Bas).
// Un MCScreen par écran ; état porté par ShellState ("missioncontrol" /
// "appexpose") pour qu'un seul panneau soit ouvert à la fois.
Scope {
    id: root

    readonly property string mode: ShellState.openPanel === "missioncontrol" ? "mc"
        : ShellState.openPanel === "appexpose" ? "app" : ""

    GlobalShortcut {
        appid: "macos"
        name: "missioncontrol"
        description: "Mission Control"
        onPressed: ShellState.toggle("missioncontrol")
    }
    GlobalShortcut {
        appid: "macos"
        name: "appexpose"
        description: "Application windows (App Exposé)"
        onPressed: ShellState.toggle("appexpose")
    }

    Variants {
        id: screens
        model: Quickshell.screens

        MCScreen {
            mode: root.mode
        }
    }

    // Écran focalisé (pour le débogage)
    function focusedScreen() {
        const name = Hyprland.focusedMonitor?.name ?? "";
        return screens.instances.find(w => w.modelData.name === name) ?? screens.instances[0];
    }

    // Débogage (banc de test, pas de clic possible) :
    //   quickshell ipc call missioncontrol-debug hover 0
    IpcHandler {
        target: "missioncontrol-debug"
        function open(kind: string): void { ShellState.open(kind === "app" ? "appexpose" : "missioncontrol"); }
        function close(): void { ShellState.close(); }
        function slow(factor: real): void { for (const w of screens.instances) w.speed = factor; }
        function hover(index: int): void { for (const w of screens.instances) w.forceHover = index; }
        function expand(on: bool): void { for (const w of screens.instances) w.forceExpanded = on; }
        function hoverSpace(id: int): void { for (const w of screens.instances) w.forceHoverSpace = id; }
        // Fige l'animation à un instant donné (0 = fenêtres à leur place réelle)
        function freeze(p: real): void { const w = root.focusedScreen(); w.freezeAt(p); }
        function pick(index: int): void { const w = root.focusedScreen(); if (w.wins[index]) w.pick(w.wins[index]); }
        function space(id: int): void { root.focusedScreen().pickSpace(id); }
        function drop(index: int, id: int): void {
            const w = root.focusedScreen();
            if (!w.wins[index]) return;
            if (id < 0) id = Spaces.add();
            Spaces.moveWindow(w.wins[index], id);
        }
        function addSpace(): void { Spaces.add(); }
        function dark(on: bool): void { Theme.dark = on; }
        function removeSpace(id: int): void { Spaces.remove(id); }
        function state(): string {
            const w = root.focusedScreen();
            return JSON.stringify({ mode: w.shownMode, started: w.started, app: w.appClass, last: w.lastActiveClass, progress: w.progress, wins: w.wins.length, rects: w.rects, spaces: Spaces.ids });
        }
    }
}
