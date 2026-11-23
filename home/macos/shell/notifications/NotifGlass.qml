import QtQuick
import qs.common

// Verre des notifications et des widgets.
//
// La teinte est peinte par un Rectangle (valeur exacte, alpha appliqué une seule
// fois) ; le Glass commun, posé par-dessus avec une teinte transparente, ajoute
// le liseré spéculaire, la lueur interne et l'ombre portée. Ainsi la luminosité
// du verre ne dépend pas de la façon dont le shader de Glass traite l'alpha des
// couleurs (Qt les lui passe déjà prémultipliées : une teinte claire y sortait
// gris foncé).
Item {
    id: root

    property real radius: 22
    property color tint: Theme.glass
    property bool shadowEnabled: true
    property real shadowBlur: 1.0
    property int shadowOffset: 8
    // Deux ombres superposées (carte + lamelle, widget + carte) doivent rester
    // sous ignore_alpha (0.05) de Hyprland : sinon halo flouté autour du verre.
    property real shadowMax: 0.024
    default property alias content: contentItem.data

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tint
        antialiasing: true
    }

    Glass {
        anchors.fill: parent
        radius: root.radius
        tint: "transparent"
        shadowEnabled: root.shadowEnabled
        shadowBlur: root.shadowBlur
        shadowOffset: root.shadowOffset
        shadowMax: root.shadowMax
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }
}
