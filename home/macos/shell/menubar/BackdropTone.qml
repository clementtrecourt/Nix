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
    // Échantillonnage actif (écran allumé, pas de plein écran)
    property bool active: true
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

    property bool busy: false
    property var _keep: null

    function sample() {
        if (!root.screen || !root.active || busy) return;
        busy = true;
        busyReset.restart();
        if (view.hasContent) view.captureFrame();
        grabTimer.restart();
    }

    // Si la capture n'aboutit pas, on réessaiera au prochain tour
    Timer {
        id: busyReset
        interval: 1500
        onTriggered: root.busy = false
    }

    // Hors de la zone visible de la fenêtre, mais rendu (grabToImage).
    // La première image arrive seule dès que la source est prête.
    ScreencopyView {
        id: view
        x: -4000
        width: root.sw
        height: root.sh
        captureSource: root.active ? root.screen : null
        live: false
        paintCursor: false
    }

    // Laisse la capture arriver et s'afficher avant de lire la texture
    Timer {
        id: grabTimer
        interval: 150
        onTriggered: {
            if (!view.hasContent) { root.busy = false; return; }
            const ok = view.grabToImage(r => {
                shot.source = r.url;
                root._keep = r; // garde le résultat en vie jusqu'au chargement
            }, Qt.size(root.sw, root.sh));
            if (!ok) root.busy = false;
        }
    }

    // Le Canvas ne sait pas charger les URL "itemgrabber:" : on passe par une Image
    Image {
        id: shot
        x: -4000
        width: root.sw
        height: root.sh
        cache: false
        onStatusChanged: if (status === Image.Ready) canvas.requestPaint()
    }

    Canvas {
        id: canvas
        x: -4000
        width: root.sw
        height: root.stripRows
        onPaint: {
            if (shot.status !== Image.Ready) return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(shot, 0, 0, root.sw, root.sh);
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
            shot.source = "";
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
