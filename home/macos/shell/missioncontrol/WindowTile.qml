import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common

// Une fenêtre dans Mission Control : vignette vivante (ScreencopyView du
// toplevel Wayland) qui glisse de sa position réelle à l'écran (progress = 0)
// vers sa place dans la grille (progress = 1). Survol : liseré bleu + titre.
Item {
    id: tile

    required property var toplevel            // HyprlandToplevel
    // Géométrie réelle (coordonnées de l'écran) et cible dans la grille
    property rect real: Qt.rect(0, 0, 100, 100)
    property rect target: Qt.rect(0, 0, 100, 100)
    property real progress: 0
    property bool hovered: false
    property bool dimmed: false               // fenêtre d'une autre app (App Exposé)
    property real windowRadius: 16            // decoration:rounding d'Hyprland

    // Glisser-déposer (déplacement vers un autre bureau)
    property bool dragging: false
    property point dragPos: Qt.point(0, 0)    // coin haut-gauche pendant le glisser
    property real dragScale: 1

    signal activated()
    signal dragMoved(real x, real y)
    signal dropped(real x, real y)

    // Cible animée (réorganisation quand une fenêtre apparaît/disparaît)
    property real tx: target.x
    property real ty: target.y
    property real tw: target.width
    property real th: target.height
    property bool settle: false
    Behavior on tx { enabled: tile.settle; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on ty { enabled: tile.settle; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on tw { enabled: tile.settle; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on th { enabled: tile.settle; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    readonly property real p: progress
    x: dragging ? dragPos.x : real.x + (tx - real.x) * p
    y: dragging ? dragPos.y : real.y + (ty - real.y) * p
    width: dragging ? tw * dragScale : real.width + (tw - real.width) * p
    height: dragging ? th * dragScale : real.height + (th - real.height) * p
    // Échelle courante par rapport à la vraie fenêtre (coins, ombre)
    readonly property real sc: width / Math.max(1, real.width)

    // Ombre portée (reprend decoration:shadow d'Hyprland à l'échelle)
    RectangularShadow {
        anchors.fill: shot
        radius: shot.radius
        offset.y: 12 * tile.sc
        blur: 40 * tile.sc
        spread: 0
        color: Qt.rgba(0, 0, 0, 0.33)
        cached: false
    }

    // Liseré de survol (bleu système, 3 pt, détaché de 1 pt)
    Rectangle {
        anchors.fill: shot
        anchors.margins: -4
        radius: shot.radius + 4
        color: "transparent"
        border.width: 3
        border.color: "#3B99FC"
        opacity: tile.hovered && !tile.dragging && tile.p > 0.98 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    ClippingRectangle {
        id: shot
        anchors.fill: parent
        radius: tile.windowRadius * tile.sc
        color: Theme.dark ? "#1e1e1e" : "#ececec"
        contentUnderBorder: true

        ScreencopyView {
            id: view
            anchors.fill: parent
            captureSource: tile.toplevel?.wayland ?? null
            live: true
            paintCursor: false
        }
        // Voile des fenêtres d'autres apps (App Exposé)
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: tile.dimmed ? 0.45 * tile.p : 0
        }
    }

    // Titre sous la fenêtre survolée
    Rectangle {
        id: titlePill
        anchors.top: parent.bottom
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(titleText.implicitWidth + 22, Math.max(140, tile.width + 40))
        height: 24
        radius: height / 2
        color: Qt.rgba(0.12, 0.12, 0.13, 0.78)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        opacity: tile.hovered && !tile.dragging && tile.p > 0.98 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Text {
            id: titleText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 22)
            text: tile.toplevel?.title || tile.toplevel?.lastIpcObject?.class || ""
            color: "white"
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: tile.p > 0.98
        cursorShape: Qt.ArrowCursor
        property point pressAt
        property point grab
        onEntered: tile.hovered = true
        onExited: tile.hovered = false
        onPressed: e => {
            pressAt = mapToItem(tile.parent, e.x, e.y);
            grab = Qt.point(e.x / tile.width, e.y / tile.height);
        }
        onPositionChanged: e => {
            if (!pressed) return;
            const pt = mapToItem(tile.parent, e.x, e.y);
            if (!tile.dragging && Math.hypot(pt.x - pressAt.x, pt.y - pressAt.y) > 6) {
                tile.dragging = true;
                tile.z = 1000;
            }
            if (tile.dragging) {
                // La fenêtre rapetisse en approchant de la barre des bureaux
                tile.dragScale = Math.max(0.35, Math.min(1, (pt.y - 140) / 260 + 0.35));
                const w = tile.tw * tile.dragScale, h = tile.th * tile.dragScale;
                tile.dragPos = Qt.point(pt.x - grab.x * w, pt.y - grab.y * h);
                tile.dragMoved(pt.x, pt.y);
            }
        }
        onReleased: e => {
            const pt = mapToItem(tile.parent, e.x, e.y);
            if (tile.dragging) {
                tile.dropped(pt.x, pt.y);
                tile.dragging = false;
                tile.dragScale = 1;
            } else {
                tile.activated();
            }
        }
    }
}
