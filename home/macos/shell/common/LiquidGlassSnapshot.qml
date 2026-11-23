import QtQuick
import Quickshell
import Quickshell.Wayland

// Fournisseur de fond pour LiquidGlass (backdrop: "snapshot") : capture unique
// de l'écran (wlr-screencopy via ScreencopyView), prise AVANT que le panneau ne
// soit visible : sinon le panneau se capturerait lui-même (boucle de
// rétroaction). La capture n'est pas rafraîchie tant que le panneau est ouvert.
//
// Deux modes :
//  - à la demande (défaut) : capture() crée le contexte de capture, l'image
//    arrive ~3 images plus tard (≈ 50 ms mesurés à 60 Hz) ; signal captured()
//    -> rendre le panneau visible ;
//  - prewarm: true : capture continue (live) tant que le panneau est fermé ;
//    capture() fige la dernière image : captured() dès l'image suivante de la
//    boucle d'événements (latence ~0). Coût : une copie GPU de l'écran à chaque
//    image où l'écran change, panneau fermé.
//
// Usage dans un panneau temporaire :
//   LiquidGlassSnapshot { id: snap; screen: win.screen }
//   function open() { snap.capture(); }      // panneau encore caché
//   Connections { target: snap; function onCaptured() { win.visible = true } }
//   function close() { win.visible = false; snap.release(); }
//   LiquidGlass { backdrop: "snapshot"; backdropItem: snap; ... }
Item {
    id: root

    property var screen: null
    property bool prewarm: false
    property bool paintCursor: false
    // Prêt : une capture prise pour cette ouverture est disponible
    readonly property bool ready: view.hasContent && _armed
    // Délai capture() -> image disponible (ms), pour mesurer la latence ajoutée
    property real latencyMs: 0
    signal captured()

    property bool _armed: false
    property double _t0: 0

    width: screen?.width ?? 0
    height: screen?.height ?? 0
    // Jamais affiché tel quel (seulement lu par les ShaderEffectSource des verres)
    visible: false

    function capture() {
        _t0 = Date.now();
        if (prewarm && view.hasContent && view.live) {
            // Fige l'image courante (le panneau n'y est pas : il est caché)
            view.live = false;
            _armed = true;
            latencyMs = 0;
            Qt.callLater(root.captured);
            return;
        }
        // Nouvelle capture : ScreencopyView ne signale pas chaque image, on
        // recrée donc le contexte (captureSource null -> écran), ce qui remet
        // hasContent à faux jusqu'à l'arrivée de l'image.
        _armed = true;
        view.live = false;
        view.captureSource = null;
        view.captureSource = root.screen;
    }
    // À la fermeture du panneau : libère le tampon, ou relance la capture live
    function release() {
        _armed = false;
        if (prewarm) {
            view.captureSource = root.screen;
            view.live = true;
        } else {
            view.captureSource = null;
        }
    }

    onPrewarmChanged: if (!_armed) release()
    onScreenChanged: if (!_armed) release()

    ScreencopyView {
        id: view
        anchors.fill: parent
        captureSource: null
        live: false
        paintCursor: root.paintCursor
        onHasContentChanged: {
            if (hasContent && root._armed && !live) {
                root.latencyMs = Date.now() - root._t0;
                root.captured();
            }
        }
    }
}
