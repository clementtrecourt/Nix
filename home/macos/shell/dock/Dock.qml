import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common
import qs.services

// Dock macOS Tahoe : plaque Liquid Glass flottante en bas de l'écran focalisé,
// agrandissement au survol, rebond au lancement, bulles de nom, menu contextuel,
// fenêtres minimisées (effet génie), Téléchargements et Corbeille.
//
// Proportions mesurées au pixel sur les captures officielles Tahoe (Newsroom
// « Apple Music » à ≈ 1 px/pt et support.apple.com « Use the Dock ») :
//   squircle visible 46 px, pas 60 px  -> squircle / pas = 0,77 (0,75 sur l'autre)
//   toile C (1024 px, squircle 824 px = 0,805 C) -> pas = 1,06 C (≈ 3 pt entre toiles)
//   plaque : bord à 0,195 C de la toile en haut, en bas et aux extrémités
//            (hauteur = 1,39 C ; 79 px pour C = 57), rayon = 0,33 × hauteur,
//            4 pt au-dessus du bord de l'écran
//   séparateur : fente de 0,42 pas, trait 1 pt, 0,95 pas de haut
//   point d'app ouverte : 4 pt, centre à 4,5 pt du bas de la plaque.
//
// IPC : quickshell -c macos ipc call dock minimize      (Cmd+M : minimise la fenêtre active)
//       quickshell -c macos ipc call dock toggleAutohide
Scope {
    id: root

    // ---- Réglages (settings.json, clés "dock.*") ----
    property int tileSize: 48          // « Taille » des Réglages Dock (pt) = toile de l'icône
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
                const g = (k, d) => (o["dock." + k] !== undefined ? o["dock." + k] : (o.dock?.[k] !== undefined ? o.dock[k] : d));
                root.tileSize = g("tileSize", root.tileSize);
                root.magnification = g("magnification", root.magnification);
                root.largeSize = g("largeSize", Math.round(root.tileSize * 1.6));
                root.autohide = g("autohide", root.autohide);
                dockModel.showRecents = g("showRecents", dockModel.showRecents);
                root.minimizeGenie = g("minimizeEffect", "genie") === "genie";
                const p = g("pinned", null);
                if (Array.isArray(p)) dockModel.setBasePinned(p);
            } catch (e) {}
        }
    }

    DockModel {
        id: dockModel
        onWindowMinimized: (t) => genie.animateMinimized(t)
    }
    DockIcons { id: iconResolver; maxPixels: dockArea.iconPixels }

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
                    w += dockModel.items.get(i).kind === "separator" ? 0.42 : 1;
                const avail = win.width - 24;
                const need = w * root.tileSize * 1.06 + 2 * root.tileSize * 0.165;
                return need > avail ? avail / need : 1;
            }
            // Toile de l'icône (pt) et pas entre deux icônes
            readonly property real canvas: Math.floor(root.tileSize * fitScale)
            readonly property real tile: canvas * 1.06
            readonly property int padV: Math.round(canvas * 0.195)
            // Du bord de la plaque au bord de la première fente (la toile y est centrée)
            readonly property real padH: padV - (tile - canvas) / 2
            readonly property int platterH: canvas + 2 * padV
            readonly property int platterRadius: Math.round(platterH * 0.33)
            readonly property int bottomGap: 4
            readonly property real maxScale: root.magnification ? Math.max(1, root.largeSize / root.tileSize) : 1
            // Rastérisation des icônes : une seule fois, à la taille maximale affichée
            // (agrandissement inclus) × densité de l'écran ; jamais pendant l'animation.
            readonly property real dpr: win.devicePixelRatio > 0 ? win.devicePixelRatio : 1
            readonly property int iconPixels: Math.ceil(root.tileSize * maxScale * dpr)
            // Les SVG MacTahoe dessinent le squircle sur 14,82/16,93 = 87,5 % de la toile,
            // les icônes Apple sur 824/1024 = 80,5 % : on ramène le squircle visible à la
            // taille Tahoe. Les icônes Apple déposées en surcharge sont affichées à 100 %.
            readonly property real themeIconScale: 0.805 / 0.875
            readonly property alias icons: iconResolver
            // Hauteur de la surface : icônes agrandies + bulle + rebond d'attention
            readonly property int restH: Math.ceil(bottomGap + padV + canvas * Math.max(maxScale, 1.9) + 52)
            // Pendant un glisser-déposer, la surface couvre tout l'écran pour que
            // l'icône puisse suivre le pointeur hors du Dock.
            readonly property int windowH: (dragKey !== "" || poof.running) ? (win.screen?.height ?? restH) : restH

            // Masquage automatique : décalage vertical de tout le Dock
            property bool revealed: !root.autohide || hovering || menu.open || stack.open || dockModel.bouncing
            property real hideOffset: revealed ? 0 : platterH + bottomGap + 12
            Behavior on hideOffset {
                NumberAnimation { duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmphasized }
            }

            readonly property real platterBottom: height - bottomGap + hideOffset
            readonly property real platterTop: platterBottom - platterH
            // Ligne de base des tuiles (bas de la tuile non agrandie)
            readonly property real baseY: platterBottom - padV

            // ---- Survol / agrandissement ----
            property bool hovering: mouse.containsMouse
            property real mouseX: 0
            property real hoverAmount: (hovering && !menu.open && !stack.open && !dragOut) ? 1 : 0
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
                magnifiedTop = baseY - canvas * maxS;
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
                visible: false
                x: dockArea.dragKey !== "" ? 0 : dockArea.revealed ? dockArea.platterX : 0
                width: dockArea.dragKey !== "" ? dockArea.width : dockArea.revealed ? dockArea.platterW : dockArea.width
                y: dockArea.dragKey !== "" ? 0 : dockArea.revealed ? Math.min(dockArea.platterTop, dockArea.hovering ? dockArea.magnifiedTop : dockArea.platterTop) : dockArea.height - 2
                height: dockArea.dragKey !== "" ? dockArea.height : dockArea.revealed ? dockArea.height - y : 2
            }

            property int pressedIndex: -1

            // ---- Glisser-déposer (réordonner / retirer du Dock) ----
            property string dragKey: ""
            property real dragX: 0
            property real dragY: 0
            property real dragSize: canvas
            property real dragScale: 1
            property string dragIcon: ""
            // Assez loin au-dessus de la plaque : « Supprimer » (comme macOS)
            readonly property bool dragOut: dragKey !== "" && dragY < platterTop - tile * 1.2
            property var pressTile: null
            property real pressX: 0
            property real pressY: 0
            property bool suppressClick: false

            function startDrag(t) {
                if (!t || t.kind !== "app") return;
                dragSize = t.vSize;
                dragScale = t.iconScale;
                dragIcon = t.iconSource;
                dockModel.frozen = true;
                dragKey = t.key;
                pressedIndex = -1;
            }
            function dragMove(x, y) {
                dragX = x;
                dragY = y;
                mouseX = x;
                if (dragOut) return;
                // Réordonne quand le pointeur dépasse le centre d'une voisine (apps seulement)
                const from = indexOfKey(dragKey);
                if (from < 0) return;
                let to = from;
                for (let i = 0; i < rep.count; i++) {
                    const t = rep.itemAt(i);
                    if (!t || i === from || t.kind !== "app" || t.removing) continue;
                    const c = t.x + t.width / 2;
                    if (i < from && x < c && i < to) to = i;
                    if (i > from && x > c && i > to) to = i;
                }
                if (to !== from) {
                    dockModel.items.move(from, to, 1);
                    requestLayout();
                }
            }
            function endDrag() {
                const key = dragKey;
                if (key === "") return;
                const t = tileForKey(key);
                const out = dragOut;
                if (t) {
                    if (out) {
                        if (t.appId && dockModel.isPinned(t.appId)) {
                            poof.at(dragX, dragY);
                            dockModel.setPinned(t.appId, false);
                        }
                    } else {
                        dockModel.commitOrder(key);
                    }
                }
                dragKey = "";
                dockModel.frozen = false;
                dockModel.scheduleSync();
            }
            function indexOfKey(key) {
                for (let i = 0; i < rep.count; i++) {
                    const t = rep.itemAt(i);
                    if (t && t.key === key && !t.removing) return i;
                }
                return -1;
            }

            function tileAt(i) { return i >= 0 ? rep.itemAt(i) : null; }
            function tileForKey(key) {
                const i = indexOfKey(key);
                return i >= 0 ? rep.itemAt(i) : null;
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                pressAndHoldInterval: 600
                onPositionChanged: (m) => {
                    if (dockArea.dragKey !== "") { dockArea.dragMove(m.x, m.y); return; }
                    dockArea.mouseX = m.x;
                    if (pressed && dockArea.pressTile && (Math.abs(m.x - dockArea.pressX) > 6 || Math.abs(m.y - dockArea.pressY) > 6)) {
                        const t = dockArea.pressTile;
                        dockArea.pressTile = null;
                        dockArea.suppressClick = true;
                        // La surface grandit vers le haut : on corrige l'ordonnée.
                        const grow = (win.screen?.height ?? dockArea.height) - dockArea.height;
                        dockArea.startDrag(t);
                        dockArea.dragMove(m.x, m.y + grow);
                    }
                }
                onEntered: dockArea.mouseX = mouseX
                onPressed: (m) => {
                    dockArea.suppressClick = false;
                    if (m.button !== Qt.LeftButton) return;
                    dockArea.pressedIndex = dockArea.hoveredIndex;
                    const t = dockArea.tileAt(dockArea.hoveredIndex);
                    dockArea.pressTile = (t && t.kind === "app") ? t : null;
                    dockArea.pressX = m.x;
                    dockArea.pressY = m.y;
                }
                onReleased: {
                    dockArea.pressedIndex = -1;
                    dockArea.pressTile = null;
                    if (dockArea.dragKey !== "") dockArea.endDrag();
                }
                onCanceled: {
                    dockArea.pressedIndex = -1;
                    dockArea.pressTile = null;
                    if (dockArea.dragKey !== "") dockArea.endDrag();
                }
                onClicked: (m) => {
                    if (dockArea.suppressClick) return;
                    const t = dockArea.tileAt(dockArea.hoveredIndex);
                    if (!t || t.isSeparator) return;
                    if (m.button === Qt.RightButton) menu.openFor(t);
                    else dockArea.activateTile(t);
                }
                onPressAndHold: (m) => {
                    // Appui long = menu contextuel, comme macOS
                    if (dockArea.dragKey !== "") return;
                    const t = dockArea.tileAt(dockArea.hoveredIndex);
                    dockArea.pressedIndex = -1;
                    dockArea.pressTile = null;
                    dockArea.suppressClick = true;
                    if (t && !t.isSeparator) menu.openFor(t);
                }
            }

            // Icône qui suit le pointeur pendant le glisser
            Item {
                visible: dockArea.dragKey !== ""
                width: dockArea.dragSize
                height: dockArea.dragSize
                x: dockArea.dragX - width / 2
                y: dockArea.dragY - height / 2
                z: 10
                Image {
                    anchors.centerIn: parent
                    width: parent.width * dockArea.dragScale
                    height: width
                    source: dockArea.dragIcon
                    sourceSize: Qt.size(dockArea.iconPixels, dockArea.iconPixels)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }
            }
            DockLabel {
                // « Supprimer » au-dessus de l'icône sortie du Dock
                z: 10
                shown: dockArea.dragOut && dockModel.isPinned(dockArea.tileForKey(dockArea.dragKey)?.appId ?? "")
                text: "Supprimer"
                tipX: dockArea.dragX
                tipY: dockArea.dragY - dockArea.dragSize / 2 - 6
            }
            Poof { id: poof; z: 11 }

            function activateTile(t) {
                switch (t.kind) {
                case "app":
                    dockModel.activate(t.appId, t.cls);
                    break;
                case "window":
                    if (t.toplevel) genie.restore(t.toplevel, t);
                    break;
                case "folder":
                    stack.toggleFor(t);
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
                shown: dockArea.hovering && !menu.open && t !== null && !t.isSeparator && dockArea.pressedIndex < 0 && dockArea.dragKey === ""
                text: t ? t.label : ""
                tipX: t ? t.x + t.width / 2 : 0
                tipY: t ? Math.min(dockArea.platterTop, t.vTop) - 10 : 0
            }
        }

        // ---- Pile Téléchargements ----
        DownloadsStack {
            id: stack
            dockWindow: win
            dock: dockArea
            folder: dockModel.downloadsDir
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

    // Raccourcis globaux (liés par Hyprland : "global, macos:<nom>")
    //   minimize      : Cmd+M      (minimise la fenêtre active dans le Dock)
    //   dock-autohide : Cmd+Opt+D  (active / désactive le masquage automatique)
    GlobalShortcut {
        appid: "macos"
        name: "minimize"
        description: "Minimiser la fenêtre active dans le Dock"
        onPressed: genie.minimizeActive()
    }
    GlobalShortcut {
        appid: "macos"
        name: "dock-autohide"
        description: "Masquer / afficher automatiquement le Dock"
        onPressed: root.autohide = !root.autohide
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
        function menuFor(i: int): void { const t = dockArea.tileAt(i); if (t) menu.debugOpen(t); }
        function closeMenu(): void { menu.close(); stack.close(); }
        function pinned(list: string): void { dockModel.pinned = list === "none" ? [] : list.split("|"); }
        function resetPinned(): void { dockModel.userPinned = false; dockModel.applyDefaults(); dockModel.saveState(false); }
        function dark(on: bool): void { Theme.dark = on; }
        function stackFor(i: int, dir: string): void { const t = dockArea.tileAt(i); if (t) { if (dir) stack.folder = dir; stack.grab = false; stack.toggleFor(t); } }
        function stackInfo(): string { return stack.debugInfo(); }
        function menuHover(row: int): void { menu.debugHover(row); }
        function menuTrigger(row: int): void { menu.debugTrigger(row); }
        function launch(id: string): void { dockModel.launch(id); }
        function bounce(id: string): void { dockModel.markLaunching(id); }
        function stopBounce(id: string): void { dockModel.endLaunching(id); }
        function press(i: int): void { dockArea.pressedIndex = i; }
        function release(): void { dockArea.pressedIndex = -1; }
        function dragStart(i: int): void { dockArea.startDrag(dockArea.tileAt(i)); }
        function dragTo(x: real, y: real): void { dockArea.dragMove(x, y - ((win.screen?.height ?? dockArea.height) - dockArea.height)); }
        function dragEnd(): void { dockArea.endDrag(); }
        function genieAt(p: real): void { genie.debugAt(p); }
        function genieDuration(ms: int): void { genie.duration = ms; }
        function minimizeHold(p: real): void { genie.debugHold = p; genie.minimizeActive(); }
        function restoreHold(i: int, p: real): void { const t = dockArea.tileAt(i); if (t?.toplevel) { genie.debugHold = p; genie.restore(t.toplevel, t); } }
        function genieEnd(): void { genie.debugEnd(); }
        function genieState(): string { return genie.debugState(); }
        function restore(i: int): void { const t = dockArea.tileAt(i); if (t?.toplevel) genie.restore(t.toplevel, t); }
        function bounceOf(i: int): real { const t = dockArea.tileAt(i); return t ? t.bounce : -1; }
        function clock(): string { return (Date.now() - dockArea.now) + " bouncing=" + dockModel.bouncing + " " + JSON.stringify(dockModel.launching); }
        function dump(): string {
            let s = "";
            for (let i = 0; i < dockModel.items.count; i++) {
                const e = dockModel.items.get(i);
                const t = dockArea.tileAt(i);
                s += i + " " + e.key + " cls=" + e.cls + " x=" + (t ? Math.round(t.x) : -1) + " w=" + (t ? Math.round(t.width) : -1) + "\n";
            }
            s += "tile " + dockArea.tile + " size " + root.tileSize + " hover " + dockArea.hoverAmount + " screen " + win.screen?.name + " " + win.width + "\n";
            return s + "platter " + Math.round(dockArea.platterX) + " " + Math.round(dockArea.platterW) + " top " + dockArea.platterTop;
        }
    }
}
