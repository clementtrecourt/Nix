import QtQuick
import qs.common

// Barre de défilement fine façon macOS (défileur en surimpression) : poignée
// de 7 pt arrondie, à 3 pt du bord droit, visible quand le contenu déborde,
// à l'apparition et pendant le défilement, puis en fondu (MacRumors
// « spotlight-clipboard », « spotlight-categories »).
Item {
    id: root

    property Flickable flick
    readonly property bool overflow: !!flick && flick.contentHeight > flick.height + 1

    anchors.right: flick ? flick.right : undefined
    anchors.top: flick ? flick.top : undefined
    anchors.bottom: flick ? flick.bottom : undefined
    anchors.rightMargin: 3
    anchors.topMargin: 4
    anchors.bottomMargin: 4
    width: 7
    visible: overflow && opacity > 0
    opacity: 0

    // Proportion visible et position (contenu compris entre les marges)
    readonly property real total: flick ? Math.max(1, flick.contentHeight + flick.topMargin + flick.bottomMargin) : 1
    readonly property real ratio: flick ? Math.min(1, flick.height / total) : 1
    readonly property real pos: flick ? Math.max(0, Math.min(1, (flick.contentY - flick.originY + flick.topMargin) / Math.max(1, total - flick.height))) : 0

    Rectangle {
        width: parent.width
        height: Math.round(Math.max(24, parent.height * root.ratio))
        y: Math.round((parent.height - height) * root.pos)
        radius: width / 2
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.38) : Qt.rgba(0, 0, 0, 0.32)
    }

    // Affiche la barre un instant
    function flash() {
        if (!overflow) return;
        fade.stop();
        opacity = 1;
        hideTimer.restart();
    }
    Timer { id: hideTimer; interval: 1100; onTriggered: fade.start() }
    NumberAnimation { id: fade; target: root; property: "opacity"; to: 0; duration: 300 }

    Connections {
        target: root.flick
        function onContentYChanged() { root.flash(); }
        function onContentHeightChanged() { root.flash(); }
        function onVisibleChanged() { if (root.flick.visible) root.flash(); }
    }
    onOverflowChanged: flash()
}
