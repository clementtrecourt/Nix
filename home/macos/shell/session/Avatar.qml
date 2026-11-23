import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.common

// Avatar rond : ~/.face si présent, sinon monogramme macOS (disque gris en
// dégradé + initiales blanches).
Item {
    id: root

    property string source
    property string name
    property int size: 56
    property bool shadow: true

    width: size
    height: size

    RectangularShadow {
        anchors.fill: parent
        visible: root.shadow
        radius: width / 2
        blur: 10
        spread: 0
        offset.y: 1
        color: Qt.rgba(0, 0, 0, 0.30)
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"

        // Monogramme (affiché tant que l'image n'est pas prête)
        Rectangle {
            anchors.fill: parent
            visible: face.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0; color: "#A9ADB5" }
                GradientStop { position: 1; color: "#80858E" }
            }
            Text {
                anchors.centerIn: parent
                text: root.name.split(/\s+/).filter(w => w.length).map(w => w.charAt(0)).join("").slice(0, 2).toUpperCase()
                font.family: Theme.fontDisplay
                font.pixelSize: Math.round(root.size * 0.42)
                font.weight: Font.DemiBold
                color: "white"
            }
        }

        Image {
            id: face
            anchors.fill: parent
            source: root.source
            sourceSize: Qt.size(root.size * 2, root.size * 2)
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
        }
    }
}
