import QtQuick
import qs.common

// Plaque du Dock : verre Liquid Glass commun (Glass) + détails propres au Dock
// Tahoe relevés sur les captures : liseré spéculaire de 1 px en haut et en bas,
// léger dégradé vertical (plus clair en haut), contour extérieur sombre très fin.
Item {
    id: root
    property real radius: 20

    Glass {
        anchors.fill: parent
        radius: root.radius
        shadowBlur: 0.9
        shadowOffset: 6
        shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.30 : 0.14)
    }

    // Dégradé interne : la lumière vient du haut
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.10) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
}
