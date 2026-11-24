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

    // HUD volume / luminosité (controlcenter/Osd.qml) : type affiché ("volume",
    // "brightness", "keyboard"), "" quand il est masqué. Sur Tahoe, l'élément
    // correspondant de la barre des menus (Son, Écran) apparaît en surbrillance
    // tant que le HUD est visible, et le HUD se centre dessous : la barre peut
    // publier le x du centre de cet élément dans osdAnchorX (-1 = inconnu ; le HUD
    // se centre alors sous l'icône du Control Center).
    property string osdKind: ""
    property real osdAnchorX: -1

    // Écran verrouillé (session/LockScreen.qml) et heure du verrouillage (ms) :
    // les notifications reçues depuis s'affichent sur l'écran de verrouillage
    // (System Settings > Notifications > « Allow notifications when the screen
    // is locked ») et leurs aperçus suivent « Show previews ».
    property bool locked: false
    property real lockedSince: 0
}
