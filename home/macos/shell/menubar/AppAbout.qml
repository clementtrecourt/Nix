import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common
import qs.services

// Panneau « À propos de <App> » (orderFrontStandardAboutPanel) : petite fenêtre
// NON modale, comme sur macOS. Feux tricolores (seul le rouge est actif),
// icône de l'app, nom en gras, « Version X » en petit gris.
//
// Surface layer-shell de la taille du panneau seulement : les clics à côté
// atteignent les apps normalement. Elle prend le clavier à la demande (clic
// dessus) : Échap ou ⌘W la ferment. On la déplace en la faisant glisser.
//
// Version : déduite du chemin du store Nix de l'exécutable de l'app
// (/nix/store/<hash>-kitty-0.43.1/bin/kitty -> « Version 0.43.1 »). Les
// .desktop n'ont ni version ni copyright : sans chemin Nix, la ligne est omise.
Scope {
    id: root

    property string cls: ""
    property bool open: false
    property string version: ""

    readonly property var entry: Apps.entryFor(cls || "nemo")

    function show(c) {
        cls = c;
        version = "";
        // Position par défaut : centré horizontalement, au premier quart de l'écran
        win.posX = -1;
        open = true;
        const cmd = entry?.command ?? [];
        const exe = cmd.length ? cmd[0] : (c || "nemo");
        versionProbe.running = false;
        versionProbe.command = ["sh", "-c",
            'p=$(command -v "$1" 2>/dev/null) || exit 0; p=$(readlink -f "$p"); ' +
            'case "$p" in /nix/store/*) echo "$p" | cut -d/ -f4;; esac', "sh", exe];
        versionProbe.running = true;
    }
    function hide() { open = false; }

    Process {
        id: versionProbe
        stdout: StdioCollector {
            onStreamFinished: {
                // "<hash>-kitty-0.43.1" -> "0.43.1" ; "<hash>-zen-beta-1.17b" -> "1.17b"
                const name = text.trim().replace(/^[a-z0-9]{32}-/, "");
                const m = /-(\d[\w.+~]*(?:-[\w.+~]+)?)$/.exec(name);
                root.version = m ? m[1].replace(/-unwrapped$/, "") : "";
            }
        }
    }

    PanelWindow {
        id: win
        visible: root.open
        color: "transparent"
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

        // Marge pour l'ombre du verre
        readonly property int pad: 40
        // Position du panneau (coin haut-gauche de la carte) ; -1 = par défaut
        property real posX: -1
        property real posY: -1
        readonly property real screenW: screen?.width ?? 1512
        readonly property real screenH: screen?.height ?? 982

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "macos-about-app"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            left: true
        }
        margins.left: Math.round((posX < 0 ? (screenW - card.width) / 2 : posX) - pad)
        margins.top: Math.round((posY < 0 ? screenH * 0.22 : posY) - pad)
        implicitWidth: card.width + 2 * pad
        implicitHeight: card.height + 2 * pad

        // Seule la carte reçoit la souris (l'ombre laisse passer les clics)
        mask: Region { item: card }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape || ((event.modifiers & (Qt.MetaModifier | Qt.ControlModifier)) && event.key === Qt.Key_W)) {
                    root.hide();
                    event.accepted = true;
                }
            }
        }

        // Fond de la fenêtre (teinte posée ici : voir MenuPanel, la teinte du
        // shader de Glass est prémultipliée deux fois)
        Rectangle {
            anchors.fill: card
            radius: card.radius
            color: Theme.glassThick
            antialiasing: true
        }
        Glass {
            id: card
            x: win.pad
            y: win.pad
            width: 284
            height: col.implicitHeight + 62
            radius: Theme.radiusWindow
            tint: "transparent"

            // Glisser la fenêtre par n'importe quel point de son fond
            MouseArea {
                anchors.fill: parent
                property point grab
                onPressed: mouse => grab = Qt.point(mouse.x, mouse.y)
                onPositionChanged: mouse => {
                    const cx = win.margins.left + win.pad, cy = win.margins.top + win.pad;
                    win.posX = Math.max(0, Math.min(win.screenW - card.width, cx + mouse.x - grab.x));
                    win.posY = Math.max(Theme.menuBarHeight, Math.min(win.screenH - 40, cy + mouse.y - grab.y));
                }
            }

            // Feux tricolores : fermeture active, réduction et zoom désactivés
            Row {
                x: 14
                y: 14
                spacing: 8
                Rectangle {
                    width: 12; height: 12; radius: 6
                    color: "#FF5F57"
                    border.width: 0.5
                    border.color: Qt.rgba(0, 0, 0, 0.18)
                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -0.5
                        visible: closeArea.containsMouse
                        text: "×"
                        font.pixelSize: 11
                        font.bold: true
                        color: Qt.rgba(0.3, 0, 0, 0.75)
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.hide()
                    }
                }
                Repeater {
                    model: 2
                    Rectangle {
                        width: 12; height: 12; radius: 6
                        color: Theme.fill
                        border.width: 0.5
                        border.color: Theme.separator
                    }
                }
            }

            Column {
                id: col
                anchors.horizontalCenter: parent.horizontalCenter
                y: 38
                width: parent.width - 48
                spacing: 4

                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitSize: 64
                    source: root.cls ? Apps.icon(root.cls) : Quickshell.iconPath("system-file-manager", "folder")
                }
                Item { width: 1; height: 8 }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.cls ? Apps.name(root.cls) : "Finder"
                    font.family: Theme.font
                    renderType: Text.CurveRendering
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Theme.label
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.version !== ""
                    text: "Version " + root.version
                    font.family: Theme.font
                    renderType: Text.CurveRendering
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.labelSecondary
                }
            }
        }
    }
}
