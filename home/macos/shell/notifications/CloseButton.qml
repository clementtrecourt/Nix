import QtQuick
import qs.common

// Bouton × des notifications macOS : pastille de verre ronde qui apparaît au
// survol de la carte. En mode `clearAll` (pile de notifications), survoler le ×
// l'allonge en capsule « Tout effacer », comme sur macOS.
Item {
    id: btn

    property bool shown: false
    property bool clearAll: false
    readonly property bool containsMouse: mouse.containsMouse
    readonly property bool expanded: clearAll && mouse.containsMouse
    signal triggered()

    property int size: 20
    width: expanded ? label.implicitWidth + 22 : size
    height: size
    Behavior on width { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }

    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.6
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    Behavior on scale { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

    Glass {
        anchors.fill: parent
        radius: height / 2
        thick: true
        shadowOffset: 2
        shadowBlur: 0.5
    }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: mouse.pressed ? Theme.fillHover : "transparent"
    }

    Symbol {
        anchors.centerIn: parent
        name: "xmark"
        size: 8
        color: Theme.labelSecondary
        opacity: btn.expanded ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }
    Text {
        id: label
        anchors.centerIn: parent
        text: "Tout effacer"
        color: Theme.label
        font.family: Theme.font
        font.pixelSize: 11
        font.weight: Font.Medium
        opacity: btn.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -2
        hoverEnabled: true
        enabled: btn.shown
        onClicked: btn.triggered()
    }
}
