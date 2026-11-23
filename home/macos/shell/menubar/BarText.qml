import QtQuick
import qs.common

// Libellé de la barre de menus (SF Pro 13 pt -> Inter 13 px)
Text {
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    font.family: Theme.font
    font.pixelSize: Theme.fontSizeMenuBar
    font.weight: Font.Normal
    textFormat: Text.PlainText
    renderType: Text.CurveRendering
    Behavior on color { ColorAnimation { duration: 300 } }
}
