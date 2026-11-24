import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common
import "decor.js" as Decor

// Vignette d'un bureau dans la barre des Spaces : fond d'écran + fenêtres du
// workspace en miniature (captures Wayland), à l'échelle de l'écran.
Item {
    id: root

    required property int wsId
    required property var monitor             // HyprlandMonitor de l'écran
    required property Item wallpaper          // fond d'écran plein écran (texture réduite ici)
    property bool live: false                 // capture continue (barre dépliée)
    property bool shown: true                 // faux : Mission Control fermé (aucune capture)
    property real screenW: 1512
    property real screenH: 982

    readonly property real k: width / Math.max(1, screenW)

    ClippingRectangle {
        anchors.fill: parent
        radius: 3
        color: "black"

        // Le fond d'écran plein écran réduit (mipmaps : net et sans crénelage)
        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: root.wallpaper
            mipmap: true
            smooth: true
        }

        Repeater {
            model: ScriptModel {
                values: {
                    if (!root.shown) return [];
                    const out = Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === root.wsId);
                    // Ordre d'empilement réel : la fenêtre du dessus en dernier
                    return Stacking.sort(out);
                }
            }
            delegate: ClippingRectangle {
                id: mini
                required property var modelData
                readonly property var ipc: modelData.lastIpcObject ?? {}
                readonly property bool fs: (ipc.fullscreen ?? 0) > 0
                // Barre de titre hyprbars (au-dessus de la zone client)
                readonly property real bar: Decor.hasBar(ipc.class ?? "", fs) ? Decor.barHeight : 0
                x: ((ipc.at?.[0] ?? 0) - (root.monitor?.x ?? 0)) * root.k
                y: ((ipc.at?.[1] ?? 0) - (root.monitor?.y ?? 0) - bar) * root.k
                width: (ipc.size?.[0] ?? 0) * root.k
                height: ((ipc.size?.[1] ?? 0) + bar) * root.k
                radius: Decor.radius(ipc.class ?? "", fs) * root.k
                color: bar > 0 ? Decor.barColor(ipc.class ?? "") : "transparent"
                ScreencopyView {
                    y: mini.bar * root.k
                    width: parent.width
                    height: parent.height - y
                    captureSource: mini.modelData.wayland ?? null
                    live: root.live
                }
            }
        }
    }
}
