import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common

// Vignette flottante macOS après une capture : en bas à droite, glisse depuis le
// bord droit, reste ~5 s (pause au survol) puis repart à droite. Clic = ouvrir ;
// glisser vers la droite = ranger tout de suite.
PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    property string path: ""
    property bool shown: false
    readonly property bool isVideo: /\.(mp4|mkv|webm|mov)$/i.test(path)

    readonly property int margin: 18
    readonly property int maxW: 210
    readonly property int maxH: 150

    // Taille de la vignette selon le ratio de l'image
    readonly property real ratio: img.status === Image.Ready && img.implicitHeight > 0
        ? img.implicitWidth / img.implicitHeight : 16 / 10
    readonly property int thumbW: Math.round(ratio >= maxW / maxH ? maxW : maxH * ratio)
    readonly property int thumbH: Math.round(ratio >= maxW / maxH ? maxW / ratio : maxH)

    WlrLayershell.namespace: "macos-screenshot-thumb"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: true; right: true }
    implicitWidth: maxW + margin + 40
    implicitHeight: maxH + margin + 40
    color: "transparent"
    visible: shown || thumb.x < width

    mask: Region { item: thumb }

    Connections {
        target: Shots
        function onCaptured(p) { win.present(p); }
    }

    function present(p) {
        // Une nouvelle capture remplace la précédente (déjà enregistrée)
        path = "";
        path = p;
        shown = true;
        thumb.dragX = 0;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 5000
        running: win.shown && !hover.hovered && !drag.active
        onTriggered: win.shown = false
    }

    Item {
        id: thumb
        property real dragX: 0
        width: win.thumbW
        height: win.thumbH
        y: win.height - win.margin - height
        x: (win.shown ? win.width - win.margin - width : win.width + 30) + dragX
        Behavior on x {
            enabled: !drag.active
            NumberAnimation {
                id: slide
                duration: win.shown ? 460 : 340
                easing.type: Easing.BezierSpline
                easing.bezierCurve: win.shown ? [0.16, 1.0, 0.3, 1.0, 1, 1] : [0.5, 0.0, 0.9, 0.5, 1, 1]
            }
        }

        // Ombre + verre (liseré clair) sous l'image
        Glass {
            anchors.fill: parent
            anchors.margins: -2
            radius: 9
            thick: true
            shadowOffset: 6
            shadowBlur: 0.9
        }
        ClippingRectangle {
            anchors.fill: parent
            radius: 7
            color: "black"
            Image {
                id: img
                anchors.fill: parent
                source: win.path && !win.isVideo ? "file://" + win.path : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize: Qt.size(win.maxW * 2, win.maxH * 2)
                smooth: true
                mipmap: true
            }
            // Vidéo : pas d'aperçu, pictogramme de lecture
            Symbol {
                anchors.centerIn: parent
                visible: win.isVideo
                name: "rectangle.inset.filled.badge.record"
                size: 40
                color: "white"
            }
        }

        HoverHandler { id: hover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { Shots.open(win.path); win.shown = false; }
        }
        DragHandler {
            id: drag
            target: null
            yAxis.enabled: false
            onTranslationChanged: thumb.dragX = Math.max(-20, translation.x)
            onActiveChanged: {
                if (active) return;
                if (translation.x > 50) win.shown = false;
                thumb.dragX = 0;
            }
        }
    }
}
