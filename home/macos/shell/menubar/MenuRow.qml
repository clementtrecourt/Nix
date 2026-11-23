import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common

// Une ligne de menu Tahoe : [coche / picto] Libellé ........ ⇧⌘ Z  ›
// La géométrie des colonnes (textX, modsW, keyW) est commune à tout le menu et
// fournie par MenuPanel pour que les raccourcis soient alignés.
// Variantes : séparateur, intitulé de section, ligne d'information (titre en
// gras + valeur à droite), interrupteur, réseau Wi-Fi (pastille ronde).
Item {
    id: row

    // Élément normalisé (voir MenuPanel.normalize)
    property var entry: ({})
    property bool highlighted: false
    property bool flashOff: false
    property real textX: 16
    property real modsW: 0
    property real keyW: 0
    // Marges mesurées sur les captures Tahoe (2x) : filets et intitulés à 16 pt
    // des bords, raccourcis et chevrons à 16 pt du bord droit, centre du picto
    // à 23 pt, texte à 37 pt.
    readonly property real edge: 16
    readonly property real leadX: 15
    // Écart entre les modificateurs et la touche, et entre deux modificateurs
    readonly property real modsGap: 3
    readonly property real modsSpacing: 2
    // Section dépliable (« Autres réseaux » du menu Wi-Fi) : dépliée ?
    property bool expanded: false
    property bool hasSubmenu: !!entry.hasSubmenu
    // État local de l'interrupteur (basculé sans fermer le menu)
    property bool toggleOn: !!entry.toggle

    readonly property bool isSeparator: !!entry.separator
    readonly property bool isHeader: !!entry.header
    readonly property bool isInfo: !!entry.info
    readonly property bool isNetwork: !!entry.network
    readonly property bool hasToggle: entry.toggle !== undefined && entry.toggle !== null
    readonly property bool isEnabled: entry.enabled !== false && !isSeparator && !isHeader && !isInfo
    readonly property bool lit: highlighted && isEnabled && !flashOff && !hasToggle

    // Couleurs : blanc sur la surbrillance bleue, sinon couleurs système
    readonly property color fg: lit ? Theme.menuHighlightText
        : isInfo ? (entry.secondary ? Theme.labelSecondary : Theme.label)
        : (isEnabled ? Theme.label : Theme.labelTertiary)
    readonly property color fgSecondary: lit ? Theme.menuHighlightText : (isEnabled || isInfo ? Theme.labelSecondary : Theme.labelTertiary)

    implicitHeight: isSeparator ? 11 : isHeader ? 24 : isNetwork ? 32 : 24

    signal hovered()
    signal clicked()

    // Surbrillance bleue arrondie, en retrait de 5 pt des bords du menu
    // (les lignes à interrupteur ont un survol gris discret, comme sur macOS)
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        radius: Theme.radiusMenuItem
        color: row.hasToggle ? Theme.fill : Theme.menuHighlight
        visible: row.lit || (row.hasToggle && row.highlighted && row.isEnabled)
    }

    // Séparateur : filet fin aligné sur les marges du texte
    Rectangle {
        visible: row.isSeparator
        anchors.verticalCenter: parent.verticalCenter
        x: row.edge
        width: parent.width - 2 * row.edge
        height: 1
        color: Theme.separator
    }

    // Coche (état), losange (fenêtre placée dans le Dock) ou picto
    Item {
        id: lead
        visible: !row.isSeparator && !row.isHeader && !row.isNetwork
        x: row.leadX
        width: 16
        height: parent.height

        Glyph {
            anchors.centerIn: parent
            visible: !!row.entry.checked
            name: "checkmark"
            size: 12
            tint: row.fg
        }
        Text {
            anchors.centerIn: parent
            visible: !row.entry.checked && !!row.entry.minimized
            text: "◆"
            font.pixelSize: 9
            color: row.fg
        }
        Glyph {
            anchors.centerIn: parent
            visible: !row.entry.checked && !row.entry.minimized && !!row.entry.icon
            name: row.entry.icon ?? ""
            size: 15
            tint: row.fg
        }
        IconImage {
            anchors.centerIn: parent
            visible: !row.entry.checked && !row.entry.minimized && !row.entry.icon && !!row.entry.iconSource
            source: row.entry.iconSource ?? ""
            implicitSize: 16
            opacity: row.isEnabled ? 1 : 0.4
        }
    }

    // Réseau Wi-Fi : pastille ronde (bleue si connecté) avec le picto de signal
    Rectangle {
        visible: row.isNetwork
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        radius: 13
        color: row.entry.connected ? Theme.accent : Theme.fillHover
        WifiGlyph {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 0.5
            scale: 0.78
            level: row.entry.wifiLevel ?? 3
            color: row.entry.connected ? "white" : Theme.label
        }
    }

    Text {
        id: label
        visible: !row.isSeparator
        x: row.isHeader ? row.edge : row.isNetwork ? 46 : row.textX
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: row.isHeader ? 1.5 : 0
        width: parent.width - x - row.edge - (row.modsW + row.keyW) - (row.hasSubmenu || row.entry.disclosure ? 20 : 0)
            - (row.hasToggle ? 40 : 0) - (row.entry.pathText ? pathLabel.implicitWidth + 12 : 0)
            - (row.entry.locked ? 20 : 0)
        elide: Text.ElideRight
        text: row.entry.text ?? ""
        textFormat: Text.PlainText
        font.family: Theme.font
        renderType: Text.CurveRendering
        font.pixelSize: row.isHeader ? 11 : Theme.fontSize
        font.weight: row.isHeader || row.entry.bold ? Font.DemiBold : Font.Normal
        color: row.isHeader ? Theme.labelSecondary : row.fg
    }

    // Valeur à droite (pourcentage de batterie, chemin des résultats de recherche)
    Text {
        id: pathLabel
        visible: !!row.entry.pathText
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: row.edge
        text: row.entry.pathText ?? ""
        font.family: Theme.font
        renderType: Text.CurveRendering
        font.pixelSize: row.isInfo ? Theme.fontSize : Theme.fontSizeSmall
        color: row.fgSecondary
    }

    // Cadenas des réseaux sécurisés
    Glyph {
        visible: !!row.entry.locked
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: row.edge
        name: "lock.fill"
        size: 11
        tint: row.fgSecondary
    }

    // Interrupteur Tahoe (capsule bleue quand activé)
    Rectangle {
        id: sw
        visible: row.hasToggle
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: row.edge
        width: 32
        height: 18
        radius: 9
        color: row.toggleOn ? Theme.accent : Theme.fillHover
        Behavior on color { ColorAnimation { duration: 160 } }
        Rectangle {
            width: 22
            height: 16
            radius: 8
            y: 1
            x: row.toggleOn ? parent.width - width - 1 : 1
            color: "white"
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        }
    }

    // Raccourci : modificateurs (espacés un à un, « ⌃ ⇧ 🌐 ◀ ») alignés à droite
    // contre la colonne de la touche
    Row {
        visible: !!row.entry.mods || !!row.entry.globe
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: keyBox.left
        anchors.rightMargin: row.modsGap
        spacing: row.modsSpacing
        Repeater {
            model: Array.from(row.entry.mods ?? "").concat(row.entry.globe ? ["🌐"] : [])
            delegate: Item {
                id: modItem
                required property string modelData
                readonly property bool isGlobe: modelData === "🌐"
                implicitWidth: isGlobe ? 12 : modText.implicitWidth
                implicitHeight: row.height
                Text {
                    id: modText
                    visible: !modItem.isGlobe
                    anchors.verticalCenter: parent.verticalCenter
                    text: modItem.isGlobe ? "" : modItem.modelData
                    font.family: Theme.font
                    renderType: Text.CurveRendering
                    font.pixelSize: Theme.fontSize
                    color: row.fgSecondary
                }
                // La touche "fn" s'affiche avec le globe, comme sur les claviers Apple
                Glyph {
                    visible: modItem.isGlobe
                    anchors.verticalCenter: parent.verticalCenter
                    name: "globe"
                    size: 12
                    tint: row.fgSecondary
                }
            }
        }
    }
    Item {
        id: keyBox
        anchors.right: parent.right
        anchors.rightMargin: row.edge
        width: row.keyW
        height: parent.height

        // Échap : glyphe ⎋ dessiné (celui d'Inter ne ressemble pas à celui d'Apple)
        Glyph {
            visible: row.entry.key === "⎋"
            anchors.verticalCenter: parent.verticalCenter
            name: "escape"
            size: 12
            tint: row.fgSecondary
        }
        Text {
            visible: row.entry.key !== "⎋"
            anchors.verticalCenter: parent.verticalCenter
            text: row.entry.key ?? ""
            font.family: Theme.font
            renderType: Text.CurveRendering
            font.pixelSize: Theme.fontSize
            color: row.fgSecondary
        }
    }

    // Chevron de sous-menu ; pour une section dépliable, il pivote vers le bas
    // quand la section est ouverte (Wi-Fi > Autres réseaux sur Tahoe)
    Glyph {
        visible: row.hasSubmenu || !!row.entry.disclosure
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: row.edge
        name: "chevron.right"
        size: 10
        tint: row.hasSubmenu ? row.fgSecondary : row.fg
        rotation: row.entry.disclosure && row.expanded ? 90 : 0
        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        enabled: !row.isSeparator && !row.isHeader && !row.isInfo
        onEntered: row.hovered()
        onPositionChanged: if (!row.highlighted) row.hovered()
        onClicked: row.clicked()
    }
}
