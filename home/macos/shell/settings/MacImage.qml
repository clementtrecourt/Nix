import QtQuick
import Quickshell.Widgets
import qs.session

// Image de la machine (MacBook ou écran de bureau) montrant le fond d’écran,
// comme en tête de General > About (reprise de session/AboutWindow).
Item {
    id: mac
    property bool laptop: false
    width: 152
    height: 92

    // Écran (couvercle / dalle)
    Rectangle {
        id: lid
        anchors.horizontalCenter: parent.horizontalCenter
        y: mac.laptop ? 1 : 0
        width: mac.laptop ? 118 : 132
        height: mac.laptop ? 78 : 76
        radius: mac.laptop ? 5 : 3
        // Bord aluminium (fin liseré) + cadre noir
        color: mac.laptop ? "#2a2a2c" : "#c9cacd"
        Rectangle {
            anchors.fill: parent
            anchors.margins: mac.laptop ? 0.75 : 1
            radius: parent.radius - 0.5
            color: "#0d0d0e"
            ClippingRectangle {
                anchors.fill: parent
                anchors.leftMargin: mac.laptop ? 3.5 : 3
                anchors.rightMargin: mac.laptop ? 3.5 : 3
                anchors.topMargin: mac.laptop ? 4 : 3
                anchors.bottomMargin: mac.laptop ? 5 : 3
                radius: mac.laptop ? 1.5 : 0.5
                color: "black"
                WallpaperView {
                    anchors.fill: parent
                    decodeSize: Qt.size(260, 160)
                }
            }
        }
    }

    // Portable : base aluminium (lèvre claire, dessous plus sombre, encoche)
    Item {
        visible: mac.laptop
        anchors.horizontalCenter: parent.horizontalCenter
        y: lid.y + lid.height - 0.5
        width: 152
        height: 6
        Rectangle {
            width: parent.width
            height: 4
            radius: 2
            gradient: Gradient {
                GradientStop { position: 0; color: "#e9eaec" }
                GradientStop { position: 0.5; color: "#c7c8cb" }
                GradientStop { position: 1; color: "#8e8f93" }
            }
        }
        // Encoche d'ouverture
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 22
            height: 1.6
            radius: 0.8
            color: "#9fa0a4"
        }
        // Ombre au sol
        Rectangle {
            y: 4
            x: 6
            width: parent.width - 12
            height: 2
            radius: 1
            color: Qt.rgba(0, 0, 0, 0.18)
        }
    }

    // Écran de bureau : pied aluminium (col + plateau)
    Item {
        visible: !mac.laptop
        anchors.horizontalCenter: parent.horizontalCenter
        y: lid.height - 1
        width: 52
        height: mac.height - lid.height + 1
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 30
            height: parent.height - 2.5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#a9aaae" }
                GradientStop { position: 0.5; color: "#d6d7da" }
                GradientStop { position: 1; color: "#a3a4a8" }
            }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 3
            radius: 1.5
            gradient: Gradient {
                GradientStop { position: 0; color: "#dcdde0" }
                GradientStop { position: 1; color: "#9c9da1" }
            }
        }
    }
}
