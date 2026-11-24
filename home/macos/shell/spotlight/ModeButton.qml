import QtQuick
import qs.common

// Bouton de mode rond (Applications, Fichiers, Actions, Presse-papiers) :
// goutte Liquid Glass de la hauteur du champ, avec un symbole. Au survol, le
// verre s'éclaircit et le champ affiche le nom du mode et son raccourci
// (« Applications  ⌘ 1 ») : Tahoe n'utilise pas d'info-bulle ici.
Item {
    id: root

    property string symbol
    property bool forceHover: false

    signal clicked()

    width: Metrics.buttonSize
    height: Metrics.buttonSize

    readonly property bool hovered: mouse.containsMouse || forceHover

    Glass {
        id: glass
        anchors.fill: parent
        radius: width / 2
        // Même verre que la capsule (cf. Spotlight.glassTint)
        tint: Theme.dark ? Qt.rgba(0.09, 0.09, 0.10, 0.64) : Qt.rgba(1, 1, 1, 0.62)
        // Ombre propre légère (gouttes détachées de la capsule)
        shadowBlur: 0.9
        shadowOffset: 6
        shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.24 : 0.10)
        // Le bouton s'enfonce légèrement à l'appui (ressort)
        scale: mouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

        // Survol : le verre devient plus clair (plus lumineux en mode sombre)
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "white"
            opacity: root.hovered ? (Theme.dark ? 0.12 : 0.40) : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
        Symbol {
            anchors.centerIn: parent
            name: root.symbol
            size: Metrics.buttonGlyphSize
            color: Theme.dark ? "#e6e6eb" : "#46464b"
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
