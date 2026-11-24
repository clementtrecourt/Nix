import QtQuick
import QtQuick.Effects
import Quickshell
import qs.common

// Pictogramme façon SF Symbols : charge assets/symbols/<name>.svg (dessin noir sur
// transparent) et le recolore. Ajouter un symbole = déposer un SVG monochrome.
Item {
    id: root

    property string name
    property int size: 16
    property color color: Theme.label

    implicitWidth: size
    implicitHeight: size

    Image {
        id: img
        anchors.fill: parent
        source: root.name ? Qt.resolvedUrl("../assets/symbols/" + root.name + ".svg") : ""
        // Rastérisé à la taille exacte en pixels (écran 1x : un rendu 2x réduit
        // ensuite donnait des pictos flous)
        readonly property real _dpr: QsWindow.window?.devicePixelRatio ?? 1
        sourceSize: Qt.size(Math.round(root.size * _dpr), Math.round(root.size * _dpr))
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }

    MultiEffect {
        anchors.fill: img
        source: img
        colorization: 1.0
        colorizationColor: root.color
        brightness: 1.0
    }
}
