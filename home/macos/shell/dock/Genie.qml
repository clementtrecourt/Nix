import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.services

// Animation de minimisation / restauration vers le Dock (effet génie de macOS).
// La fenêtre est capturée (ScreencopyView), envoyée sur special:minimized, puis sa
// capture est déformée par un maillage (shaders/genie.vert) jusqu'à la miniature
// du Dock ; la restauration rejoue l'effet à l'envers avant de ramener la fenêtre.
Scope {
    id: root

    property var screen
    property var dock
    property bool enabled: true          // false : simple réduction (effet « échelle »)

    property int duration: 520  // durée macOS (≈ 0,5 s)

    property var toplevel: null
    property bool restoring: false
    property string address: ""
    property rect srcRect: Qt.rect(0, 0, 1, 1)
    property rect dstRect: Qt.rect(0, 0, 1, 1)
    property real progress: 0

    function windowRect(t) {
        const o = t?.lastIpcObject ?? {};
        const at = o.at ?? [0, 0], size = o.size ?? [400, 300];
        const sx = root.screen?.x ?? 0, sy = root.screen?.y ?? 0;
        return Qt.rect(at[0] - sx, at[1] - sy, size[0], size[1]);
    }

    // Rectangle de la miniature d'une fenêtre dans sa tuile (ou repli : Corbeille)
    function thumbRect(addr, winSize) {
        const tile = dock.tileForKey("win:" + addr) ?? dock.tileForKey("trash");
        if (!tile) return Qt.rect(dock.width / 2, dock.height, 1, 1);
        const T = tile.vSize;
        const fit = Math.min(T * 0.9 / Math.max(1, winSize.width), T * 0.9 / Math.max(1, winSize.height));
        const w = winSize.width * fit, h = winSize.height * fit;
        const cx = tile.x + tile.width / 2;
        const cy = tile.vTop + T / 2;
        // Coordonnées de la fenêtre du Dock -> écran
        const oy = (root.screen?.height ?? dock.height) - dock.height;
        return Qt.rect(cx - w / 2, oy + cy - h / 2, w, h);
    }

    function minimizeActive() {
        const t = Hyprland.activeToplevel;
        if (t && !Windows.isMinimized(t)) minimize(t);
    }

    function minimize(t) {
        if (anim.running) anim.complete();
        Hyprland.refreshToplevels();
        toplevel = t;
        address = t.address;
        restoring = false;
        srcRect = windowRect(t);
        dstRect = srcRect;
        progress = 0;
        dock.model.setLanding(address, true);
        shot.captureSource = t.wayland;
        overlay.visible = true;
        startTimer.restart();
    }

    function restore(t, tile) {
        if (anim.running) anim.complete();
        Hyprland.refreshToplevels();
        toplevel = t;
        address = t.address;
        restoring = true;
        srcRect = windowRect(t);
        dstRect = thumbRect(address, Qt.size(srcRect.width, srcRect.height));
        progress = 1;
        dock.model.setLanding(address, true);
        shot.captureSource = t.wayland;
        overlay.visible = true;
        startTimer.restart();
    }

    // Laisse le temps à la première image capturée d'arriver
    Timer {
        id: startTimer
        interval: 60
        onTriggered: {
            if (!root.restoring) {
                Windows.minimize(root.toplevel);
            }
            if (!shot.hasContent) {
                // Capture impossible : pas d'animation
                root.finish();
                return;
            }
            anim.from = root.restoring ? 1 : 0;
            anim.to = root.restoring ? 0 : 1;
            anim.start();
        }
    }

    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        duration: root.duration
        easing.type: Easing.InOutSine
        onFinished: root.finish()
    }

    // Pendant la minimisation, la cible suit la tuile qui s'ouvre dans le Dock
    FrameAnimation {
        running: anim.running && !root.restoring
        onTriggered: root.dstRect = root.thumbRect(root.address, Qt.size(root.srcRect.width, root.srcRect.height))
    }

    function finish() {
        if (restoring && toplevel) Windows.restore(toplevel);
        const addr = address;
        endTimer.addr = addr;
        endTimer.restart();
    }
    Timer {
        id: endTimer
        property string addr
        // Une image de plus pour que la fenêtre / la miniature soit réellement affichée
        interval: root.restoring ? 90 : 30
        onTriggered: {
            overlay.visible = false;
            shot.captureSource = null;
            root.dock.model.setLanding(addr, false);
            root.toplevel = null;
        }
    }

    // ---- Débogage : fige l'animation à une étape donnée ----
    property real debugHold: -1
    onProgressChanged: if (debugHold >= 0 && anim.running) { anim.stop(); progress = debugHold; }
    function debugAt(p) { debugHold = p; anim.stop(); progress = p; }
    function debugEnd() { debugHold = -1; finish(); }

    PanelWindow {
        id: overlay
        visible: false
        screen: root.screen
        color: "transparent"
        WlrLayershell.namespace: "macos-genie"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { left: true; right: true; top: true; bottom: true }
        mask: Region {}

        ScreencopyView {
            id: shot
            width: root.srcRect.width
            height: root.srcRect.height
            live: true
            captureSource: null
        }
        ShaderEffectSource {
            id: tex
            sourceItem: shot
            hideSource: true
            live: true
            width: 1; height: 1
            visible: false
        }
        ShaderEffect {
            anchors.fill: parent
            visible: shot.hasContent
            property variant source: tex
            property real progress: root.progress
            property real mode: root.enabled ? 0 : 1
            property rect src: root.srcRect
            property rect dst: root.dstRect
            property real radius: Theme.radiusWindow
            mesh: GridMesh { resolution: Qt.size(4, 72) }
            vertexShader: Qt.resolvedUrl("shaders/genie.vert.qsb")
            fragmentShader: Qt.resolvedUrl("shaders/genie.frag.qsb")
        }
    }
}
