import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.services
import qs.session
import "layout.js" as Layout
import "decor.js" as Decor

// Mission Control sur un écran : surface plein écran (calque Overlay) qui
// recouvre le bureau réel. Les fenêtres partent de leur position exacte à
// l'écran (progress = 0, le fond d'écran est encore transparent : on voit le
// vrai bureau) et glissent vers une grille sans chevauchement (progress = 1).
// La sortie rejoue l'animation à l'envers puis rend la main au vrai bureau.
PanelWindow {
    id: win

    required property var modelData           // ShellScreen
    screen: modelData
    readonly property var monitor: Hyprland.monitorFor(modelData)

    // Mode demandé : "mc" (Mission Control), "app" (App Exposé), "" (fermé)
    property string mode: ""
    // Mode affiché (conservé pendant l'animation de sortie)
    property string shownMode: ""
    readonly property bool isOpen: mode !== ""
    property real progress: 0
    property real speed: 1                    // > 1 : ralenti (débogage)
    property bool closing: false
    property var frozen: []                   // fenêtres figées pendant la sortie
    property var frozenMin: []                // idem pour la rangée des fenêtres réduites
    property var raised: null                 // fenêtre choisie : au-dessus pendant la sortie
    property int forceHover: -1               // débogage : survol forcé
    property bool forceExpanded: false        // débogage : barre dépliée
    property int forceHoverSpace: -1          // débogage : bureau survolé

    // Surface montrée une fois les positions rafraîchies (évite un flash de
    // fenêtres à d'anciennes positions)
    property bool started: false
    visible: started
    color: "transparent"
    // Calque Top, comme le Dock et la barre des menus. Dans un même calque,
    // Hyprland empile les surfaces dans l'ordre où elles sont mappées : Mission
    // Control (mappé à l'ouverture) recouvre donc la barre des menus (masquée,
    // comme sur macOS)... mais aussi le Dock (« layerrule = order » ne règle que
    // la réservation d'espace, pas l'empilement). Garder le Dock visible demande
    // de le placer dans le calque Overlay (hors de ce composant).
    // "macos-lg-*" : pas de flou Hyprland (surface opaque une fois ouverte ;
    // pendant l'animation, le vrai bureau doit rester net sous les vignettes).
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "macos-lg-missioncontrol"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    // ---- Fenêtres affichées ----
    readonly property int wsId: monitor?.activeWorkspace?.id ?? 1
    // App Exposé : classe de l'app montrée, figée à l'ouverture. Dès que la
    // surface prend le clavier, Hyprland n'a plus de fenêtre active : on retient
    // donc la dernière classe active connue (ou celle demandée par le Dock).
    property string appClass: ""
    property string lastActiveClass: ""
    readonly property string activeClassNow: Windows.activeClass
    onActiveClassNowChanged: if (activeClassNow !== "") lastActiveClass = activeClassNow
    Component.onCompleted: lastActiveClass = Windows.activeClass
    function latchAppClass() {
        // Repli : juste après le lancement du shell, Hyprland.activeToplevel
        // n'est connu qu'au premier changement de focus -> historique de focus
        const recent = Windows.toplevels.find(t => t.lastIpcObject?.focusHistoryID === 0);
        appClass = ShellState.exposeClass || Windows.activeClass || lastActiveClass || Windows.classOf(recent);
        ShellState.exposeClass = "";
    }
    readonly property var liveWins: {
        const ws = win.wsId;
        const app = win.shownMode === "app";
        const list = Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === ws
            && t.lastIpcObject?.at !== undefined
            && (!app || Windows.classOf(t).toLowerCase() === win.appClass.toLowerCase()));
        // Ordre d'empilement réel d'Hyprland : la fenêtre du dessus en dernier
        return Stacking.sort(list);
    }
    readonly property var wins: closing ? frozen : liveWins

    // App Exposé : fenêtres réduites de l'app (special:minimized), rangée à part
    // en bas de l'écran sous un filet, comme sur macOS
    readonly property var liveMinWins: {
        if (win.shownMode !== "app") return [];
        const cls = win.appClass.toLowerCase();
        return Hyprland.toplevels.values.filter(t => Windows.isMinimized(t)
            && t.lastIpcObject?.at !== undefined && Windows.classOf(t).toLowerCase() === cls);
    }
    readonly property var minWins: closing ? frozenMin : liveMinWins
    readonly property real minStripH: minWins.length > 0 ? 150 : 0
    // Haut de la rangée des fenêtres réduites
    readonly property real minStripY: height - dockReserve - 26 - minStripH

    // Géométrie visible d'une fenêtre : la barre de titre hyprbars est dessinée
    // au-dessus de la zone client (`at`/`size` ne la comptent pas)
    function geomOf(t) {
        const o = t.lastIpcObject ?? {};
        const bar = Decor.hasBar(o.class ?? "", (o.fullscreen ?? 0) > 0) ? Decor.barHeight : 0;
        return {
            x: (o.at?.[0] ?? 0) - (monitor?.x ?? 0),
            y: (o.at?.[1] ?? 0) - (monitor?.y ?? 0) - bar,
            w: Math.max(1, o.size?.[0] ?? 1),
            h: Math.max(1, (o.size?.[1] ?? 1) + bar)
        };
    }

    // Zone de la grille : sous la barre des Spaces repliée, au-dessus du Dock,
    // avec une marge latérale (les fenêtres ne touchent jamais les bords).
    readonly property real dockReserve: 84
    readonly property rect area: shownMode === "app"
        ? Qt.rect(40, 56, width - 80, height - 56 - dockReserve - 24 - (minStripH > 0 ? minStripH + 56 : 0))
        : Qt.rect(48, spaces.collapsedH + 30, width - 96, height - spaces.collapsedH - 30 - dockReserve - 18)
    readonly property var baseRects: Layout.compute(wins.map(geomOf), {
        x: area.x, y: area.y, w: area.width, h: area.height
    }, { gapX: 26, gapY: 46, maxScale: 0.88 })   // toujours un léger "recul", comme macOS
    // Barre des Spaces dépliée (survol, glisser) : comme sur macOS, la même
    // disposition est réduite et descendue sous la barre (aucune fenêtre ne
    // change de place dans la grille).
    readonly property var rects: {
        const r = baseRects;
        if (shownMode !== "mc" || !spaces.expanded || r.length === 0) return r;
        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (const q of r) {
            x0 = Math.min(x0, q.x); y0 = Math.min(y0, q.y);
            x1 = Math.max(x1, q.x + q.w); y1 = Math.max(y1, q.y + q.h);
        }
        const top = spaces.expandedH + 30;
        const bottom = height - dockReserve - 18;
        const k = Math.min(1, (bottom - top) / Math.max(1, y1 - y0));
        const cx = (x0 + x1) / 2;
        const ny0 = Math.max(top, Math.min(y0, bottom - (y1 - y0) * k));
        return r.map(q => ({
            x: cx + (q.x - cx) * k, y: ny0 + (q.y - y0) * k,
            w: q.w * k, h: q.h * k, s: q.s * k
        }));
    }
    readonly property var minRects: Layout.compute(minWins.map(geomOf), {
        x: 80, y: minStripY, w: width - 160, h: minStripH
    }, { gapX: 34, gapY: 20, maxScale: 0.3 })

    // ---- Ouverture / fermeture ----
    onIsOpenChanged: isOpen ? begin() : end()
    // Passage direct Mission Control <-> App Exposé
    onModeChanged: if (mode !== "" && shownMode !== "" && mode !== shownMode) {
        if (mode === "app") latchAppClass();
        shownMode = mode;
    }

    function begin() {
        closing = false;
        raised = null;
        fadeAll.stop();
        content.opacity = 1;
        latchAppClass();
        shownMode = mode;
        // Positions fraîches (lastIpcObject n'est mis à jour que sur demande)
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        Stacking.refresh();
        if (progress > 0) start(1);
        else settleTimer.restart();
    }
    function end() {
        settleTimer.stop();
        if (shownMode === "") return;
        frozen = liveWins;
        frozenMin = liveMinWins;
        closing = true;
        start(0);
    }
    function start(to) {
        if (to === 1) { started = true; content.forceActiveFocus(); }
        anim.stop();
        anim.to = to;
        anim.duration = (to === 1 ? 420 : 380) * speed;
        anim.start();
    }
    Timer {
        id: settleTimer
        interval: 45
        onTriggered: {
            // Les positions viennent d'être rafraîchies : classe encore inconnue ?
            if (win.appClass === "") win.latchAppClass();
            win.start(1);
        }
    }
    NumberAnimation {
        id: anim
        target: win
        property: "progress"
        // Ressort macOS amorti (pas de dépassement visible)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 0.86, 0.26, 1.0, 1, 1]
        onFinished: if (win.progress === 0) win.finish()
    }
    readonly property bool opening: anim.running && anim.to === 1
    // Débogage : animation figée
    function freezeAt(p) {
        settleTimer.stop();
        anim.stop();
        started = true;
        progress = p;
    }
    function finish() {
        started = false;
        shownMode = "";
        closing = false;
        frozen = [];
        frozenMin = [];
        raised = null;
    }

    // Choix d'une fenêtre : focus puis sortie (la fenêtre reste au-dessus)
    // (Hyprland refuse de focaliser une fenêtre tant qu'une surface garde le
    // clavier en exclusif : on rend d'abord le clavier, puis on focalise.)
    function pick(t) {
        raised = t;
        ShellState.close();
        focusLater.target = t;
        focusLater.restart();
    }
    Timer {
        id: focusLater
        property var target: null
        interval: 50
        onTriggered: if (target) {
            // Au premier plan, comme à la fin de l'animation (une fenêtre
            // flottante focalisée n'est pas forcément remontée par Hyprland)
            if (!Windows.isMinimized(target)) Hyprland.dispatch("alterzorder top,address:0x" + target.address);
            Windows.focus(target);
            target = null;
        }
    }
    // Choix d'un autre bureau : fondu puis bascule. On rend d'abord le
    // clavier : en le récupérant, Hyprland refocalise la fenêtre active d'avant
    // Mission Control, ce qui ramènerait sur l'ancien bureau si la bascule
    // avait déjà eu lieu.
    function pickSpace(id) {
        if (id === wsId) { ShellState.close(); return; }
        frozen = liveWins;
        frozenMin = liveMinWins;
        closing = true;
        fadeAll.start();
        ShellState.close();
        goLater.wsId = id;
        goLater.restart();
    }
    Timer {
        id: goLater
        property int wsId: 0
        interval: 60
        onTriggered: Spaces.goTo(wsId)
    }
    NumberAnimation {
        id: fadeAll
        target: content
        property: "opacity"
        to: 0
        duration: 260 * win.speed
        easing.type: Easing.OutCubic
        onFinished: { anim.stop(); win.progress = 0; win.finish(); content.opacity = 1; }
    }

    // Lâcher d'une fenêtre glissée : sur un bureau, ou sur "+" (nouveau bureau)
    function dropOn(t, x, y) {
        if (shownMode !== "mc") return;
        let id = spaces.spaceAt(x, y - spaces.y);
        if (id === -1) id = Spaces.add();
        if (id > 0 && id !== wsId) Spaces.moveWindow(t, id);
    }

    // ---- Contenu ----
    Item {
        id: content
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ShellState.close()
        Keys.onReturnPressed: {
            const i = tiles.hoveredIndex;
            if (i >= 0) win.pick(win.wins[i]);
            else ShellState.close();
        }

        // Fond d'écran (copie du bureau). Au départ (progress = 0) la surface
        // est transparente : on voit le vrai bureau. Le fond d'écran net devient
        // opaque presque aussitôt, en même temps que les vignettes (qui
        // recouvrent alors exactement les vraies fenêtres : pas de « fantôme »
        // des fenêtres réelles pendant l'animation), puis se floute et
        // s'assombrit progressivement, comme sur macOS.
        Item {
            id: backdrop
            anchors.fill: parent
            opacity: Math.min(1, win.progress / 0.06)
            layer.enabled: true
            // Avancement du flou/voile (et des ombres des vignettes)
            readonly property real fx: Math.min(1, win.progress / 0.35)

            // Fond d'écran net (source du flou et des vignettes des Spaces)
            WallpaperView {
                id: wallpaper
                anchors.fill: parent
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                source: wallpaper
                opacity: backdrop.fx
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                blurMultiplier: 0.6
                saturation: 0.05
            }
            // Voile : Mission Control assombrit le fond ; l'Exposé
            // d'application l'assombrit davantage
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: (win.shownMode === "app" ? 0.40 : 0.24) * backdrop.fx
            }
        }

        // Clic dans le vide : retour au bureau
        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.close()
        }

        // Fenêtres
        Item {
            id: tiles
            anchors.fill: parent
            property int hoveredIndex: -1
            property bool anyDragging: false
            property point dragPoint: Qt.point(-1, -1)

            Repeater {
                model: ScriptModel { values: win.wins }

                WindowTile {
                    id: tile
                    required property var modelData
                    required property int index
                    toplevel: modelData
                    readonly property var g: win.geomOf(modelData)
                    readonly property var r: win.rects[index] ?? { x: g.x, y: g.y, w: g.w, h: g.h }
                    realRect: Qt.rect(g.x, g.y, g.w, g.h)
                    targetRect: Qt.rect(r.x, r.y, r.w, r.h)
                    progress: win.progress
                    settle: win.progress === 1
                    active: (modelData.lastIpcObject?.focusHistoryID ?? 1) === 0
                    shadowOpacity: backdrop.fx
                    z: dragging ? 1000 : (win.raised === modelData && win.closing ? 900 : index)
                    onHoveredChanged: if (hovered) tiles.hoveredIndex = index; else if (tiles.hoveredIndex === index) tiles.hoveredIndex = -1
                    Binding on hovered {
                        when: win.forceHover >= 0
                        value: win.forceHover === tile.index
                    }
                    onActivated: win.pick(modelData)
                    onDraggingChanged: tiles.anyDragging = dragging
                    onDragMoved: (x, y) => tiles.dragPoint = Qt.point(x, y)
                    onDropped: (x, y) => { tiles.dragPoint = Qt.point(-1, -1); win.dropOn(modelData, x, y); }
                }
            }

            // App Exposé : filet de séparation au-dessus des fenêtres réduites
            Rectangle {
                visible: win.minWins.length > 0
                x: 60
                width: parent.width - 120
                y: win.minStripY - 28
                height: 1
                color: Qt.rgba(1, 1, 1, 0.22)
                opacity: win.progress
            }

            // App Exposé : fenêtres réduites (elles montent depuis le Dock)
            Repeater {
                model: ScriptModel { values: win.minWins }

                WindowTile {
                    id: minTile
                    required property var modelData
                    required property int index
                    toplevel: modelData
                    readonly property var g: win.geomOf(modelData)
                    readonly property var r: win.minRects[index] ?? { x: 0, y: 0, w: 1, h: 1 }
                    // Départ : même taille, sous le bord bas de l'écran
                    realRect: Qt.rect(r.x, win.height + 20, r.w, r.h)
                    naturalWidth: g.w
                    targetRect: Qt.rect(r.x, r.y, r.w, r.h)
                    progress: win.progress
                    settle: win.progress === 1
                    active: false
                    shadowOpacity: backdrop.fx
                    draggable: false
                    z: win.raised === modelData && win.closing ? 900 : 0
                    onActivated: win.pick(modelData)
                }
            }
        }

        // Barre des Spaces : descend du haut de l'écran
        SpacesBar {
            id: spaces
            width: parent.width
            screenH: win.height
            y: -(1 - win.progress) * (height + 30)
            visible: win.shownMode === "mc"
            backdrop: backdrop
            wallpaper: wallpaper
            monitor: win.monitor
            progress: win.progress
            forceExpanded: win.forceExpanded
            forceHoverSpace: win.forceHoverSpace
            dragActive: tiles.anyDragging
            dragPoint: Qt.point(tiles.dragPoint.x, tiles.dragPoint.y - y)
            onSpaceClicked: id => win.pickSpace(id)
        }
    }
}
