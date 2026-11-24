import QtQuick
import QtQuick.Effects
import qs.common

// Picto façon SF Symbols (assets/symbols/<name>.svg) pour la barre et les menus.
// Contrairement à common/Symbol.qml (SVG rastérisé en 2x puis réduit par le
// GPU, d'où des bords gris à l'échelle 1), le SVG est rastérisé à la taille
// EXACTE en pixels physiques : net sur un écran non Retina, pourvu que l'élément
// soit posé sur des pixels entiers.
// La colorisation de MultiEffect ignore l'alpha de colorizationColor : on
// colorise avec la couleur opaque et on reporte l'alpha sur l'opacité (picto
// grisé = labelTertiary, labelSecondary).
Item {
    id: root

    property string name
    property int size: 16
    property color tint: Theme.label

    implicitWidth: size
    implicitHeight: size
    opacity: tint.a

    readonly property real _dpr: Window.window?.devicePixelRatio ?? 1

    Image {
        id: img
        anchors.fill: parent
        source: root.name ? Qt.resolvedUrl("../assets/symbols/" + root.name + ".svg") : ""
        sourceSize: Qt.size(Math.round(root.width * root._dpr), Math.round(root.height * root._dpr))
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }

    MultiEffect {
        anchors.fill: img
        source: img
        colorization: 1.0
        colorizationColor: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 1)
        brightness: 1.0
    }
}
