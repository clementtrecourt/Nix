import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

// Session : fond d'écran (+ menu du bureau), écran de verrouillage,
// alertes Éteindre / Redémarrer / Fermer la session, Forcer à quitter,
// À propos de ce Mac, agent Polkit.
//
// Panneaux ShellState gérés ici : lock, shutdown, restart, logout, forcequit,
// about ; "wallpaper" ouvre System Settings ▸ Wallpaper. Raccourcis globaux : macos:lock, macos:forcequit.
Scope {
    id: root

    Wallpaper {
        onContextMenuRequested: (scr, x, y) => desktopMenu.popup(scr, x, y)
    }
    DesktopMenu {
        id: desktopMenu
        onChangeWallpaper: root.openWallpaperSettings()
    }

    // « Change Wallpaper… » : comme macOS, ouvre System Settings ▸ Wallpaper
    // (app Réglages du shell, IPC « settings »). L'appel IPC vise CETTE
    // instance par son pid (marche en prod comme au banc de test, quel que soit
    // le nom de la config) ; binaire quickshell du PATH, sinon celui du processus.
    function openWallpaperSettings() {
        const pid = String(Quickshell.processId);
        Quickshell.execDetached(["sh", "-c",
            'q=$(command -v quickshell || echo "/proc/$1/exe"); ' +
            'exec "$q" ipc --pid "$1" call settings open wallpaper', "sh", pid]);
    }
    // Ancien panneau ShellState "wallpaper" : redirigé vers Réglages
    Connections {
        target: ShellState
        function onOpenPanelChanged() {
            if (ShellState.openPanel === "wallpaper") {
                ShellState.close();
                root.openWallpaperSettings();
            }
        }
    }

    LockScreen {}
    SessionAlert {}
    ForceQuit {}
    AboutWindow {}
    PolkitDialog {}

    // Débogage (banc de test uniquement : QS_SESSION_DEBUG=1)
    //   quickshell ipc call session-debug dark true
    IpcHandler {
        target: "session-debug"
        enabled: Quickshell.env("QS_SESSION_DEBUG") === "1"
        function dark(on: bool): void { Theme.dark = on; }
        function menu(x: real, y: real): void { desktopMenu.popup(Quickshell.screens[0], x, y); }
        function menuClose(): void { desktopMenu.dismiss(); }
        function menuKey(k: string): void { desktopMenu.win?.debugKey(k); }
        function menuState(): string {
            return JSON.stringify({ shown: desktopMenu.shown, stacks: desktopMenu.useStacks, sort: desktopMenu.sortBy });
        }
        function wallpaper(path: string): void { WallpaperService.set(path); }
    }
}
