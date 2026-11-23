import QtQuick

// Détecte si une icône de la barre d'état est « monochrome » (équivalent des
// template images de macOS : un seul ton, sans couleur). Ces icônes sont alors
// recolorées dans la couleur de la barre (noir sur fond clair) ; les icônes en
// couleur restent telles quelles.
//
// Méthode : capture de l'item à 16 px (grabToImage), lecture des pixels via un
// Canvas ; monochrome si les pixels visibles sont quasi gris (saturation faible).
Item {
    id: root

    // Item à analyser (déjà affiché)
    property Item target
    // Clé qui change quand l'icône change (relance l'analyse)
    property string key: ""
    // Résultat
    property bool mono: false

    width: 0
    height: 0

    property var _keep: null

    function probe() {
        if (!target || !target.visible || target.width <= 0 || !target.Window.window) return;
        const ok = target.grabToImage(r => {
            shot.source = r.url;
            root._keep = r;
        }, Qt.size(16, 16));
        if (!ok) retry.restart();
    }

    onKeyChanged: delay.restart()
    Component.onCompleted: delay.restart()

    // Laisse l'icône se charger avant de la capturer
    Timer {
        id: delay
        interval: 400
        onTriggered: root.probe()
    }
    Timer {
        id: retry
        interval: 1000
        onTriggered: root.probe()
    }

    Image {
        id: shot
        x: -4000
        width: 16
        height: 16
        cache: false
        onStatusChanged: if (status === Image.Ready) canvas.requestPaint()
    }

    Canvas {
        id: canvas
        x: -4000
        width: 16
        height: 16
        onPaint: {
            if (shot.status !== Image.Ready) return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(shot, 0, 0, 16, 16);
            const d = ctx.getImageData(0, 0, 16, 16).data;
            // Monochrome = sans couleur ET d'un seul ton : une icône grise à
            // deux tons (disque noir + motif blanc) ne doit pas être aplatie
            // en silhouette unie par la recoloration.
            let n = 0, colored = 0, lo = 1, hi = 0;
            for (let i = 0; i < d.length; i += 4) {
                if (d[i + 3] < 60) continue;
                n++;
                const mx = Math.max(d[i], d[i + 1], d[i + 2]), mn = Math.min(d[i], d[i + 1], d[i + 2]);
                if (mx - mn > 40) colored++;
                // Ton des pixels bien opaques (les bords anticrénelés sont ignorés)
                if (d[i + 3] > 170) {
                    const l = (0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2]) / 255;
                    lo = Math.min(lo, l);
                    hi = Math.max(hi, l);
                }
            }
            shot.source = "";
            root._keep = null;
            // Quelques pixels colorés tolérés (anticrénelage)
            if (n > 0) root.mono = colored <= n * 0.06 && (hi < lo || hi - lo < 0.3);
        }
    }
}
