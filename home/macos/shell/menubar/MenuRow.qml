import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common

// Une ligne de menu Tahoe : [coche / picto] Libellé ........ ⇧⌘ Z  ›
// La géométrie des colonnes (textX, modsW, keyW) est commune à tout le menu et
// fournie par MenuPanel pour que les raccourcis soient alignés.
Item {
    id: row

    // Élément normalisé (voir MenuPanel.normalize)
    property var entry: ({})
    property bool highlighted: false
    property bool flashOff: false
    property real textX: 14
    property real modsW: 0
    property real keyW: 0
    property bool hasSubmenu: !!entry.hasSubmenu

    readonly property bool isSeparator: !!entry.separator
    readonly property bool isHeader: !!entry.header
    readonly property bool isEnabled: entry.enabled !== false && !isSeparator && !isHeader
    readonly property bool lit: highlighted && isEnabled && !flashOff

    // Couleurs : blanc sur la surbrillance bleue, sinon couleurs système
    readonly property color fg: lit ? Theme.menuHighlightText : (isEnabled ? Theme.label : Theme.labelTertiary)
    readonly property color fgSecondary: lit ? Theme.menuHighlightText : (isEnabled ? Theme.labelSecondary : Theme.labelTertiary)

    implicitHeight: isSeparator ? 11 : (isHeader ? 22 : 24)

    signal hovered()
    signal clicked()

    // Surbrillance bleue arrondie, en retrait de 5 pt des bords du menu
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        radius: Theme.radiusMenuItem
        color: Theme.menuHighlight
        visible: row.lit
    }

    // Séparateur : filet fin aligné sur les marges du texte
    Rectangle {
        visible: row.isSeparator
        anchors.verticalCenter: parent.verticalCenter
        x: 14
        width: parent.width - 28
        height: 1
        color: Theme.separator
    }

    // Coche (état), losange (fenêtre placée dans le Dock) ou picto
    Item {
        id: lead
        visible: !row.isSeparator && !row.isHeader
        x: 14
        width: 16
        height: parent.height

        Symbol {
            anchors.centerIn: parent
            visible: !!row.entry.checked
            name: "checkmark"
            size: 12
            color: row.fg
        }
        Text {
            anchors.centerIn: parent
            visible: !row.entry.checked && !!row.entry.minimized
            text: "◆"
            font.pixelSize: 9
            color: row.fg
        }
        Symbol {
            anchors.centerIn: parent
            visible: !row.entry.checked && !row.entry.minimized && !!row.entry.icon
            name: row.entry.icon ?? ""
            size: 15
            color: row.fg
        }
        IconImage {
            anchors.centerIn: parent
            visible: !row.entry.checked && !row.entry.minimized && !row.entry.icon && !!row.entry.iconSource
            source: row.entry.iconSource ?? ""
            implicitSize: 16
            opacity: row.isEnabled ? 1 : 0.4
        }
    }

    Text {
        id: label
        visible: !row.isSeparator
        x: row.isHeader ? 14 : row.textX
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: row.isHeader ? 1 : 0
        width: parent.width - x - 14 - (row.modsW + row.keyW) - (row.hasSubmenu ? 20 : 0)
        elide: Text.ElideRight
        text: row.entry.text ?? ""
        textFormat: Text.PlainText
        font.family: Theme.font
        font.pixelSize: row.isHeader ? 11 : Theme.fontSize
        font.weight: row.isHeader ? Font.DemiBold : Font.Normal
        color: row.isHeader ? Theme.labelSecondary : row.fg
    }

    // Chemin du menu (résultats de recherche du menu Aide)
    Text {
        visible: !!row.entry.pathText
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 14
        text: row.entry.pathText ?? ""
        font.family: Theme.font
        font.pixelSize: Theme.fontSizeSmall
        color: row.fgSecondary
    }

    // Raccourci : modificateurs alignés à droite contre la colonne de la touche
    Text {
        visible: !!row.entry.mods
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: keyBox.left
        anchors.rightMargin: 1
        text: row.entry.mods ?? ""
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        color: row.fgSecondary
    }
    Item {
        id: keyBox
        anchors.right: parent.right
        anchors.rightMargin: 14
        width: row.keyW
        height: parent.height

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            // La touche "fn" s'affiche avec le globe, comme sur les claviers Apple
            Symbol {
                visible: !!row.entry.globe
                anchors.verticalCenter: parent.verticalCenter
                name: "globe"
                size: 12
                color: row.fgSecondary
            }
            Text {
                text: row.entry.key ?? ""
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                color: row.fgSecondary
            }
        }
    }

    // Chevron de sous-menu
    Symbol {
        visible: row.hasSubmenu
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 14
        name: "chevron.right"
        size: 10
        color: row.fgSecondary
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        enabled: !row.isSeparator && !row.isHeader
        onEntered: row.hovered()
        onPositionChanged: if (!row.highlighted) row.hovered()
        onClicked: row.clicked()
    }
}
