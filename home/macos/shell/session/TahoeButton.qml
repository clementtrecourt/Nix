import QtQuick
import qs.common

// Bouton poussoir Tahoe : bouton par défaut en couleur d'accent, bouton
// secondaire en remplissage neutre translucide, assombri à l'appui.
// Forme (captures Tahoe 26) : capsule dans les alertes (28 pt), rectangle aux
// coins de 6 pt pour les boutons « regular » des fenêtres (24 pt : More Info…,
// Force Quit) -> `radius`.
Item {
    id: root

    property string text
    property bool isDefault: false
    property bool destructive: false
    property bool enabled: true
    property int fontSize: 13
    property real radius: height / 2
    readonly property real labelWidth: label.implicitWidth
    signal clicked()

    implicitHeight: 28
    implicitWidth: Math.max(80, label.implicitWidth + 32)
    opacity: enabled ? 1 : 0.45

    readonly property color base: isDefault
        // Bleu des boutons par défaut Tahoe (#3478F6 mesuré sur les alertes)
        ? (destructive ? Theme.red : (Theme.dark ? "#2F7BF5" : "#3478F6"))
        : (Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.07))

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.radius
        color: root.base
    }
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "black"
        opacity: ma.pressed ? (root.isDefault ? 0.18 : 0.10) : 0
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.font
        font.pixelSize: root.fontSize
        font.weight: root.isDefault ? Font.Medium : Font.Normal
        color: root.isDefault ? "white" : Theme.label
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
