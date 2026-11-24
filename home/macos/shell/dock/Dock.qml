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
// Proportions mesurées au pixel sur deux captures Tahoe 26 : Newsroom
// « Apple Music » (3840 px, 2,27 px/pt, Dock par défaut : toile 48 pt) et Ars
// Technica (2560 px, Dock sombre) ; toile C (1024 px, squircle 824 = 0,805 C) :
//   squircle 87-88 px, pas 118 px (Newsroom) ; 78 / 108 (Ars)
//     -> pas = 1,36 squircle = 1,10 C (≈ 5 pt entre toiles pour C = 48)
//   plaque : 152 px (Newsroom), 138 (Ars) = 1,75 squircle = 1,42 C ; bord à
//            0,21 C de la toile en haut, en bas et aux extrémités ; rayon
//            ≈ 0,33 × hauteur (arc ajusté : 53 px / 152) ; 5 pt au-dessus du
//            bord de l'écran
//   séparateur : entraxe de 1,47 pas de part et d'autre (fente de 0,47 pas),
//            trait d'un pixel, 74 % de la hauteur de la plaque
//   point d'app ouverte : 4 pt, centre à ~4 pt du bas de la plaque.
//
// IPC : quickshell -c macos ipc call dock minimize      (Cmd+M : minimise la fenêtre active)
//       quickshell -c macos ipc call dock toggleAutohide
Scope {
    id: root

    // ---- Réglages (settings.json, clés "dock.*") ----
    property int tileSize: 48          // « Taille » des Réglages Dock (pt) = toile de l'icône
    // Tahoe, installation neuve : « Magnification » désactivé (Desktop & Dock)
    property bool magnification: false
    property real largeSize: Math.round(tileSize * 1.6)
    property bool autohide: false
    property bool minimizeGenie: true   // effet génie (sinon : échelle)

    FileView {
        id: settingsFile
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
                if (dockModel.stateLoaded) root.applyPrefs();
            } catch (e) {}
        }
    }

    DockModel {
        id: dockModel
        onWindowMinimized: (t) => genie.animateMinimized(t)
        // Réglages changés à l'exécution (IPC, raccourci) : persistés dans l'état
        // du shell et appliqués par-dessus settings.json
        onStateLoadedChanged: if (stateLoaded) root.applyPrefs()
    }
    function applyPrefs() {
        const p = dockModel.prefs;
        if (p.autohide !== undefined) root.autohide = p.autohide;
        if (p.magnification !== undefined) root.magnification = p.magnification;
        if (p.showRecents !== undefined) dockModel.showRecents = p.showRecents;
    }
    function setAutohide(on) { root.autohide = on; dockModel.setPref("autohide", on); }
    function setMagnification(on) { root.magnification = on; dockModel.setPref("magnification", on); }
    function setShowRecents(on) { dockModel.showRecents = on; dockModel.setPref("showRecents", on); }
    // Réglages « dock.* » de settings.json (lus aussi par System Settings) :
    // fusion dans le fichier existant
    function writeSetting(k, v) {
        let o = {};
        try { o = JSON.parse(settingsFile.text() || "{}"); } catch (e) { o = {}; }
        o["dock." + k] = v;
        settingsFile.setText(JSON.stringify(o, null, 2));
    }
    function setMinimizeEffect(v) { root.minimizeGenie = v === "genie"; writeSetting("minimizeEffect", v); }
    // Taille (glisser vertical sur le séparateur) : appliquée tout de suite,
    // écrite à la fin du glisser
    function setTileSize(v, persist) {
        root.tileSize = v;
        if (persist) writeSetting("tileSize", v);
    }
    // System Settings > Desktop & Dock (IPC « settings » de cette instance)
    function openDockSettings() {
        Quickshell.execDetached(["quickshell", "ipc", "--pid", String(Quickshell.processId), "call", "settings", "open", "desktop-dock"]);
    }
    DockIcons { id: iconResolver; maxPixels: dockArea.iconPixels }

    // Écran focalisé (macOS : écran principal / celui où se trouve le pointeur)
    readonly property var targetScreen: {
        const name = Hyprland.focusedMonitor?.name ?? "";
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }

    // Sur un espace occupé, le Dock ne se révèle qu'au bord de l'écran.
    // Les fenêtres minimisées / masquées vivent sur des espaces spéciaux et
    // ne comptent donc pas dans les fenêtres de l'espace courant.
    readonly property var targetMonitor: Hyprland.monitors.values.find(m => m.name === targetScreen?.name) ?? null
    readonly property bool workspaceOccupied: (targetMonitor?.activeWorkspace?.toplevels.values.length ?? 0) > 0
    // Le réglage explicite permet toujours de masquer aussi sur le bureau vide.
    readonly property bool shouldHide: autohide || workspaceOccupied

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

        // "macos-lg-*" : pas de flou Hyprland, la plaque réfracte elle-même le
        // fond d'écran (seul élément derrière le Dock grâce à sa zone exclusive)
        WlrLayershell.namespace: "macos-lg-dock"
        WlrLayershell.layer: WlrLayer.Top
        property Item glassBackdrop: dockBackdrop
        GlassBackdrop {
            id: dockBackdrop
            mode: "wallpaper"
            screen: win.screen
            want: true
        }

        // Mission Control / App Exposé : la surface de Mission Control est créée
        // avant le Dock (ordre dans shell.qml) et reste mappée : le Dock, mappé
        // après elle sur la même couche, reste naturellement au-dessus.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { left: true; right: true; bottom: true }
        implicitHeight: dockArea.windowH
        exclusionMode: root.shouldHide ? ExclusionMode.Ignore : ExclusionMode.Normal
        exclusiveZone: root.shouldHide ? 0 : dockArea.platterH + dockArea.bottomGap

        // Seule la plaque (et les icônes agrandies) reçoivent la souris ; masquée :
        // une bande de 2 px en bas de l'écran pour la faire réapparaître.
        mask: Region { item: hitArea }

        Item {
            id: dockArea
            anchors.fill: parent

            readonly property var model: dockModel
            readonly property bool trashFull: root.trashFull
            readonly property bool stackOpen: stack.open

            // ---- Téléchargements : contenu et réglages de la pile (menu de la tuile) ----
            //   stackSort    : name | dateAdded (défaut) | dateModified | dateCreated | kind
            //   stackDisplay : stack (défaut, icône = derniers éléments empilés) | folder
            //   stackView    : fan | grid | list | auto (défaut)
            readonly property var downloads: downloadsFolder
            readonly property string stackSort: dockModel.prefs.stackSort ?? "dateAdded"
            readonly property string stackDisplay: dockModel.prefs.stackDisplay ?? "stack"
            readonly property string stackView: dockModel.prefs.stackView ?? "auto"
            DockFolder {
                id: downloadsFolder
                folder: dockModel.downloadsDir
                sortBy: dockArea.stackSort
                watching: dockArea.stackDisplay === "stack" || stack.open
            }

            // ---- Géométrie ----
            // Le Dock rétrécit ses tuiles s'il ne tient plus dans la largeur de l'écran.
            readonly property real fitScale: {
                let w = 0;
                for (let i = 0; i < dockModel.items.count; i++)
                    w += dockModel.items.get(i).kind === "separator" ? 0.47 : 1;
                const avail = win.width - 24;
                const need = w * root.tileSize * 1.10 + 2 * root.tileSize * 0.16;
                return need > avail ? avail / need : 1;
            }
            // Toile de l'icône (pt) et pas entre deux icônes
            readonly property real canvas: Math.floor(root.tileSize * fitScale)
            // Pas ≈ 1,10 toile, arrondi pour que (pas - toile) soit pair : la toile, la
            // plaque et le point tombent alors sur des pixels entiers (écran 1x).
            readonly property real tile: canvas + 2 * Math.round(canvas * 0.05)
            readonly property int padV: Math.round(canvas * 0.21)
            // Du bord de la plaque au bord de la première fente (la toile y est centrée)
            readonly property real padH: padV - (tile - canvas) / 2
            readonly property int platterH: canvas + 2 * padV
            readonly property int platterRadius: Math.round(platterH * 0.33)
            readonly property int bottomGap: 5
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

            // Réglages et actions pour les menus (séparateur)
            readonly property bool autohide: root.autohide
            readonly property bool magnification: root.magnification
            readonly property bool minimizeGenie: root.minimizeGenie
            function setAutohide(on) { root.setAutohide(on); }
            function setMagnification(on) { root.setMagnification(on); }
            function setMinimizeEffect(v) { root.setMinimizeEffect(v); }
            function openDockSettings() { root.openDockSettings(); }

            // Masquage automatique : décalage vertical de tout le Dock. Le pointeur
            // doit rester un instant au bord de l'écran avant que le Dock ne
            // réapparaisse (autohide-delay de macOS : 0,5 s par défaut).
            property bool revealHeld: false
            Timer {
                id: revealTimer
                interval: 500
                onTriggered: dockArea.revealHeld = true
            }
            onHoveringChanged: {
                if (hovering) { if (!revealHeld) revealTimer.restart(); }
                else { revealTimer.stop(); revealHeld = false; }
            }
            property bool revealed: !root.shouldHide || revealHeld || menu.open || stack.open || dragKey !== "" || resizing
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
                // Au repos, la rangée commence sur un pixel entier (icônes nettes en 1x)
                const B0 = Math.round((width - W0) / 2);
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
                // Sans agrandissement, la rangée ne bouge pas : positions entières
                const magnifying = h > 0 && M > 1;
                const L = magnifying ? mouseX - magPos : B0;
                let x = L, hov = -1;
                for (let i = 0; i < tiles.length; i++) {
                    const e = tiles[i];
                    e.it.px = magnifying ? x : Math.round(x);
                    e.it.pw = e.m;
                    e.it.ps = e.s;
                    if (hovering && mouseX >= x && mouseX < x + e.m) hov = e.it.index;
                    x += e.m;
                }
                // Bords de la plaque sur des pixels entiers (liserés nets)
                const pl = magnifying ? L - padH : Math.round(L - padH);
                const pr = magnifying ? L + total + padH : Math.round(L + total + padH);
                platterX = pl;
                platterW = pr - pl;
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
            // (le Finder ne se retire pas du Dock)
            property bool dragFinder: false
            readonly property bool dragOut: dragKey !== "" && !dragFinder && dragY < platterTop - tile * 1.2
            property var pressTile: null
            property real pressX: 0
            property real pressY: 0
            property bool suppressClick: false

            function startDrag(t) {
                if (!t || t.kind !== "app") return;
                dragSize = t.vSize;
                dragScale = t.iconScale;
                dragIcon = t.iconSource;
                dragFinder = dockModel.isFinder(t.appId);
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

            // ---- Séparateur : glisser vertical = taille du Dock (curseur double flèche) ----
            readonly property bool overSeparator: { const t = tileAt(hoveredIndex); return !!t && t.isSeparator; }
            property bool resizing: false
            property real resizeFrom: 0
            property int resizeStart: 48

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                pressAndHoldInterval: 600
                cursorShape: (dockArea.resizing || (dockArea.overSeparator && dockArea.dragKey === "")) ? Qt.SizeVerCursor : Qt.ArrowCursor
                onPositionChanged: (m) => {
                    if (dockArea.resizing) {
                        // Distance au bas de l'écran : stable même si la surface change de hauteur
                        const d = (dockArea.height - m.y) - dockArea.resizeFrom;
                        const v = Math.max(16, Math.min(128, Math.round(dockArea.resizeStart + d)));
                        if (v !== root.tileSize) root.setTileSize(v, false);
                        return;
                    }
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
                    if (dockArea.overSeparator) {
                        dockArea.resizing = true;
                        dockArea.resizeFrom = dockArea.height - m.y;
                        dockArea.resizeStart = root.tileSize;
                        dockArea.suppressClick = true;
                        return;
                    }
                    dockArea.pressedIndex = dockArea.hoveredIndex;
                    const t = dockArea.tileAt(dockArea.hoveredIndex);
                    dockArea.pressTile = (t && t.kind === "app") ? t : null;
                    dockArea.pressX = m.x;
                    dockArea.pressY = m.y;
                }
                onReleased: {
                    if (dockArea.resizing) { dockArea.resizing = false; root.setTileSize(root.tileSize, true); }
                    dockArea.pressedIndex = -1;
                    dockArea.pressTile = null;
                    if (dockArea.dragKey !== "") dockArea.endDrag();
                }
                onCanceled: {
                    if (dockArea.resizing) { dockArea.resizing = false; root.setTileSize(root.tileSize, true); }
                    dockArea.pressedIndex = -1;
                    dockArea.pressTile = null;
                    if (dockArea.dragKey !== "") dockArea.endDrag();
                }
                onClicked: (m) => {
                    if (dockArea.suppressClick) return;
                    const t = dockArea.tileAt(dockArea.hoveredIndex);
                    if (!t) return;
                    const alt = !!(m.modifiers & Qt.AltModifier);
                    // Séparateur : clic droit (ou Ctrl+clic) = menu des réglages du Dock
                    if (m.button === Qt.RightButton || (m.modifiers & Qt.ControlModifier)) menu.openFor(t, alt);
                    else if (!t.isSeparator) dockArea.activateTile(t);
                }
                onPressAndHold: (m) => {
                    // Appui long = menu contextuel, comme macOS
                    if (dockArea.dragKey !== "" || dockArea.resizing) return;
                    const t = dockArea.tileAt(dockArea.hoveredIndex);
                    dockArea.pressedIndex = -1;
                    dockArea.pressTile = null;
                    dockArea.suppressClick = true;
                    if (t && !t.isSeparator) menu.openFor(t, !!(m.modifiers & Qt.AltModifier));
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
                // « Remove » au-dessus de l'icône sortie du Dock
                z: 10
                shown: dockArea.dragOut && dockModel.isPinned(dockArea.tileForKey(dockArea.dragKey)?.appId ?? "")
                text: "Remove"
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
                instant: menu.open || stack.open
                shown: dockArea.hovering && dockArea.revealed && !menu.open && !stack.open && t !== null && !t.isSeparator && dockArea.pressedIndex < 0 && dockArea.dragKey === ""
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
        description: "Minimize the active window into the Dock"
        onPressed: genie.minimizeActive()
    }
    GlobalShortcut {
        appid: "macos"
        name: "dock-autohide"
        description: "Turn Dock hiding on or off"
        onPressed: root.setAutohide(!root.autohide)
    }

    IpcHandler {
        target: "dock"
        // Minimise la fenêtre active vers le Dock (à lier à Cmd+M)
        function minimize(): void { genie.minimizeActive(); }
        function toggleAutohide(): void { root.setAutohide(!root.autohide); }
        function setAutohide(on: bool): void { root.setAutohide(on); }
        function setMagnification(on: bool): void { root.setMagnification(on); }
        function setShowRecents(on: bool): void { root.setShowRecents(on); }
    }

    Timer {
        id: traceTimer
        property var tile: null
        property var samples: []
        interval: 80; repeat: true
        onTriggered: { samples.push(Math.round(tile ? tile.bounce : -1)); if (samples.length >= 20) stop(); }
    }
    // Débogage (banc de test : pas de clic souris possible dans l'instance imbriquée)
    IpcHandler {
        target: "dock-debug"
        function visibility(): string {
            return JSON.stringify({ occupied: root.workspaceOccupied, autohide: root.autohide,
                revealed: dockArea.revealed, exclusiveZone: win.exclusiveZone });
        }
        function hover(x: real): void { dockArea.hovering = true; dockArea.mouseX = x; }
        function unhover(): void { dockArea.hovering = Qt.binding(() => mouse.containsMouse); }
        function click(i: int): void { const t = dockArea.tileAt(i); if (t) dockArea.activateTile(t); }
        function menuFor(i: int): void { const t = dockArea.tileAt(i); if (t) menu.debugOpen(t, false); }
        function menuAlt(i: int): void { const t = dockArea.tileAt(i); if (t) menu.debugOpen(t, true); }
        function size(v: int): void { root.setTileSize(v, false); }
        function prefs(): string { return JSON.stringify(dockModel.prefs) + " assign=" + JSON.stringify(dockModel.assign); }
        function closeMenu(): void { menu.close(); stack.close(); }
        function pinned(list: string): void { dockModel.pinned = list === "none" ? [] : list.split("|"); }
        function resetPinned(): void { dockModel.userPinned = false; dockModel.applyDefaults(); dockModel.saveState(false); }
        function dark(on: bool): void { Theme.dark = on; }
        function stackFor(i: int, dir: string): void { const t = dockArea.tileAt(i); if (t) { if (dir) stack.folder = dir; stack.grab = false; stack.toggleFor(t); } }
        function stackInfo(): string { return stack.debugInfo(); }
        function stackNavigate(i: int): void { stack.debugNavigate(i); }
        function stackBack(): void { stack.back(); }
        function menuHover(row: int): void { menu.debugHover(row); }
        function menuTrigger(row: int): void { menu.debugTrigger(row); }
        function launch(id: string): void { dockModel.launch(id); }
        function bounce(id: string): void { dockModel.markLaunching(id); }
        function stopBounce(id: string): void { dockModel.endLaunching(id); }
        function attention(cls: string): void { const a = {}; a[cls] = Date.now(); dockModel.attention = a; }
        // Rebond d'attention échantillonné toutes les 80 ms (les appels IPC sont trop lents)
        function attentionTrace(cls: string, i: int): void {
            attention(cls);
            traceTimer.tile = dockArea.tileAt(i); traceTimer.samples = []; traceTimer.restart();
        }
        function trace(): string { return JSON.stringify(traceTimer.samples) + " bouncing=" + dockModel.bouncing; }
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
