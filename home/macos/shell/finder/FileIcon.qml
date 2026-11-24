import QtQuick
import Quickshell
import qs.common

// Icône d'un élément du Finder : vignette (images, PDF, vidéos) ou icône du
// thème (dossiers bleus Tahoe, types de documents). La vignette d'une image
// garde ses proportions dans le carré, avec un fin liseré et une ombre légère
// comme les aperçus du Finder ; l'icône du thème reste affichée tant que la
// vignette n'est pas prête.
Item {
    id: root

    property var entry: null
    property int size: 64
    // Vignettes autorisées (faux : icône de type seulement, ex. barre de chemin)
    property bool thumbnails: true
    // Atténuée (élément coupé, fichier caché)
    property bool dimmed: false
    // Pastille de sélection derrière l'icône (présentation Icônes)
    readonly property bool showsThumb: thumb.status === Image.Ready && thumb.source != ""
    readonly property real paintedW: showsThumb ? thumb.paintedWidth : size
    readonly property real paintedH: showsThumb ? thumb.paintedHeight : size

    implicitWidth: size
    implicitHeight: size
    opacity: dimmed ? 0.5 : 1

    readonly property real _dpr: QsWindow.window?.devicePixelRatio ?? 1
    readonly property int _px: Math.round(size * _dpr)
    readonly property bool _isImage: !!entry && thumbnails && size >= 14 && Fs.isImage(entry)
    readonly property string _extThumb: (!!entry && thumbnails && size >= 32) ? Thumbs.get(entry, Math.max(128, _px)) : ""
    readonly property url _thumbSource: _isImage ? Fs.fileUrl(entry.path) : (_extThumb ? _extThumb : "")

    Image {
        id: icon
        anchors.fill: parent
        visible: !root.showsThumb
        source: root.entry ? Fs.iconFor(root.entry) : ""
        // Les petites tailles du thème (16, 22, 24) sont des pictogrammes au
        // trait : toujours demander la variante pleine couleur, puis réduire
        sourceSize: Qt.size(Math.max(root._px, 64), Math.max(root._px, 64))
        fillMode: Image.PreserveAspectFit
        asynchronous: root.size > 32
        smooth: true
        mipmap: true
    }

    // Petite flèche des alias (coin inférieur gauche), comme macOS
    Image {
        visible: !!root.entry && !!root.entry.isLink
        width: Math.max(8, root.size * 0.32)
        height: width
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.size * 0.06
        source: Fs.themeIcon("emblem-symbolic-link", "emblem-link")
        sourceSize: Qt.size(width * 2, height * 2)
    }

    // Ombre portée discrète sous la vignette
    Rectangle {
        visible: root.showsThumb && root.size >= 32
        x: (root.width - thumb.paintedWidth) / 2
        y: (root.height - thumb.paintedHeight) / 2 + 1
        width: thumb.paintedWidth
        height: thumb.paintedHeight
        radius: frame.radius
        color: Qt.rgba(0, 0, 0, Theme.dark ? 0.40 : 0.14)
    }
    Image {
        id: thumb
        anchors.fill: parent
        // Les vignettes sont un peu plus petites que la case de l'icône (~90 %)
        anchors.margins: root.size >= 32 ? Math.round(root.size * 0.06) : 0
        source: root._thumbSource
        sourceSize: Qt.size(root._px, root._px)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        cache: true
        visible: root.showsThumb
    }
    // Liseré fin autour de la vignette
    Rectangle {
        id: frame
        visible: root.showsThumb && root.size >= 32
        x: (root.width - thumb.paintedWidth) / 2
        y: (root.height - thumb.paintedHeight) / 2
        width: thumb.paintedWidth
        height: thumb.paintedHeight
        radius: 0
        color: "transparent"
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)
    }
}
