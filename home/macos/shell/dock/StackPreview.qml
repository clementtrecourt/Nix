import QtQuick

// Aperçu d'un élément de la pile : essaie chaque source dans l'ordre
// (miniature du cache, image elle-même, icône du type) et garde la première
// qui se charge. Rastérisé à sa taille exacte (`pixel`) : net sur un écran 1x.
Item {
    id: root

    property var sources: []
    property int pixel: 48
    property bool hovered: false

    property int attempt: 0
    onSourcesChanged: attempt = 0

    Image {
        anchors.fill: parent
        source: root.sources.length ? root.sources[Math.min(root.attempt, root.sources.length - 1)] : ""
        sourceSize: Qt.size(root.pixel, root.pixel)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        onStatusChanged: if (status === Image.Error && root.attempt < root.sources.length - 1) root.attempt++
    }
}
