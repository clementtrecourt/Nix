import QtQuick
import Quickshell
import Quickshell.Wayland

// Bureau : un fond d'écran par écran (calque Background) + clic droit -> menu
// contextuel du bureau (Finder).
Scope {
    id: root

    // Demande d'ouverture du menu contextuel (écran, position locale)
    signal contextMenuRequested(var screen, real x, real y)

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            color: "black"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "macos-wallpaper"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }

            WallpaperView {
                anchors.fill: parent
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onPressed: mouse => root.contextMenuRequested(win.modelData, mouse.x, mouse.y)
            }
        }
    }
}
