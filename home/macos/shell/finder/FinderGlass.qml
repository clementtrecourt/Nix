import QtQuick
import qs.common

// Verre Liquid Glass des fenêtres du Finder (capsules de la barre d'outils,
// barre latérale) : réfracte la scène de la fenêtre (backdrop "snapshot"),
// mais reste presque opaque comme dans le Finder de Tahoe (voile clair /
// sombre par-dessus, couleur du fond atténuée : Six Colors note que le verre
// du Finder « se voit à peine », MacStories montre seulement un reflet coloré).
LiquidGlass {
    id: g
    // Densité du voile (0 = verre nu, 1 = opaque)
    property real veil: 0.55
    // Couleur du voile : capsules gris clair en sombre (relevé #616568 sur la
    // capture Eclectic Light, Finder sombre de Tahoe), blanc en clair
    property color veilColor: Theme.dark ? Qt.rgba(0.40, 0.40, 0.42, 1) : Qt.rgba(1, 1, 1, 1)

    backdrop: "snapshot"
    windowOrigin: Qt.point(0, 0)
    saturation: 0.9
    overlay: Qt.rgba(veilColor.r, veilColor.g, veilColor.b, veil)
    shadowBlur: 0.75
    shadowOffset: 2
    shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.35 : 0.075)
    rimColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.34) : Qt.rgba(1, 1, 1, 1)
    rimBase: 0.3
    edgeDarken: Theme.dark ? 0.22 : 0.04
    glowColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.6)
    shadeColor: Theme.dark ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(0, 0, 0, 0.015)
}
