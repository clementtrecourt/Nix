import QtQuick
import qs.common

// Symbol (common/Symbol.qml) qui respecte l'alpha de sa couleur : la
// colorisation de MultiEffect ignore l'alpha de colorizationColor, si bien
// qu'un picto « grisé » (labelTertiary, labelSecondary) sortait en plein blanc.
// On colorise avec la couleur opaque et on reporte l'alpha sur l'opacité.
Symbol {
    id: root

    property color tint: Theme.label

    color: Qt.rgba(tint.r, tint.g, tint.b, 1)
    opacity: tint.a
}
