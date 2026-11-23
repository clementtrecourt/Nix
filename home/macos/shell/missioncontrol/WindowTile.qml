import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common
import "decor.js" as Decor

// Une fenêtre dans Mission Control : vignette vivante (ScreencopyView du
// toplevel Wayland) qui glisse de sa position réelle à l'écran (progress = 0)
// vers sa place dans la grille (progress = 1). Survol : liseré bleu + titre.
//
// La capture Wayland ne contient que le contenu du client : la barre de titre
// hyprbars, le liseré et l'ombre d'Hyprland sont redessinés (decor.js) pour que
// la vignette soit identique à la fenêtre au départ et à l'arrivée.
Item {
    id: tile

    required property var toplevel            // HyprlandToplevel
    // Géométrie réelle (barre de titre comprise, coordonnées de l'écran) et cible
    property rect realRect: Qt.rect(0, 0, 100, 100)
    property rect targetRect: Qt.rect(0, 0, 100, 100)
    property real progress: 0
    property bool hovered: false
    property bool active: false               // fenêtre focalisée (feux colorés, ombre forte)

    readonly property var ipc: toplevel?.lastIpcObject ?? {}
    readonly property string cls: ipc.class ?? ""
    readonly property bool fullscreen: (ipc.fullscreen ?? 0) > 0
    readonly property bool hasBar: Decor.hasBar(cls, fullscreen)
    readonly property real barH: hasBar ? Decor.barHeight : 0
    readonly property real windowRadius: Decor.radius(cls, fullscreen)

    // Glisser-déposer (déplacement vers un autre bureau)
    property bool dragging: false
    property point dragPos: Qt.point(0, 0)    // coin haut-gauche pendant le glisser
    property real dragScale: 1

    signal activated()
    signal dragMoved(real x, real y)
    signal dropped(real x, real y)

    // Cible animée (réorganisation quand une fenêtre apparaît/disparaît)
    property real tx: targetRect.x
    property real ty: targetRect.y
    property real tw: targetRect.width
    property real th: targetRect.height
    property bool settle: false
    Behavior on tx { enabled: tile.settle; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on ty { enabled: tile.settle; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on tw { enabled: tile.settle; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on th { enabled: tile.settle; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    readonly property real p: progress
    readonly property real baseX: realRect.x + (tx - realRect.x) * p
    readonly property real baseY: realRect.y + (ty - realRect.y) * p
    readonly property real baseW: realRect.width + (tw - realRect.width) * p
    readonly property real baseH: realRect.height + (th - realRect.height) * p
    // 1 pendant le glisser, revient à 0 (retour animé à sa place) au lâcher
    property real dragBlend: dragging ? 1 : 0
    Behavior on dragBlend { enabled: !tile.dragging; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    x: baseX + (dragPos.x - baseX) * dragBlend
    y: baseY + (dragPos.y - baseY) * dragBlend
    width: baseW + (tw * dragScale - baseW) * dragBlend
    height: baseH + (th * dragScale - baseH) * dragBlend
    // Échelle courante par rapport à la vraie fenêtre
    readonly property real sc: width / Math.max(1, realRect.width)

    // Ombre portée (decoration:shadow d'Hyprland : 0 20 60, 0x99 active / 0x55).
    // Elle n'apparaît qu'avec le fond d'écran de Mission Control : au départ,
    // l'ombre réelle d'Hyprland est encore visible dessous (pas de double ombre).
    property real shadowOpacity: 1
    RectangularShadow {
        anchors.fill: shot
        opacity: tile.shadowOpacity
        radius: shot.radius
        offset.y: 20 * tile.sc
        blur: 60 * tile.sc
        spread: 0
        color: Qt.rgba(0, 0, 0, tile.active ? 0.60 : 0.33)
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
        // Sous la capture : fond de la barre (terminaux translucides floutés par Hyprland)
        color: tile.hasBar ? Decor.barColor(tile.cls) : "transparent"

        ScreencopyView {
            id: view
            y: tile.barH * tile.sc
            width: parent.width
            height: parent.height - y
            captureSource: tile.toplevel?.wayland ?? null
            live: true
            paintCursor: false
        }

        // Barre de titre hyprbars, dessinée à taille réelle puis mise à l'échelle
        Item {
            visible: tile.hasBar
            width: tile.realRect.width
            height: Decor.barHeight
            scale: tile.sc
            transformOrigin: Item.TopLeft

            Rectangle {
                anchors.fill: parent
                color: Decor.barColor(tile.cls)
            }
            // Feux tricolores : Ø 14, marge 10, écart 9 (gris si fenêtre inactive)
            Row {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9
                Repeater {
                    model: ["#ff5f57", "#febc2e", "#28c840"]
                    Rectangle {
                        required property var modelData
                        width: 14
                        height: 14
                        radius: 7
                        color: tile.active ? modelData : "#4f4f52"
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 160)
                text: tile.toplevel?.title ?? ""
                color: Qt.rgba(1, 1, 1, 0.85)
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }

    // Liseré d'un pixel (general:border_size = 1)
    Rectangle {
        anchors.fill: shot
        radius: shot.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, tile.active ? 0.14 : 0.08)
        visible: !tile.fullscreen
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
            text: tile.toplevel?.title || tile.cls
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
                tile.dragPos = Qt.point(tile.x, tile.y);
                tile.dragging = true;
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
                tile.dragging = false;
                tile.dropped(pt.x, pt.y);
            } else {
                tile.activated();
            }
        }
    }
}
