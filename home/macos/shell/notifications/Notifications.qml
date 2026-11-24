import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

// Composant "notifications" du shell macOS Tahoe :
//  - serveur de notifications freedesktop (NotifStore, singleton) ;
//  - bannières en haut à droite (Banners) ;
//  - Centre de notifications + widgets (NotificationCenter) ;
//  - vignette flottante et barre d'outils de capture d'écran (Screenshot*).
Scope {
    id: root

    Banners {}
    NotificationCenter {}
    ScreenshotThumb {}
    ScreenshotToolbar {}

    GlobalShortcut {
        appid: "macos"
        name: "notificationcenter"
        description: "Show / hide Notification Center"
        onPressed: ShellState.toggle("notificationcenter")
    }
}
