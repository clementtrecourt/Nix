import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common

// Menu contextuel du bureau (clic droit sur le fond d'écran), comme le Finder.
// Surface plein écran transparente : un clic en dehors du menu le ferme.
Scope {
    id: root

    property var screen: null
    property real menuX: 0
    property real menuY: 0
    property bool shown: false

    signal changeWallpaper()

    function popup(scr, x, y) {
        screen = scr;
        menuX = x;
        menuY = y;
        shown = true;
    }
    function dismiss() { shown = false; }

    readonly property string desktopDir: Quickshell.env("HOME") + "/Desktop"

    function newFolder() {
        // "dossier sans titre", "dossier sans titre 2", … comme le Finder
        Quickshell.execDetached(["sh", "-c",
            'd="$1"; mkdir -p "$d"; n="dossier sans titre"; i=2; p="$d/$n"; ' +
            'while [ -e "$p" ]; do p="$d/$n $i"; i=$((i+1)); done; mkdir "$p"',
            "sh", desktopDir]);
    }

    LazyLoader {
        active: root.shown && root.screen !== null

        PanelWindow {
            id: win
            screen: root.screen
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "macos-menu"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: root.dismiss()
            }

            TahoeMenu {
                id: menu
                focus: true
                // Ouvert vers le bas-droite du pointeur, replié si l'écran manque
                x: Math.min(root.menuX, win.width - width - 6)
                y: root.menuY + height > win.height - 6 ? Math.max(6, root.menuY - height) : root.menuY
                width: implicitWidth
                height: implicitHeight
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 90 } }

                Keys.onEscapePressed: root.dismiss()

                items: [
                    { text: "Nouveau dossier", icon: "folder.badge.plus", action: "newfolder" },
                    { separator: true },
                    { text: "Lire les informations", icon: "info.circle", enabled: false },
                    { text: "Changer le fond d’écran…", icon: "photo", action: "wallpaper" },
                    { text: "Modifier les widgets…", icon: "square.grid.2x2", enabled: false },
                    { separator: true },
                    { text: "Utiliser les piles", icon: "square.stack.3d.up", enabled: false },
                    { text: "Trier par", icon: "arrow.up.arrow.down", submenu: true, enabled: false },
                    { text: "Afficher les options de présentation", icon: "eye", enabled: false }
                ]

                onTriggered: item => {
                    root.dismiss();
                    if (item.action === "newfolder") root.newFolder();
                    else if (item.action === "wallpaper") root.changeWallpaper();
                }
            }
        }
    }
}
