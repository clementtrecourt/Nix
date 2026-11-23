pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// État global des panneaux : un seul panneau "modal" ouvert à la fois
// (spotlight, controlcenter, notificationcenter, missioncontrol, appswitcher,
// applemenu, ...). Les composants observent `openPanel`.
//
// IPC : quickshell -c macos ipc call shell toggle spotlight
//       quickshell -c macos ipc call shell close
Singleton {
    id: root

    property string openPanel: ""
    // Écran (nom de sortie) où le panneau doit apparaître : écran focalisé par défaut.
    property string panelScreen: ""

    function isOpen(name) { return openPanel === name; }
    function open(name) { openPanel = name; }
    function close() { openPanel = ""; }
    function toggle(name) { openPanel = (openPanel === name) ? "" : name; }

    IpcHandler {
        target: "shell"
        function toggle(name: string): void { root.toggle(name); }
        function open(name: string): void { root.open(name); }
        function close(): void { root.close(); }
        function current(): string { return root.openPanel; }
    }

    // Dock > « Afficher toutes les fenêtres » : classe de l'app à montrer dans
    // l'Exposé d'application (panneau "appexpose"). Vide = app au premier plan.
    property string exposeClass: ""

    // Barre des menus > icône Control Center : x du CENTRE de l'icône (coordonnées
    // de l'écran, -1 = inconnu). Renseigné par la barre ; le HUD volume/luminosité
    // (controlcenter/Osd.qml) s'affiche centré sous cette icône, comme sur Tahoe.
    property real controlCenterIconX: -1
}
