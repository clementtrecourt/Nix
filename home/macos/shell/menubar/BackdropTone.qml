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
//
// Deux zones sont mesurées séparément (menus à gauche, icônes d'état à droite) :
// sur un fond d'écran mi-sombre mi-clair, chaque groupe reste lisible.
Item {
    id: root

    property var screen
    property int stripHeight: 32
    // Échantillonnage actif (écran allumé, pas de plein écran)
    property bool active: true
    // Vrai = fond clair -> texte noir (barre entière, zone gauche, zone droite)
    property bool light: false
    property bool lightLeft: false
    property bool lightRight: false
    property real luminance: 0
    property real luminanceLeft: 0
    property real luminanceRight: 0
    // Étendue des zones, en pixels logiques de l'écran : [0, leftEnd] et
    // [rightStart, largeur] (0 / largeur : toute la barre)
    property real leftEnd: 0
    property real rightStart: 0

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
            // (pendant un rechargement du shell, l'ancienne vue n'a plus de fenêtre)
            if (!view.hasContent || !view.Window.window) { root.busy = false; return; }
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
            const sw = root.screen?.width ?? 1920;
            const xl = root.leftEnd > 0 ? Math.ceil(root.leftEnd * width / sw) : width;
            const xr = root.rightStart > 0 ? Math.floor(root.rightStart * width / sw) : 0;
            // Moyenne de luminance d'une plage de colonnes, sans nos libellés.
            // Si presque tout est exclu, c'est le fond lui-même qui est blanc
            // (ou noir) pur : on garde alors tous les pixels.
            const measure = (x0, x1, textWhite) => {
                let sum = 0, n = 0, sumAll = 0, nAll = 0;
                for (let y = 0; y < height; y++) {
                    for (let x = Math.max(0, x0); x < Math.min(width, x1); x++) {
                        const i = (y * width + x) * 4;
                        const l = 0.2126 * d[i] / 255 + 0.7152 * d[i + 1] / 255 + 0.0722 * d[i + 2] / 255;
                        sumAll += l;
                        nAll++;
                        // Nos propres libellés : blanc pur ou noir pur
                        if (textWhite ? l > 0.93 : l < 0.07) continue;
                        sum += l;
                        n++;
                    }
                }
                if (nAll === 0) return -1;
                return n >= nAll * 0.4 ? sum / n : sumAll / nAll;
            };
            // Hystérésis : bascule en noir au-dessus de 0,63, en blanc sous 0,53 (une traînée claire à 0,65
            // derrière l'horloge passe en noir ; un bleu moyen à 0,6 reste en blanc)
            const decide = (was, lum) => lum < 0 ? was : (!was && lum > 0.63) ? true : (was && lum < 0.53) ? false : was;
            const all = measure(0, width, !root.light);
            const left = measure(0, xl, !root.lightLeft);
            const right = measure(xr, width, !root.lightRight);
            shot.source = "";
            root._keep = null;
            root.busy = false;
            if (all >= 0) root.luminance = all;
            if (left >= 0) root.luminanceLeft = left;
            if (right >= 0) root.luminanceRight = right;
            root.light = decide(root.light, all);
            root.lightLeft = decide(root.lightLeft, left);
            root.lightRight = decide(root.lightRight, right);
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
