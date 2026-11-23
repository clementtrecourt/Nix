import QtQuick
import qs.common

// Bouton de mode rond (Applications, Fichiers, Actions, Presse-papiers) :
// pastille Liquid Glass avec un symbole, info-bulle « Nom ⌘n » au survol.
Item {
    id: root

    property string symbol
    property string label
    property string shortcut
    property bool forceHover: false

    signal clicked()

    width: Metrics.buttonSize
    height: Metrics.buttonSize

    readonly property bool hovered: mouse.containsMouse || forceHover

    Glass {
        id: glass
        anchors.fill: parent
        radius: width / 2
        shadowOffset: 4
        shadowBlur: 0.7
        shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.18 : 0.1)
        // Le bouton s'enfonce légèrement à l'appui (ressort)
        scale: mouse.pressed ? 0.92 : (root.hovered ? 1.06 : 1.0)
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.label
            opacity: root.hovered ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
        Symbol {
            anchors.centerIn: parent
            name: root.symbol
            size: Metrics.glyphSize
            color: Theme.label
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }

    // Info-bulle (apparaît après un court délai, comme AppKit)
    Timer {
        id: tipDelay
        interval: 600
        running: root.hovered
        onRunningChanged: if (!running) tip.shown = false
        onTriggered: tip.shown = true
    }
    Rectangle {
        id: tip
        property bool shown: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 10
        width: tipRow.implicitWidth + 16
        height: 24
        radius: 7
        color: Theme.menuBackground
        border.width: 0.5
        border.color: Theme.glassStroke
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Row {
            id: tipRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: root.label
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.label
            }
            Text {
                text: root.shortcut
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.labelSecondary
            }
        }
    }
}
