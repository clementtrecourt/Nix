import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common

// Fenêtre "système" façon macOS Tahoe dessinée par le shell (À propos, Forcer à
// quitter, alertes, Polkit…) : surface layer-shell centrée sur l'écran actif,
// carte Liquid Glass (réfraction d'une capture de l'écran prise juste avant
// l'ouverture), pastilles rouge/jaune/vert, déplaçable par glisser, apparition
// "pop" (échelle 0,92 -> 1 + fondu) et disparition en fondu.
//
// Matériau : verre DÉPOLI (SessionGlass.frost : flou de 40 px, sans lentille de
// bord) : le fond n'y paraît que comme une teinte, jamais lisible. Teintes
// (voile composé sur le fond flouté et saturé), relevées sur les captures
// Tahoe 26 (512pixels) : fenêtre claire ≈ blanc à 80 % teinté par le fond
// (About This Mac : 225,249,255 sur un ciel 86,141,193) ; alerte claire ≈
// blanc à 60 % (Empty Trash : 192,229,255 sur 100,153,199).
// `opaque` : fond plein (Force Quit Applications : blanc 255, liste et barre de
// titre comprises).
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
    // Ligne de séparation sous la barre de titre (Force Quit Applications)
    property bool titleSeparator: false
    property bool opaque: false
    property color tint: opaque
        ? (Theme.dark ? "#2B2B2D" : "#FFFFFF")
        : titleBar
        ? (Theme.dark ? Qt.rgba(0.14, 0.14, 0.15, 0.80) : Qt.rgba(1, 1, 1, 0.80))
        : (Theme.dark ? Qt.rgba(0.13, 0.13, 0.14, 0.72) : Qt.rgba(1, 1, 1, 0.60))
    // Flou du verre dépoli (px logiques)
    property real frost: 40
    // Barre de titre Tahoe : 31 pt (séparateur à 31 pt sur Force Quit)
    readonly property int titleBarHeight: titleBar ? 31 : 0
    readonly property int pad: 56          // marge pour l'ombre portée
    default property alias content: body.data
    property alias card: card

    signal closeRequested()
    signal minimizeRequested()

    // Écran actif (celui du curseur / de la fenêtre focalisée)
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    // Fond Liquid Glass : capture de l'écran prise avant l'apparition
    property Item glassBackdrop: backdrop
    GlassBackdrop {
        id: backdrop
        mode: "snapshot"
        screen: win.screen
        // (opacité de la carte : la fenêtre reste le temps du fondu de fermeture)
        want: win.shown || card.opacity > 0.001
    }

    visible: backdrop.pass
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    // "macos-lg-*" : pas de flou Hyprland (le verre floute et réfracte lui-même)
    WlrLayershell.namespace: titleBar ? "macos-lg-window" : "macos-lg-alert"
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
            // Fenêtre encore visible (réouverture pendant le fondu) : on repart
            // de l'état courant ; sinon l'animation part quand la capture est là
            if (visible) showAnim.restart();
        } else {
            showAnim.stop();
            hideAnim.restart();
        }
    }
    onVisibleChanged: if (visible && shown) showAnim.restart()

    Item {
        id: card
        x: win.pad
        y: win.pad
        width: win.cardWidth
        height: win.cardHeight
        transformOrigin: Item.Center
        opacity: 0
        scale: 0.92

        // Filet extérieur sombre (0,5 pt à 30 % relevé sur Force Quit à 2x ;
        // 1 px à 15 % sur un écran 1x)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: win.radius + 1
            color: "transparent"
            border.width: 1
            border.color: Theme.dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.15)
        }
        SessionGlass {
            anchors.fill: parent
            radius: win.radius
            tint: win.tint
            frost: win.frost
            opaque: win.opaque
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

        // Ligne sous la barre de titre (0,5 pt)
        Rectangle {
            visible: win.titleBar && win.titleSeparator
            y: win.titleBarHeight - height
            width: parent.width
            height: 0.5
            color: Theme.dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.10)
        }

        // Pastilles : centres à 16 pt du bord haut et du bord gauche
        TrafficLights {
            id: lights
            visible: win.titleBar
            x: 9
            y: 9
            closeEnabled: win.closeEnabled
            minimizeEnabled: win.minimizeEnabled
            zoomEnabled: win.zoomEnabled
            onCloseClicked: win.closeRequested()
            onMinimizeClicked: win.minimizeRequested()
        }

        // Titre : centré ~9 pt à gauche du milieu (Force Quit Tahoe : centre du
        // titre à 431 contre 450 à 2x), décalé à droite des pastilles s'il
        // manque de place. Gris 89 sur blanc (noir à 65 %).
        Text {
            visible: win.titleBar && win.title !== ""
            text: win.title
            x: Math.round(Math.max(lights.x + lights.width + 14, (parent.width - implicitWidth) / 2 - 9))
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 16
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Bold
            color: Theme.label
            opacity: Theme.dark ? 0.85 : 0.65
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
