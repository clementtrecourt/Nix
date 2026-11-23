import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common

// Fenêtre "système" façon macOS Tahoe dessinée par le shell (À propos, Forcer à
// quitter, alertes, Polkit…) : surface layer-shell centrée sur l'écran actif,
// carte de verre aux grands rayons, pastilles rouge/jaune/vert, déplaçable par
// glisser, apparition "pop" (échelle 0,92 -> 1 + fondu) et disparition en fondu.
PanelWindow {
    id: win

    property bool shown: false
    property string title: ""
    property bool titleBar: true          // false : alerte sans barre de titre
    property bool closeEnabled: true
    property bool minimizeEnabled: false
    property bool zoomEnabled: false
    property bool exclusiveKeyboard: false
    property real radius: titleBar ? 16 : 26
    property int cardWidth: 300
    property int cardHeight: 200
    property color tint: titleBar
        ? (Theme.dark ? Qt.rgba(0.14, 0.14, 0.15, 0.93) : Qt.rgba(0.975, 0.975, 0.98, 0.94))
        : Theme.glassThick
    readonly property int titleBarHeight: titleBar ? 38 : 0
    readonly property int pad: 56          // marge pour l'ombre portée
    default property alias content: body.data
    property alias card: card

    signal closeRequested()
    signal minimizeRequested()

    // Écran actif (celui du curseur / de la fenêtre focalisée)
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    visible: shown || hideAnim.running
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: titleBar ? "macos-window" : "macos-alert"
    WlrLayershell.keyboardFocus: exclusiveKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true }

    implicitWidth: cardWidth + pad * 2
    implicitHeight: cardHeight + pad * 2

    // Position : centrée (un peu au-dessus du centre, comme AppKit) + déplacement
    property real dragX: 0
    property real dragY: 0
    margins.left: Math.round(((screen?.width ?? 1512) - implicitWidth) / 2 + dragX)
    margins.top: Math.round(((screen?.height ?? 982) - implicitHeight) * 0.42 + dragY)

    // Seule la carte reçoit les clics (pas la zone d'ombre)
    mask: Region { item: card }

    onShownChanged: {
        if (shown) {
            dragX = 0;
            dragY = 0;
            hideAnim.stop();
            showAnim.restart();
        } else {
            showAnim.stop();
            hideAnim.restart();
        }
    }

    Item {
        id: card
        x: win.pad
        y: win.pad
        width: win.cardWidth
        height: win.cardHeight
        transformOrigin: Item.Center
        opacity: 0
        scale: 0.92

        Glass {
            anchors.fill: parent
            radius: win.radius
            tint: win.tint
            shadowBlur: 1.0
            shadowOffset: 14
            shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.55 : 0.30)
        }

        // Déplacement par la barre de titre (ou tout le fond pour une alerte)
        MouseArea {
            id: dragArea
            width: parent.width
            height: win.titleBar ? win.titleBarHeight : parent.height
            property point start
            onPressed: mouse => start = Qt.point(mouse.x, mouse.y)
            onPositionChanged: mouse => {
                win.dragX += mouse.x - start.x;
                win.dragY += mouse.y - start.y;
            }
        }

        TrafficLights {
            visible: win.titleBar
            x: 14
            y: 13
            closeEnabled: win.closeEnabled
            minimizeEnabled: win.minimizeEnabled
            zoomEnabled: win.zoomEnabled
            onCloseClicked: win.closeRequested()
            onMinimizeClicked: win.minimizeRequested()
        }

        Text {
            visible: win.titleBar && win.title !== ""
            text: win.title
            anchors.horizontalCenter: parent.horizontalCenter
            y: 11
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: Theme.label
            opacity: 0.85
        }

        Item {
            id: body
            anchors.fill: parent
            anchors.topMargin: win.titleBarHeight
        }
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation {
            target: card; property: "scale"; from: 0.92; to: 1; duration: 320
            easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSpring
        }
    }
    ParallelAnimation {
        id: hideAnim
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: 160; easing.type: Easing.InQuad }
        NumberAnimation { target: card; property: "scale"; to: 0.96; duration: 160; easing.type: Easing.InQuad }
    }
}
