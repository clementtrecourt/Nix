import QtQuick
import qs.common

// Fond procédural "Tahoe" (vagues de verre), variante claire / sombre suivant
// Theme.dark avec un fondu (comme macOS au changement d'apparence).
ShaderEffect {
    id: root

    property bool darkMode: Theme.dark
    property real aspect: width / Math.max(1, height)
    property real dark: darkMode ? 1 : 0
    // 1 pixel en coordonnées de texture (finesse de la lèvre du verre)
    property real pxv: 1 / Math.max(1, height)

    Behavior on dark {
        NumberAnimation { duration: 900; easing.type: Easing.InOutQuad }
    }

    fragmentShader: Qt.resolvedUrl("shaders/tahoe.frag.qsb")
}
