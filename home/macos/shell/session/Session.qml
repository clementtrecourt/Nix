import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

// Session : fond d'écran (+ menu du bureau, sélecteur), écran de verrouillage,
// alertes Éteindre / Redémarrer / Fermer la session, Forcer à quitter,
// À propos de ce Mac, agent Polkit.
//
// Panneaux ShellState gérés ici : lock, shutdown, restart, logout, forcequit,
// about, wallpaper. Raccourcis globaux : macos:lock, macos:forcequit.
Scope {
    id: root

    Wallpaper {
        onContextMenuRequested: (scr, x, y) => desktopMenu.popup(scr, x, y)
    }
    DesktopMenu {
        id: desktopMenu
        onChangeWallpaper: ShellState.open("wallpaper")
    }
    WallpaperPicker {}

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
