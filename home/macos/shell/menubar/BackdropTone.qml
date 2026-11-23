import QtQuick
import Quickshell
import Quickshell.Wayland

// Luminosité de ce qui est derrière la barre (fond d'écran) : macOS Tahoe écrit
// la barre transparente en blanc sur fond sombre, en noir sur fond clair.
//
// Méthode : capture d'écran réduite (ScreencopyView, à la demande), lecture des
// pixels de la bande de la barre via un Canvas, moyenne de luminance relative.
// Les pixels proches de la couleur actuelle du texte (nos propres libellés)
// sont ignorés ; un hystérésis évite le clignotement sur les fonds moyens.
Item {
    id: root

    property var screen
    property int stripHeight: 32
    // Vrai = fond clair -> texte noir
    property bool light: false
    property real luminance: 0
    // Couleur actuelle du texte (exclue de la mesure)
    readonly property bool textIsWhite: !light

    // Largeur d'échantillonnage (la hauteur suit le ratio de l'écran)
    readonly property int sw: 160
    readonly property int sh: Math.max(1, Math.round(sw * (screen?.height ?? 1080) / (screen?.width ?? 1920)))
    readonly property int stripRows: Math.max(1, Math.round(stripHeight * sw / (screen?.width ?? 1920)))

    width: 0
    height: 0

    function sample() {
        if (!root.screen || busy) return;
        busy = true;
        view.captureFrame();
    }
    property bool busy: false

    // Hors de la zone visible de la fenêtre, mais rendu (grabToImage)
    ScreencopyView {
        id: view
        x: -4000
        width: root.sw
        height: root.sh
        captureSource: root.screen
        live: false
        paintCursor: false
        onHasContentChanged: if (hasContent) grabTimer.restart()
    }

    // Laisse une image au rendu avant de lire la texture
    Timer {
        id: grabTimer
        interval: 60
        onTriggered: {
            const ok = view.grabToImage(r => {
                canvas.pending = r.url;
                canvas.loadImage(r.url);
                root._keep = r; // garde le résultat en vie jusqu'au chargement
            }, Qt.size(root.sw, root.sh));
            if (!ok) root.busy = false;
        }
    }
    property var _keep: null

    Canvas {
        id: canvas
        x: -4000
        width: root.sw
        height: root.stripRows
        property string pending: ""
        renderStrategy: Canvas.Immediate
        onImageLoaded: requestPaint()
        onPaint: {
            if (!pending || !isImageLoaded(pending)) return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(pending, 0, 0, root.sw, root.sh);
            const d = ctx.getImageData(0, 0, width, height).data;
            let sum = 0, n = 0;
            const tw = root.textIsWhite;
            for (let i = 0; i < d.length; i += 4) {
                const r = d[i] / 255, g = d[i + 1] / 255, b = d[i + 2] / 255;
                const l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
                // Nos propres libellés : blanc pur ou noir pur
                if (tw ? l > 0.93 : l < 0.07) continue;
                sum += l;
                n++;
            }
            unloadImage(pending);
            pending = "";
            root._keep = null;
            root.busy = false;
            if (n === 0) return;
            const lum = sum / n;
            root.luminance = lum;
            if (!root.light && lum > 0.66) root.light = true;
            else if (root.light && lum < 0.54) root.light = false;
        }
    }

    // Échantillonnage régulier (fond d'écran changé, espace de travail, etc.)
    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }
}
