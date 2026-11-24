import QtQuick
import qs.common

// Libellé de la barre de menus (SF Pro 13 pt -> Inter 13 px). Posé sur un y
// ENTIER (centrage par ancre = demi-pixels possibles, texte flou à l'échelle 1) ;
// `yOffset` règle la hauteur des capitales sur celle de Tahoe.
Text {
    property real yOffset: -1
    y: parent ? Math.round((parent.height - height) / 2 + yOffset) : 0
    font.family: Theme.font
    font.pixelSize: Theme.fontSizeMenuBar
    font.weight: Font.Normal
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    Behavior on color { ColorAnimation { duration: 300 } }
}
