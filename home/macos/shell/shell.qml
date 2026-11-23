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

ShellRoot {
    // Fond d'écran, verrouillage, dialogues de session, À propos, Polkit
    Session {}

    MenuBar {}
    Dock {}

    ControlCenter {}
    Osd {}

    Spotlight {}
    Notifications {}

    MissionControl {}
    AppSwitcher {}
}
