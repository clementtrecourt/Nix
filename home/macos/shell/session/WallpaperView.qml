import QtQuick

// Rendu du fond d'écran courant (bureau et écran de verrouillage) :
// fond procédural Tahoe en dessous, image utilisateur par-dessus, fondu
// enchaîné de 700 ms quand l'image change (comme Réglages > Fond d'écran).
Item {
    id: root

    property string source: WallpaperService.source
    // Taille de décodage (évite de garder une image 6K en mémoire)
    property size decodeSize: Qt.size(width * 2, height * 2)

    // Couche du dessous : toujours le fond procédural
    TahoeWallpaper {
        anchors.fill: parent
        // Inutile de calculer le shader quand une image opaque le recouvre
        visible: front.opacity < 1 || back.opacity < 1 || root.source === ""
    }

    // Deux couches d'image en alternance : `back` garde l'ancienne image pendant
    // que `front` (la nouvelle) apparaît en fondu.
    Image {
        id: back
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: root.decodeSize
        opacity: 0
    }
    Image {
        id: front
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: root.decodeSize
        opacity: 0
        onStatusChanged: if (status === Image.Ready && source != "" && opacity < 1) fadeIn.restart()
    }

    NumberAnimation {
        id: fadeIn
        target: front
        property: "opacity"
        to: 1
        duration: 700
        easing.type: Easing.InOutQuad
        onFinished: { back.source = ""; back.opacity = 0; }
    }
    NumberAnimation {
        id: fadeOut   // retour au fond procédural
        target: front
        property: "opacity"
        to: 0
        duration: 700
        easing.type: Easing.InOutQuad
        onFinished: front.source = ""
    }

    // Au démarrage, la première image arrive sans fondu
    property bool settled: false
    Timer { interval: 1500; running: true; onTriggered: root.settled = true }

    function apply() {
        if (front.source == root.source) return;
        if (!root.settled) {
            fadeIn.stop(); fadeOut.stop();
            back.source = "";
            front.source = root.source;
            front.opacity = root.source === "" ? 0 : 1;
            return;
        }
        fadeIn.stop();
        fadeOut.stop();
        if (root.source === "") {
            back.source = "";
            back.opacity = 0;
            fadeOut.start();
            return;
        }
        // L'image actuelle passe derrière, la nouvelle arrive devant
        if (front.source != "" && front.opacity > 0) {
            back.source = front.source;
            back.opacity = front.opacity;
        }
        front.opacity = 0;
        front.source = root.source;
        if (front.status === Image.Ready) fadeIn.restart();
    }

    onSourceChanged: apply()
    Component.onCompleted: apply()
}
