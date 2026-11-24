import QtQuick
import qs.common

// Bouton × des notifications macOS : pastille de verre ronde qui apparaît au
// survol de la carte. En mode `clearAll` (pile de notifications), survoler le ×
// l'allonge en capsule « Clear All », comme sur macOS.
Item {
    id: btn

    property bool shown: false
    property bool clearAll: false
    readonly property bool containsMouse: mouse.containsMouse
    readonly property bool expanded: clearAll && shown && (mouse.containsMouse || NotifStore.debugClearAll)
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

    NotifGlass {
        anchors.fill: parent
        radius: height / 2
        tint: Theme.dark ? Qt.rgba(0.20, 0.20, 0.21, 0.80) : Qt.rgba(0.97, 0.97, 0.98, 0.85)
        // Pas d'ombre : elle s'ajouterait à celle de la carte (halo flouté Hyprland)
        shadowEnabled: false
    }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: mouse.pressed ? Theme.fillHover : "transparent"
    }

    Symbol {
        anchors.centerIn: parent
        name: "xmark"
        // Croix de ~8 pt pour une pastille de 20 pt (image Apple, macOS 26)
        size: Math.round(16 + (btn.size - 20) * 0.25)
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(0, 0, 0, 0.62)
        opacity: btn.expanded ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }
    Text {
        id: label
        anchors.centerIn: parent
        text: "Clear All"
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
