//@ pragma UseQApplication
//@ pragma IconTheme MacTahoe-dark
// Shell façon macOS Tahoe pour Hyprland.
// Lancement : quickshell -c macos   (ou -p <ce dossier> en dev)
import QtQuick
import Quickshell
import qs.common
import qs.services
import qs.session
import qs.menubar
import qs.dock
import qs.controlcenter
import qs.spotlight
import qs.notifications
import qs.missioncontrol
import qs.finder
import qs.settings

ShellRoot {
    // Fond d'écran, verrouillage, dialogues de session, À propos, Polkit
    Session {}

    MenuBar {}
    // Mission Control avant le Dock : sa surface (toujours mappée) est ainsi
    // empilée au-dessus de la barre des menus et sous le Dock, comme sur macOS
    MissionControl {}
    Dock {}

    ControlCenter {}
    Osd {}

    Spotlight {}
    Notifications {}

    AppSwitcher {}

    // Gestionnaire de fichiers façon Finder
    Finder {}

    // Réglages Système (System Settings)
    Settings {}
}
