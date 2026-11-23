import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.common
import qs.services

// Une tuile du Dock (app, séparateur, fenêtre minimisée, pile, Corbeille).
// La géométrie horizontale (px, pw, ps) est imposée par Dock.layout() ; la tuile
// gère seule son contenu vertical : icône posée sur la ligne de base, agrandie
// vers le haut, rebond, point d'app ouverte.
Item {
    id: tile

    required property int index
    required property string key
    required property string kind
    required property string appId
    required property string cls
    required property string address
    required property bool removing
    required property bool fresh

    // Fourni par le Dock
    required property var dock

    // Imposé par la mise en page
    property real px: 0
    property real pw: baseW
    property real ps: 1          // facteur d'agrandissement (1 = repos)

    x: px
    width: pw
    height: parent ? parent.height : 0

    readonly property bool isApp: kind === "app"
    readonly property bool isSeparator: kind === "separator"
    readonly property bool isWindow: kind === "window"
    readonly property real tsz: dock.tile
    // Largeur de base : une tuile, ou la fente du séparateur (0,46 tuile, mesuré sur Tahoe)
    readonly property real baseW: isSeparator ? Math.round(tsz * 0.46) : tsz

    // ---- Apparition / disparition (les voisines s'écartent / se resserrent) ----
    property real presence: fresh ? 0 : 1
    Component.onCompleted: if (fresh) presence = 1
    onRemovingChanged: if (removing) presence = 0
    Behavior on presence {
        NumberAnimation {
            id: presenceAnim
            duration: 320
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveStandard
            onRunningChanged: {
                if (!running && tile.removing && tile.presence === 0) tile.dock.model.finishRemoval(tile.key);
            }
        }
    }
    onPresenceChanged: dock.requestLayout()
    onBaseWChanged: dock.requestLayout()

    // ---- État ----
    readonly property var windows: isApp ? dock.model.windowsFor(cls) : []
    readonly property bool running: isApp && (windows.length > 0)
    readonly property var launchState: isApp ? (dock.model.launching[appId] ?? null) : null
    readonly property bool urgent: isApp && cls !== "" && dock.model.urgentClasses.includes(cls)
    readonly property var toplevel: isWindow ? dock.model.toplevelByAddress(address) : null
    property bool pressed: false

    readonly property string label: {
        if (isWindow) return toplevel?.title || Apps.name(cls);
        if (kind === "folder") return "Téléchargements";
        if (kind === "trash") return "Corbeille";
        if (appId === dock.model.appsTileId) return "Apps";
        return Apps.name(appId || cls);
    }
    readonly property string iconSource: {
        if (kind === "folder") return Quickshell.iconPath("folder-download", "folder");
        if (kind === "trash") return Quickshell.iconPath(dock.trashFull ? "user-trash-full" : "user-trash", "user-trash");
        if (appId === dock.model.appsTileId) return Quickshell.iconPath("view-app-grid", "application-x-executable");
        return Apps.icon(appId || cls);
    }

    // ---- Rebond (lancement / demande d'attention), piloté par l'horloge du Dock ----
    // Lancement : paraboles de 0,7 s, hauteur ≈ 0,5 tuile ; on termine le saut en cours
    // quand la fenêtre apparaît. Attention : sauts plus hauts suivis d'une pause.
    readonly property real bounce: {
        const now = dock.now;
        if (launchState) {
            const P = 700, el = now - launchState.start;
            if (el < 0) return 0;
            if (launchState.end) {
                const stop = Math.ceil(Math.max(1, launchState.end - launchState.start) / P) * P;
                if (el >= stop) return 0;
            }
            const f = (el % P) / P;
            return tsz * 0.5 * 4 * f * (1 - f);
        }
        if (urgent) {
            const P = 1100, flight = 640, el = now % P;
            if (el > flight) return 0;
            const f = el / flight;
            return tsz * 0.9 * 4 * f * (1 - f);
        }
        return 0;
    }

    // Tuile "virtuelle" agrandie, posée sur la ligne de base du Dock
    readonly property real vSize: tsz * ps
    readonly property real vBottom: dock.baseY
    readonly property real vTop: vBottom - vSize - bounce
    readonly property real centerX: width / 2

    // ---- Séparateur : trait de 1 pt, 0,95 tuile de haut ----
    Rectangle {
        visible: tile.isSeparator
        width: 1
        height: Math.round(tile.tsz * 0.95)
        x: Math.round(tile.width / 2 - 0.5)
        y: tile.dock.baseY - tile.tsz / 2 - height / 2
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.28)
        opacity: tile.presence
    }

    // ---- Icône ----
    Item {
        id: iconBox
        visible: !tile.isSeparator && !tile.isWindow
        width: tile.vSize
        height: tile.vSize
        x: tile.centerX - width / 2
        y: tile.vTop
        opacity: Math.min(1, tile.presence * 1.4)
        scale: 0.6 + 0.4 * tile.presence
        transformOrigin: Item.Bottom

        IconImage {
            id: icon
            anchors.centerIn: parent
            // Les icônes MacTahoe dessinent le squircle sur 87,5 % du canevas, celles de
            // macOS sur 80 % : on réduit pour retrouver la proportion du vrai Dock.
            implicitSize: Math.round(tile.vSize * tile.dock.iconRatio)
            source: tile.iconSource
            asynchronous: false
            mipmap: true
            layer.enabled: tile.pressed
            layer.effect: MultiEffect {
                // macOS assombrit l'icône pendant l'appui
                brightness: -0.35
            }
        }
    }

    // ---- Fenêtre minimisée : miniature + badge de l'app ----
    Item {
        id: thumbBox
        visible: tile.isWindow
        width: tile.vSize
        height: tile.vSize
        x: tile.centerX - width / 2
        y: tile.vTop
        opacity: Math.min(1, tile.presence * 1.4)

        readonly property real winW: tile.toplevel?.lastIpcObject?.size?.[0] ?? 16
        readonly property real winH: tile.toplevel?.lastIpcObject?.size?.[1] ?? 10
        readonly property real fit: Math.min(width * 0.9 / Math.max(1, winW), height * 0.9 / Math.max(1, winH))

        ClippingRectangle {
            id: thumbClip
            anchors.centerIn: parent
            width: Math.max(4, thumbBox.winW * thumbBox.fit)
            height: Math.max(4, thumbBox.winH * thumbBox.fit)
            radius: Math.max(2, Theme.radiusWindow * thumbBox.fit)
            color: "transparent"

            ScreencopyView {
                id: shot
                anchors.fill: parent
                captureSource: tile.isWindow ? (tile.toplevel?.wayland ?? null) : null
                live: false
                visible: hasContent
            }
            // Repli : icône de l'app si la capture est impossible
            IconImage {
                anchors.centerIn: parent
                visible: !shot.hasContent
                implicitSize: Math.min(parent.width, parent.height)
                source: tile.isWindow ? Apps.icon(tile.cls) : ""
            }
        }
        IconImage {
            // Badge de l'app en bas à droite, comme macOS
            visible: shot.hasContent
            implicitSize: Math.round(thumbBox.width * 0.42)
            x: thumbBox.width - width - thumbBox.width * 0.02
            y: thumbBox.height - height - thumbBox.height * 0.02
            source: tile.isWindow ? Apps.icon(tile.cls) : ""
            mipmap: true
        }
    }

    // ---- Point d'app ouverte (4 pt, centré 4,5 pt au-dessus du bord bas de la plaque) ----
    Rectangle {
        visible: tile.isApp
        width: 4
        height: 4
        radius: 2
        x: tile.centerX - 2
        y: tile.dock.platterBottom - 4.5 - 2
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.78) : Qt.rgba(0, 0, 0, 0.82)
        opacity: (tile.running || (tile.launchState !== null)) ? tile.presence : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
}
