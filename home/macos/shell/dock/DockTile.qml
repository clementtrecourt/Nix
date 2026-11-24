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
    // Pas entre deux icônes et toile de l'icône (voir les mesures dans Dock.qml)
    readonly property real tsz: dock.tile
    readonly property real canvas: dock.canvas
    // Largeur de base : un pas, ou la fente du séparateur (0,47 pas : entraxe de
    // part et d'autre du séparateur = 1,47 pas, mesuré sur la capture Newsroom)
    readonly property real baseW: isSeparator ? Math.round(tsz * 0.47) : tsz

    // ---- Apparition / disparition (les voisines s'écartent / se resserrent) ----
    property real presence: fresh ? 0 : 1
    Component.onCompleted: {
        if (fresh) presence = 1;
        dock.icons.want(iconKey, themeIcon);
    }
    // Tuile en cours de glisser : invisible (l'icône suit le pointeur) ; sortie du
    // Dock, sa place se referme.
    readonly property bool dragged: dock.dragKey === key
    readonly property bool collapsed: removing || (dragged && dock.dragOut)
    onCollapsedChanged: presence = collapsed ? 0 : 1
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
    // Le Finder est toujours ouvert sur macOS : point permanent
    readonly property bool running: isApp && (windows.length > 0 || dock.model.isFinder(appId))
    readonly property var launchState: isApp ? (dock.model.launching[appId] ?? null) : null
    // Début de la demande d'attention en cours (un seul rebond), 0 sinon
    readonly property real attentionStart: isApp && cls !== "" ? (dock.model.attention[cls] ?? 0) : 0
    readonly property var toplevel: isWindow ? dock.model.toplevelByAddress(address) : null
    property bool pressed: false
    // Téléchargements affiché « en pile » (Display as: Stack) et non vide
    readonly property bool showStack: kind === "folder" && dock.stackDisplay === "stack" && dock.downloads.count > 0
    // Trois premiers éléments (ordre de tri), dessinés de l'arrière vers l'avant
    readonly property var stackItems: showStack ? dock.downloads.sorted.slice(0, 3).reverse() : []

    // Nom affiché dans la bulle (libellés de macOS en anglais US)
    readonly property string label: {
        if (isWindow) return toplevel?.title || dock.model.displayName("", cls);
        if (kind === "folder") return "Downloads";
        if (kind === "trash") return "Trash";
        if (appId === dock.model.appsTileId) return "Apps";
        return dock.model.displayName(appId, cls);
    }
    // ---- Icône : surcharge utilisateur > PNG du thème > thème (voir DockIcons) ----
    // Clé de surcharge : id .desktop sans extension, sinon classe en minuscules.
    readonly property string iconKey: {
        if (kind === "folder") return "downloads";
        if (kind === "trash") return dock.trashFull ? "user-trash-full" : "user-trash";
        // Fenêtre minimisée : icône de son app (badge de la miniature)
        if (!isApp && !isWindow) return "";
        if (appId === dock.model.appsTileId) return "apps";
        const e = Apps.entryFor(appId || cls);
        return e ? e.id : (cls || appId).toLowerCase();
    }
    // Nom d'icône dans le thème
    // « @ » : chercher d'abord dans MacTahoe clair (voir DockIcons)
    readonly property string themeIcon: {
        if (kind === "folder") return "@folder-download";
        if (kind === "trash") return "@" + iconKey;
        if (appId === dock.model.appsTileId) return "macos-apps";
        const e = Apps.entryFor(appId || cls);
        // Sans entrée .desktop : l'id tel quel (les noms d'icônes sont sensibles à la casse)
        if (e && e.icon) return e.icon;
        return isWindow ? (cls || iconKey) : (appId || cls || iconKey);
    }
    onIconKeyChanged: dock.icons.want(iconKey, themeIcon)
    onThemeIconChanged: dock.icons.want(iconKey, themeIcon)
    readonly property var iconInfo: iconKey ? (dock.icons.resolved[iconKey] ?? null) : null
    readonly property string iconSource: {
        if (iconInfo && iconInfo.path) return iconInfo.path;
        if (kind === "folder") return Quickshell.iconPath("folder-download", "folder");
        if (kind === "trash") return Quickshell.iconPath(iconKey, "user-trash");
        if (appId === dock.model.appsTileId)
            return Quickshell.iconPath("macos-apps", true) || Quickshell.iconPath("view-app-grid", "application-x-executable");
        return Apps.icon(isWindow ? cls : (appId || cls));
    }
    // Échelle d'affichage dans la toile : 1 pour une toile Apple (squircle 824/1024),
    // sinon ramène le squircle MacTahoe (87,5 %) aux 80,5 % de Tahoe.
    readonly property real iconScale: (iconInfo && iconInfo.apple) ? 1 : dock.themeIconScale
    // Icône absente du thème (forme libre, non conforme à la grille Apple) : Tahoe
    // la réduit et la pose sur un squircle gris (« boîte »).
    readonly property bool boxed: isApp && appId !== dock.model.appsTileId && !!iconInfo && !!iconInfo.foreign

    // ---- Rebond (lancement / demande d'attention), piloté par l'horloge du Dock ----
    // Lancement : paraboles de 0,7 s, hauteur ≈ 0,5 tuile ; on termine le saut en cours
    // quand la fenêtre apparaît. Attention : un seul saut, plus haut (demande informative).
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
            return canvas * 0.5 * 4 * f * (1 - f);
        }
        if (attentionStart > 0) {
            const flight = 640, el = now - attentionStart;
            if (el < 0 || el > flight) return 0;
            const f = el / flight;
            return canvas * 0.9 * 4 * f * (1 - f);
        }
        return 0;
    }

    // Toile agrandie, posée sur la ligne de base du Dock
    readonly property real vSize: canvas * ps
    readonly property real vBottom: dock.baseY
    readonly property real vTop: vBottom - vSize - bounce
    readonly property real centerX: width / 2

    // ---- Séparateur : trait d'un pixel, 74 % de la hauteur de la plaque, centré
    // sur elle ; blanc à ~30 % en sombre, sombre à ~30 % en clair (relevés Ars
    // Technica sombre / Newsroom clair) ----
    Rectangle {
        visible: tile.isSeparator
        width: 1
        height: Math.round(tile.dock.platterH * 0.74)
        x: Math.round(tile.width / 2 - 0.5)
        y: Math.round(tile.dock.platterTop + (tile.dock.platterH - height) / 2)
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(0, 0, 0, 0.30)
        opacity: tile.presence
    }

    // ---- Icône ----
    Item {
        id: iconBox
        visible: !tile.isSeparator && !tile.isWindow && !tile.dragged
        width: tile.vSize
        height: tile.vSize
        x: tile.centerX - width / 2
        y: tile.vTop
        opacity: Math.min(1, tile.presence * 1.4)
        scale: 0.6 + 0.4 * tile.presence
        transformOrigin: Item.Bottom

        // Image telle quelle (l'ombre fait partie de l'icône Apple) : aucun masque,
        // fond ni ombre ajoutés. Rastérisée une fois à la taille maximale agrandie
        // (sourceSize fixe), puis réduite par mipmap : nette et sans re-rastérisation
        // pendant l'agrandissement.
        // Squircle gris des icônes « en boîte » (toile Apple : squircle à 80,5 %)
        Rectangle {
            id: box
            visible: tile.boxed
            anchors.centerIn: parent
            width: tile.vSize * 0.805
            height: width
            // Coin continu Apple ≈ 22,4 % du côté (approché par un arc)
            radius: width * 0.225
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.dark ? "#4a4a4e" : "#fbfbfd" }
                GradientStop { position: 1; color: Theme.dark ? "#323235" : "#e4e4e8" }
            }
            border.width: 0.5
            border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)
            layer.enabled: tile.pressed
            layer.effect: MultiEffect { brightness: -0.35 }
        }

        // Pile ouverte : la tuile devient un carré de verre avec un chevron
        // (Tahoe, capture 9to5Mac de la pile en grille)
        readonly property bool stackOpen: tile.kind === "folder" && tile.dock.stackOpen
        Rectangle {
            visible: iconBox.stackOpen
            anchors.centerIn: parent
            width: tile.vSize * 0.805
            height: width
            radius: width * 0.225
            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.26)
            border.width: 1
            border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.55)
            Symbol {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                name: "chevron.down"
                size: Math.round(parent.width * 0.5)
                color: Theme.dark ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.72)
            }
        }

        // Au repos (sans agrandissement) : icône rastérisée à sa taille EXACTE en
        // pixels et posée sur des pixels entiers. La réduction par mipmap d'une
        // grande image (ci-dessous, pendant l'agrandissement) donnait des icônes
        // floues sur un écran 1x.
        readonly property real restW: tile.boxed ? tile.canvas * 0.805 * 0.66 : tile.canvas * tile.iconScale
        readonly property bool atRest: Math.abs(tile.vSize - tile.canvas) < 0.5
        readonly property real _dpr: QsWindow.window?.devicePixelRatio ?? 1
        // Origine absolue de iconBox dans la fenêtre : l'icône est posée sur un
        // pixel entier de la FENÊTRE (pas seulement de son parent).
        readonly property real absX: tile.x + x
        readonly property real absY: y
        Image {
            id: iconRest
            visible: !iconBox.stackOpen && iconBox.atRest && status === Image.Ready && !tile.showStack
            width: Math.round(iconBox.restW)
            height: width
            x: Math.round(iconBox.absX + (iconBox.width - width) / 2) - iconBox.absX
            y: Math.round(iconBox.absY + (iconBox.height - height) / 2) - iconBox.absY
            source: tile.iconSource
            sourceSize: Qt.size(Math.round(width * iconBox._dpr), Math.round(width * iconBox._dpr))
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: false
            // macOS assombrit l'icône pendant l'appui (même rastérisation : reste nette)
            layer.enabled: tile.pressed
            layer.effect: MultiEffect { brightness: -0.35 }
        }

        // « Display as: Stack » (réglage par défaut de Tahoe) : l'icône est la pile
        // des derniers éléments, le plus récent devant, les suivants dépassant
        // au-dessus (capture Ars Technica de Tahoe, Dock sombre). Aperçus du cache
        // de miniatures, sinon icône du type ; boîtes en pixels entiers.
        Item {
            id: stackIcon
            visible: tile.showStack && !iconBox.stackOpen
            anchors.fill: parent
            layer.enabled: tile.pressed
            layer.effect: MultiEffect { brightness: -0.35 }
            Repeater {
                model: tile.stackItems
                Item {
                    id: layerItem
                    required property var modelData
                    required property int index
                    // Rang depuis l'avant (0 = le plus récent)
                    readonly property int rank: tile.stackItems.length - 1 - index
                    readonly property int boxH: Math.round(tile.vSize * 0.84) - rank * Math.round(tile.vSize * 0.03)
                    readonly property int boxW: Math.round(tile.vSize * 0.84 * (1 - 0.06 * rank))
                    width: boxW
                    height: boxH
                    x: Math.round(iconBox.absX + (iconBox.width - width) / 2) - iconBox.absX
                    // Bas du premier plan à ~8 % du bas de la toile ; les autres remontent
                    y: Math.round(iconBox.absY + tile.vSize * 0.92) - iconBox.absY - rank * Math.max(2, Math.round(tile.vSize * 0.05)) - boxH
                    readonly property bool img: tile.dock.downloads.isImage(modelData.name)
                    readonly property var sources: {
                        const d = tile.dock.downloads;
                        const l = [];
                        const th = modelData.isDir ? "" : d.thumbFor(modelData.path, false);
                        if (th) l.push(th);
                        if (img) l.push("file://" + modelData.path);
                        l.push(d.iconFor(modelData.name, modelData.isDir));
                        return l;
                    }
                    property int attempt: 0
                    onSourcesChanged: attempt = 0
                    Image {
                        id: prev
                        anchors.fill: parent
                        source: layerItem.sources[Math.min(layerItem.attempt, layerItem.sources.length - 1)]
                        sourceSize: Qt.size(Math.round(width * iconBox._dpr), Math.round(height * iconBox._dpr))
                        fillMode: Image.PreserveAspectFit
                        verticalAlignment: Image.AlignBottom
                        asynchronous: true
                        smooth: true
                        onStatusChanged: if (status === Image.Error && layerItem.attempt < layerItem.sources.length - 1) layerItem.attempt++
                    }
                }
            }
        }

        Image {
            id: icon
            visible: !iconBox.stackOpen && !iconRest.visible && !tile.showStack
            anchors.centerIn: parent
            width: tile.boxed ? box.width * 0.66 : tile.vSize * tile.iconScale
            height: width
            source: tile.iconSource
            sourceSize: Qt.size(tile.dock.iconPixels, tile.dock.iconPixels)
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            smooth: true
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
        opacity: tile.dock.model.landing[tile.address] ? 0 : Math.min(1, tile.presence * 1.4)

        readonly property real winW: tile.toplevel?.lastIpcObject?.size?.[0] ?? 16
        readonly property real winH: tile.toplevel?.lastIpcObject?.size?.[1] ?? 10
        readonly property real fit: Math.min(width * 0.9 / Math.max(1, winW), height * 0.9 / Math.max(1, winH))

        // Au repos : miniature et badge sur des pixels entiers de la fenêtre
        readonly property real absX: tile.x + x
        ClippingRectangle {
            id: thumbClip
            width: Math.max(4, Math.round(thumbBox.winW * thumbBox.fit))
            height: Math.max(4, Math.round(thumbBox.winH * thumbBox.fit))
            x: Math.round(thumbBox.absX + (thumbBox.width - width) / 2) - thumbBox.absX
            y: Math.round(thumbBox.y + (thumbBox.height - height) / 2) - thumbBox.y
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
            Image {
                anchors.centerIn: parent
                visible: !shot.hasContent
                width: Math.min(parent.width, parent.height) * tile.iconScale
                height: width
                source: tile.isWindow ? tile.iconSource : ""
                sourceSize: Qt.size(tile.dock.iconPixels, tile.dock.iconPixels)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
        }
        Image {
            // Badge de l'app en bas à droite, comme macOS (même icône que sa tuile)
            visible: shot.hasContent
            width: Math.round(thumbBox.width * 0.42)
            height: width
            x: Math.round(thumbBox.absX + thumbBox.width - width - thumbBox.width * 0.02) - thumbBox.absX
            y: Math.round(thumbBox.y + thumbBox.height - height - thumbBox.height * 0.02) - thumbBox.y
            source: tile.isWindow ? tile.iconSource : ""
            // Rastérisé à sa taille exacte (net en 1x, y compris pendant l'agrandissement)
            sourceSize: Qt.size(Math.round(width * iconBox._dpr), Math.round(width * iconBox._dpr))
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: false
        }
    }

    // ---- Point d'app ouverte (4 pt, centré 4 pt au-dessus du bord bas de la
    // plaque, sur des pixels entiers ; relevés : noir ~95 % en clair — Newsroom
    // #011435, MacStories #000228 —, blanc ~55 % en sombre — Ars #969FA8 sur
    // #192229) ----
    Rectangle {
        visible: tile.isApp
        width: 4
        height: 4
        radius: 2
        x: Math.round(tile.x + tile.centerX - 2) - tile.x
        y: Math.round(tile.dock.platterBottom) - 6
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.95)
        opacity: (tile.running || (tile.launchState !== null)) ? tile.presence : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
}
