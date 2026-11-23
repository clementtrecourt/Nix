import QtQuick
import qs.common

// Fond procédural "Tahoe" (vagues de verre), variante claire / sombre suivant
// Theme.dark avec un fondu (comme macOS au changement d'apparence).
ShaderEffect {
    id: root

    property bool darkMode: Theme.dark
    property real aspect: width / Math.max(1, height)
    property real dark: darkMode ? 1 : 0

    Behavior on dark {
        NumberAnimation { duration: 900; easing.type: Easing.InOutQuad }
    }

    fragmentShader: Qt.resolvedUrl("shaders/tahoe.frag.qsb")
}
