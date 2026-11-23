import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common
import qs.session

// Vignette d'un bureau dans la barre des Spaces : fond d'écran + fenêtres du
// workspace en miniature (captures Wayland), à l'échelle de l'écran.
Item {
    id: root

    required property int wsId
    required property var monitor             // HyprlandMonitor de l'écran
    property bool live: false                 // capture continue (barre dépliée)
    property real screenW: 1512
    property real screenH: 982

    readonly property real k: width / Math.max(1, screenW)

    ClippingRectangle {
        anchors.fill: parent
        radius: 3
        color: "black"

        WallpaperView {
            anchors.fill: parent
        }

        Repeater {
            model: {
                const out = Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === root.wsId);
                // Ordre d'empilement : la fenêtre la plus récemment focalisée au-dessus
                return out.sort((a, b) => (b.lastIpcObject?.focusHistoryID ?? 0) - (a.lastIpcObject?.focusHistoryID ?? 0));
            }
            delegate: ClippingRectangle {
                required property var modelData
                readonly property var ipc: modelData.lastIpcObject ?? {}
                x: ((ipc.at?.[0] ?? 0) - (root.monitor?.x ?? 0)) * root.k
                y: ((ipc.at?.[1] ?? 0) - (root.monitor?.y ?? 0)) * root.k
                width: (ipc.size?.[0] ?? 0) * root.k
                height: (ipc.size?.[1] ?? 0) * root.k
                radius: 16 * root.k
                color: Theme.dark ? "#1e1e1e" : "#ececec"
                ScreencopyView {
                    anchors.fill: parent
                    captureSource: modelData.wayland ?? null
                    live: root.live
                }
            }
        }
    }
}
