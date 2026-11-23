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
        // Pas d'ombre propre : les ombres de boutons voisins s'additionneraient
        // au-delà du seuil ignore_alpha de Hyprland (0.05) et l'espace entre
        // les gouttes serait flouté. L'ombre diffuse de la capsule suffit.
        shadowEnabled: false
        // Le bouton s'enfonce légèrement à l'appui (ressort)
        scale: mouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

        // Survol : le verre devient plus clair (plus lumineux en mode sombre)
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "white"
            opacity: root.hovered ? (Theme.dark ? 0.14 : 0.45) : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
        Symbol {
            anchors.centerIn: parent
            name: root.symbol
            size: Metrics.buttonGlyphSize
            color: Theme.dark ? "#ececf0" : "#3c3c41"
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
