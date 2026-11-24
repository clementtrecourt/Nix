import QtQuick
import qs.common

// Texte d'aide gris sous un groupe (11 pt), aligné sur les libellés.
Text {
    width: parent ? parent.width - 2 * SStyle.pad : 0
    x: SStyle.pad
    wrapMode: Text.WordWrap
    font.family: Theme.font
    font.pixelSize: SStyle.small
    lineHeight: 14
    lineHeightMode: Text.FixedHeight
    color: SStyle.secondary
}
