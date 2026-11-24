import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common
import qs.services
import "decor.js" as Decor

// Une fenêtre dans Mission Control : vignette vivante (ScreencopyView du
// toplevel Wayland) qui glisse de sa position réelle à l'écran (progress = 0)
// vers sa place dans la grille (progress = 1). Survol : liseré bleu + titre.
// App Exposé : titre de la fenêtre affiché en permanence sous la vignette.
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
    property bool showTitle: false            // App Exposé : titre permanent sous la fenêtre
    property real labelMaxY: 1e9              // bas autorisé du titre (au-dessus du Dock)

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
    property bool draggable: true             // faux : clic seulement (fenêtres réduites)

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
    // Largeur de la vraie fenêtre (différente de realRect pour une fenêtre
    // réduite, qui part du bas de l'écran déjà à sa taille de vignette)
    property real naturalWidth: realRect.width
    readonly property real sc: width / Math.max(1, naturalWidth)
    // La capture Wayland est opaque (alpha perdu) : une fenêtre translucide
    // (terminal) « sauterait » au départ. Fondu enchaîné très bref avec la vraie
    // fenêtre, restée dessous, au tout début (et à la toute fin) de l'animation.
    opacity: Math.min(1, progress / 0.06)

    // Ombre portée = decoration:shadow d'Hyprland (hyprland-look.nix : range 52,
    // décalage 0 14, 0x28 active / 0x1a inactive) : aucun saut au départ ni à
    // l'arrivée de l'animation.
    // Elle n'apparaît qu'avec le fond d'écran de Mission Control : au départ,
    // l'ombre réelle d'Hyprland est encore visible dessous (pas de double ombre).
    property real shadowOpacity: 1
    RectangularShadow {
        anchors.fill: shot
        opacity: tile.shadowOpacity
        radius: shot.radius
        offset.y: 14 * tile.sc
        blur: 52 * tile.sc
        spread: 0
        color: Qt.rgba(0, 0, 0, tile.active ? 0x28 / 255 : 0x1a / 255)
        cached: false
    }

    // Liseré de survol (couleur d'accent, 3 pt, détaché de 1 pt)
    Rectangle {
        anchors.fill: shot
        anchors.margins: -4
        radius: shot.radius + 4
        color: "transparent"
        border.width: 3
        border.color: Theme.accent
        opacity: tile.hovered && !tile.dragging && tile.p > 0.98 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    ClippingRectangle {
        id: shot
        anchors.fill: parent
        radius: tile.windowRadius * tile.sc
        // Sous la capture : fond de la barre
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
            width: tile.naturalWidth
            height: Decor.barHeight
            scale: tile.sc
            transformOrigin: Item.TopLeft

            Rectangle {
                anchors.fill: parent
                color: Decor.barColor(tile.cls)
            }
            // Feux tricolores (hyprland-look.nix : bar_padding 8, Ø 14, écart 9 ;
            // gris #585858 si la fenêtre est inactive)
            Row {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9
                Repeater {
                    model: [Theme.trafficRed, Theme.trafficYellow, Theme.trafficGreen]
                    Rectangle {
                        required property var modelData
                        width: 14
                        height: 14
                        radius: 7
                        color: tile.active ? modelData : "#585858"
                    }
                }
            }
            // Titre aligné à gauche après les feux (bar_text_align = left),
            // Inter 13 semi-gras, blanc 85 % (30 % si inactive)
            Text {
                x: 86
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - x - 12)
                text: tile.toplevel?.title ?? ""
                color: Qt.rgba(1, 1, 1, tile.active ? 0.85 : 0.30)
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                renderType: Text.NativeRendering
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

    // Titre sous la fenêtre (Tahoe : texte seul, sans icône)
    //  - App Exposé : en permanence, texte blanc 13 pt sur le fond d'écran ;
    //  - Mission Control : au survol seulement, dans une pastille sombre.
    // Jamais sur le Dock : remonté au besoin au ras du bas de la vignette.
    readonly property bool titleShown: (tile.showTitle || tile.hovered) && !tile.dragging && tile.p > 0.98
    Rectangle {
        id: titlePill
        readonly property real maxW: Math.max(160, tile.width + 40)
        readonly property bool plain: tile.showTitle
        width: Math.round(titleText.width + (plain ? 0 : 20))
        height: plain ? Math.ceil(titleText.implicitHeight) : 24
        x: Math.round((tile.width - width) / 2)
        y: Math.round(Math.min(tile.height + (plain ? 8 : 10), tile.labelMaxY - tile.y - height) )
        radius: height / 2
        color: plain ? "transparent" : Qt.rgba(0.12, 0.12, 0.13, 0.78)
        border.width: plain ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        opacity: tile.titleShown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Text {
            id: titleText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, titlePill.maxW - (titlePill.plain ? 0 : 20))
            text: tile.toplevel?.title || Apps.displayName(tile.cls)
            color: "white"
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
            renderType: Text.NativeRendering
            // Lisible sur un fond d'écran clair (léger halo sombre, comme macOS)
            style: titlePill.plain ? Text.Raised : Text.Normal
            styleColor: Qt.rgba(0, 0, 0, 0.25)
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
            if (tile.draggable && !tile.dragging && Math.hypot(pt.x - pressAt.x, pt.y - pressAt.y) > 6) {
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
