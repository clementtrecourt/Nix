import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.services

// Dock macOS Tahoe : plaque Liquid Glass flottante en bas de l'écran focalisé,
// agrandissement au survol, rebond au lancement, bulles de nom, menu contextuel,
// fenêtres minimisées (effet génie), Téléchargements et Corbeille.
//
// Proportions relevées sur les captures officielles Tahoe (support.apple.com,
// Newsroom) en unités de tuile T (pas entre deux icônes) :
//   plaque = T + 2 × 0,145 T de haut, marges latérales 0,145 T,
//   rayon = 0,32 × hauteur de plaque, 4 pt au-dessus du bord de l'écran,
//   séparateur : fente de 0,46 T, trait 1 pt, 0,95 T de haut,
//   point d'app ouverte : 4 pt, centre à 4,5 pt du bas de la plaque.
//
// IPC : quickshell -c macos ipc call dock minimize      (Cmd+M : minimise la fenêtre active)
//       quickshell -c macos ipc call dock toggleAutohide
Scope {
    id: root

    // ---- Réglages (settings.json, clés "dockArea.*") ----
    property int tileSize: 48          // « Taille » des Réglages Dock (pt)
    property bool magnification: true
    property real largeSize: Math.round(tileSize * 1.6)
    property bool autohide: false
    property bool minimizeGenie: true   // effet génie (sinon : échelle)

    FileView {
        path: Quickshell.shellPath("settings.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const o = JSON.parse(text());
                const g = (k, d) => (o["dockArea." + k] !== undefined ? o["dockArea." + k] : (o.dock?.[k] !== undefined ? o.dock[k] : d));
                root.tileSize = g("tileSize", root.tileSize);
                root.magnification = g("magnification", root.magnification);
                root.largeSize = g("largeSize", Math.round(root.tileSize * 1.6));
                root.autohide = g("autohide", root.autohide);
                dockModel.showRecents = g("showRecents", dockModel.showRecents);
                root.minimizeGenie = g("minimizeEffect", "genie") === "genie";
                const p = g("pinned", null);
                if (Array.isArray(p) && !dockModel.stateLoaded) dockModel.pinned = p;
            } catch (e) {}
        }
    }

    DockModel { id: dockModel }

    // Écran focalisé (macOS : écran principal / celui où se trouve le pointeur)
    readonly property var targetScreen: {
        const name = Hyprland.focusedMonitor?.name ?? "";
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }

    // Corbeille pleine ?
    property bool trashFull: false
    Process {
        id: trashProbe
        command: ["sh", "-c", "[ -n \"$(ls -A \"$1\" 2>/dev/null)\" ]", "sh", dockModel.trashDir]
        onExited: (code) => root.trashFull = (code === 0)
    }
    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: trashProbe.running = true
    }

    PanelWindow {
        id: win
        screen: root.targetScreen
        color: "transparent"

        WlrLayershell.namespace: "macos-dock"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { left: true; right: true; bottom: true }
        implicitHeight: dockArea.windowH
        exclusionMode: root.autohide ? ExclusionMode.Ignore : ExclusionMode.Normal
        exclusiveZone: root.autohide ? 0 : dockArea.platterH + dockArea.bottomGap

        // Seule la plaque (et les icônes agrandies) reçoivent la souris ; masquée :
        // une bande de 2 px en bas de l'écran pour la faire réapparaître.
        mask: Region { item: hitArea }

        Item {
            id: dockArea
            anchors.fill: parent

            readonly property var model: dockModel
            readonly property bool trashFull: root.trashFull

            // ---- Géométrie ----
            // Le Dock rétrécit ses tuiles s'il ne tient plus dans la largeur de l'écran.
            readonly property real fitScale: {
                let w = 0;
                for (let i = 0; i < dockModel.items.count; i++)
                    w += dockModel.items.get(i).kind === "separator" ? 0.46 : 1;
                const avail = win.width - 24;
                const need = w * root.tileSize + 2 * Math.round(root.tileSize * 0.145);
                return need > avail ? avail / need : 1;
            }
            readonly property real tile: Math.floor(root.tileSize * fitScale)
            readonly property int padV: Math.round(tile * 0.145)
            readonly property int padH: Math.round(tile * 0.145)
            readonly property int platterH: tile + 2 * padV
            readonly property int platterRadius: Math.round(platterH * 0.32)
            readonly property int bottomGap: 4
            readonly property real maxScale: root.magnification ? Math.max(1, root.largeSize / root.tileSize) : 1
            // Hauteur de la surface : icônes agrandies + bulle + rebond d'attention
            readonly property int windowH: Math.ceil(bottomGap + padV + tile * Math.max(maxScale, 1.9) + 52)

            // Masquage automatique : décalage vertical de tout le Dock
            property bool revealed: !root.autohide || hovering || menu.open || dockModel.bouncing
            property real hideOffset: revealed ? 0 : platterH + bottomGap + 12
            Behavior on hideOffset {
                NumberAnimation { duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmphasized }
            }

            readonly property real platterBottom: height - bottomGap + hideOffset
            readonly property real platterTop: platterBottom - platterH
            // Ligne de base des tuiles (bas de la tuile non agrandie)
            readonly property real baseY: platterBottom - padV
            // Rapport icône / tuile (voir DockTile)
            readonly property real iconRatio: 0.89

            // ---- Survol / agrandissement ----
            property bool hovering: mouse.containsMouse
            property real mouseX: 0
            property real hoverAmount: (hovering && !menu.open && dragKey === "") ? 1 : 0
            Behavior on hoverAmount {
                NumberAnimation { duration: dockArea.hoverAmount > 0.5 ? 220 : 120; easing.type: Easing.OutCubic }
            }
            onHoverAmountChanged: requestLayout()
            onMouseXChanged: requestLayout()
            onWidthChanged: requestLayout()
            onTileChanged: requestLayout()

            // Horloge des rebonds (ne tourne que pendant un rebond)
            property real now: Date.now()
            FrameAnimation {
                running: dockModel.bouncing
                onTriggered: dockArea.now = Date.now()
            }

            // Géométrie calculée de la plaque
            property real platterX: (width - platterW) / 2
            property real platterW: 2 * padH
            property int hoveredIndex: -1
            property real magnifiedTop: platterTop

            function requestLayout() {
                if (!layoutPending) { layoutPending = true; Qt.callLater(layout); }
            }
            property bool layoutPending: false

            // Agrandissement façon macOS : distance mesurée en coordonnées de repos,
            // profil en cloche (cosinus surélevé) sur ±3 tuiles, la rangée s'étire de
            // part et d'autre du pointeur pour que l'icône survolée reste sous lui.
            function layout() {
                layoutPending = false;
                const n = rep.count;
                const tiles = [];
                let W0 = 0;
                for (let i = 0; i < n; i++) {
                    const it = rep.itemAt(i);
                    if (!it) continue;
                    const w = it.baseW * it.presence;
                    tiles.push({ it: it, w: w });
                    W0 += w;
                }
                const B0 = (width - W0) / 2;
                const h = hoverAmount;
                const M = maxScale;
                const R = tile * 3;
                const t = mouseX - B0;
                let cum = 0, total = 0, magPos = 0, maxS = 1;
                for (const e of tiles) {
                    const c = cum + e.w / 2;
                    const d = Math.abs(c - t);
                    const g = d < R ? (1 + Math.cos(Math.PI * d / R)) / 2 : 0;
                    e.s = 1 + (M - 1) * h * g;
                    e.m = e.w * e.s;
                    if (cum + e.w <= t) magPos += e.m;
                    else if (cum < t) magPos += (t - cum) * e.s;
                    if (!e.it.isSeparator) maxS = Math.max(maxS, e.s);
                    total += e.m;
                    cum += e.w;
                }
                if (t < 0) magPos = t;
                else if (t > W0) magPos = total + (t - W0);
                const L = h > 0 ? mouseX - magPos : B0;
                let x = L, hov = -1;
                for (let i = 0; i < tiles.length; i++) {
                    const e = tiles[i];
                    e.it.px = x;
                    e.it.pw = e.m;
                    e.it.ps = e.s;
                    if (hovering && mouseX >= x && mouseX < x + e.m) hov = e.it.index;
                    x += e.m;
                }
                platterX = L - padH;
                platterW = total + 2 * padH;
                hoveredIndex = hov;
                magnifiedTop = baseY - tile * maxS;
            }

            // ---- Plaque Liquid Glass ----
            DockPlatter {
                id: platter
                x: dockArea.platterX
                y: dockArea.platterTop
                width: dockArea.platterW
                height: dockArea.platterH
                radius: dockArea.platterRadius
            }

            // ---- Tuiles ----
            Item {
                id: tilesLayer
                anchors.fill: parent
                Repeater {
                    id: rep
                    model: dockModel.items
                    onCountChanged: dockArea.requestLayout()
                    delegate: DockTile {
                        dock: dockArea
                        pressed: dockArea.pressedIndex === index
                    }
                }
            }

            // ---- Zone sensible (masque d'entrée de la surface) ----
            Item {
                id: hitArea
                x: dockArea.revealed ? dockArea.platterX : 0
                width: dockArea.revealed ? dockArea.platterW : dockArea.width
                y: dockArea.revealed ? Math.min(dockArea.platterTop, dockArea.hovering ? dockArea.magnifiedTop : dockArea.platterTop) : dockArea.height - 2
                height: dockArea.revealed ? dockArea.height - y : 2
            }

            property int pressedIndex: -1
            property string dragKey: ""

            function tileAt(i) { return i >= 0 ? rep.itemAt(i) : null; }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                pressAndHoldInterval: 600
                onPositionChanged: (m) => dockArea.mouseX = m.x
                onEntered: dockArea.mouseX = mouseX
                onPressed: (m) => {
                    if (m.button === Qt.LeftButton) dockArea.pressedIndex = dockArea.hoveredIndex;
                }
                onReleased: dockArea.pressedIndex = -1
                onCanceled: dockArea.pressedIndex = -1
                onClicked: (m) => {
                    const t = dockArea.tileAt(dockArea.hoveredIndex);
                    if (!t || t.isSeparator) return;
                    if (m.button === Qt.RightButton) menu.openFor(t);
                    else dockArea.activateTile(t);
                }
                onPressAndHold: (m) => {
                    // Appui long = menu contextuel, comme macOS
                    const t = dockArea.tileAt(dockArea.hoveredIndex);
                    dockArea.pressedIndex = -1;
                    if (t && !t.isSeparator) menu.openFor(t);
                }
            }

            function activateTile(t) {
                switch (t.kind) {
                case "app":
                    dockModel.activate(t.appId, t.cls);
                    break;
                case "window":
                    if (t.toplevel) genie.restore(t.toplevel, t);
                    break;
                case "folder":
                    dockModel.openPath(dockModel.downloadsDir);
                    break;
                case "trash":
                    dockModel.openTrash();
                    break;
                }
            }

            // ---- Bulle du nom ----
            DockLabel {
                id: bubble
                readonly property var t: dockArea.tileAt(dockArea.hoveredIndex)
                shown: dockArea.hovering && !menu.open && t !== null && !t.isSeparator && dockArea.pressedIndex < 0
                text: t ? t.label : ""
                tipX: t ? t.x + t.width / 2 : 0
                tipY: t ? Math.min(dockArea.platterTop, t.vTop) - 10 : 0
            }
        }

        // ---- Menu contextuel ----
        DockMenu {
            id: menu
            dockWindow: win
            dock: dockArea
        }
    }

    // ---- Effet génie (minimiser / restaurer) ----
    Genie {
        id: genie
        screen: root.targetScreen
        dock: dockArea
        enabled: root.minimizeGenie
    }

    IpcHandler {
        target: "dock"
        // Minimise la fenêtre active vers le Dock (à lier à Cmd+M)
        function minimize(): void { genie.minimizeActive(); }
        function toggleAutohide(): void { root.autohide = !root.autohide; }
        function setAutohide(on: bool): void { root.autohide = on; }
        function setMagnification(on: bool): void { root.magnification = on; }
        function setShowRecents(on: bool): void { dockModel.showRecents = on; }
    }

    // Débogage (banc de test : pas de clic souris possible dans l'instance imbriquée)
    IpcHandler {
        target: "dock-debug"
        function hover(x: real): void { dockArea.hovering = true; dockArea.mouseX = x; }
        function unhover(): void { dockArea.hovering = Qt.binding(() => mouse.containsMouse); }
        function click(i: int): void { const t = dockArea.tileAt(i); if (t) dockArea.activateTile(t); }
        function menuFor(i: int): void { const t = dockArea.tileAt(i); if (t) menu.openFor(t); }
        function closeMenu(): void { menu.close(); }
        function menuHover(row: int): void { menu.debugHover(row); }
        function menuTrigger(row: int): void { menu.debugTrigger(row); }
        function launch(id: string): void { dockModel.launch(id); }
        function bounce(id: string): void { dockModel.markLaunching(id); }
        function stopBounce(id: string): void { dockModel.endLaunching(id); }
        function press(i: int): void { dockArea.pressedIndex = i; }
        function release(): void { dockArea.pressedIndex = -1; }
        function restore(i: int): void { const t = dockArea.tileAt(i); if (t?.toplevel) genie.restore(t.toplevel, t); }
        function dump(): string {
            let s = "";
            for (let i = 0; i < dockModel.items.count; i++) {
                const e = dockModel.items.get(i);
                const t = dockArea.tileAt(i);
                s += i + " " + e.key + " cls=" + e.cls + " x=" + (t ? Math.round(t.x) : -1) + " w=" + (t ? Math.round(t.width) : -1) + "\n";
            }
            return s + "platter " + Math.round(dockArea.platterX) + " " + Math.round(dockArea.platterW) + " top " + dockArea.platterTop;
        }
    }
}
