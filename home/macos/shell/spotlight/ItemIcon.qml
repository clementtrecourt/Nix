import QtQuick
import Quickshell.Widgets
import qs.common

// Icône d'un résultat : vignette (image / capture), icône du thème, ou
// symbole blanc sur tuile colorée façon Raccourcis (actions, calcul, Web).
Item {
    id: root

    property var item
    property int size: 28

    implicitWidth: size
    implicitHeight: size

    readonly property bool hasThumb: !!(item && item.thumb) && thumb.status !== Image.Error
    readonly property bool useTile: !hasThumb && !!(item && item.symbol && !item.icon)

    // Vignette d'image (fichiers image, images du presse-papiers)
    Image {
        id: thumb
        anchors.fill: parent
        visible: root.hasThumb && status === Image.Ready
        source: root.item && root.item.thumb ? root.item.thumb : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
    }
    // Liseré fin autour des vignettes (comme les aperçus Finder)
    Rectangle {
        visible: thumb.visible
        x: (parent.width - thumb.paintedWidth) / 2 - 0.5
        y: (parent.height - thumb.paintedHeight) / 2 - 0.5
        width: thumb.paintedWidth + 1
        height: thumb.paintedHeight + 1
        color: "transparent"
        radius: 2
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
    }

    // Icône du thème (apps, fichiers)
    IconImage {
        anchors.fill: parent
        visible: !root.hasThumb && !root.useTile && !!(root.item && root.item.icon)
        source: root.item && root.item.icon ? root.item.icon : ""
        implicitSize: root.size
        asynchronous: true
        mipmap: true
    }

    // Tuile colorée + symbole
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.size * 0.04
        visible: root.useTile
        radius: width * 0.26
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(root.item?.tint ?? "#8e8e93", 1.18) }
            GradientStop { position: 1.0; color: root.item?.tint ?? "#8e8e93" }
        }
        border.width: 0.5
        border.color: Qt.rgba(1, 1, 1, 0.12)
        Symbol {
            anchors.centerIn: parent
            name: root.item?.symbol ?? ""
            size: Math.round(root.size * 0.56)
            color: "white"
        }
    }
}
