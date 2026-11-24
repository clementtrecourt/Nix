import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import qs.common

// Une ligne de menu Tahoe : [coche / picto] Libellé ........ ⇧⌘ Z  ›
// La géométrie des colonnes (cols, modsW, keyW) est commune à tout le menu et
// fournie par MenuPanel pour que les raccourcis soient alignés.
// Variantes : séparateur, intitulé de section, ligne d'information (titre en
// gras + valeur à droite), interrupteur, réseau Wi-Fi (pastille ronde).
Item {
    id: row

    // Élément normalisé (voir MenuPanel.normalize)
    property var entry: ({})
    property bool highlighted: false
    property bool flashOff: false
    // Colonnes : { check, plain, icon, iconText } (voir MenuPanel.metrics)
    property var cols: ({ check: 13, plain: 16, icon: 24, iconText: 38 })
    readonly property real textX: entry.indent ? cols.iconText : cols.plain
    property real modsW: 0
    property real keyW: 0
    // Marges mesurées sur les captures Tahoe (2x) : filets à 16 pt des bords,
    // raccourcis et chevrons à ~17 pt du bord droit.
    readonly property real edge: 16
    readonly property real rightEdge: 17
    // Écart entre les modificateurs et la touche, et entre deux modificateurs :
    // Tahoe colle les glyphes (⇧ 188-199, ⌘ 201,5-212,5, ⌫ 215-226 pt dans le
    // menu Finder de 512pixels : 2,5 pt d'encre à encre) ; les approches
    // latérales des glyphes d'Inter suffisent à cet écart.
    readonly property real modsGap: 1
    readonly property real modsSpacing: 0
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
    // Élément dont le sous-menu ouvert a la sélection : surbrillance atténuée
    // (accent à ~22 %, texte normal : HIG « Menus » de Tahoe, clair et sombre)
    property bool muted: false
    readonly property bool lit: highlighted && isEnabled && !flashOff && !hasToggle && !muted

    // Couleurs : blanc sur la surbrillance bleue, sinon couleurs système
    // (texte des menus Tahoe : ~85 % de noir / de blanc, #252525 relevé)
    readonly property color labelColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.86) : Qt.rgba(0, 0, 0, 0.85)
    readonly property color fg: lit ? Theme.menuHighlightText
        : isInfo ? (entry.secondary ? Theme.labelSecondary : labelColor)
        : (isEnabled ? labelColor : Theme.labelTertiary)
    readonly property color fgSecondary: lit ? Theme.menuHighlightText : (isEnabled || isInfo ? Theme.labelSecondary : Theme.labelTertiary)
    // Raccourcis : même gris que le texte grisé (Finder de Tahoe : #B6B6B6)
    readonly property color fgShortcut: lit ? Theme.menuHighlightText
        : Theme.dark ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(0, 0, 0, 0.28)

    implicitHeight: isSeparator ? 11 : isHeader ? 24 : isNetwork ? 32 : 24

    signal hovered()
    signal clicked()

    // Surbrillance bleue arrondie (rayon ~6 pt), en retrait de 5 pt des bords
    // du menu (les lignes à interrupteur ont un survol gris discret)
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        radius: 6
        color: row.hasToggle ? Theme.fill
            : row.muted ? Qt.rgba(Theme.menuSelection.r, Theme.menuSelection.g, Theme.menuSelection.b, 0.22)
            : Theme.menuSelection
        visible: row.lit || (row.muted && row.highlighted) || (row.hasToggle && row.highlighted && row.isEnabled)
    }

    // Séparateur : filet fin aligné sur les marges du texte
    Rectangle {
        visible: row.isSeparator
        anchors.verticalCenter: parent.verticalCenter
        x: row.edge
        width: parent.width - 2 * row.edge
        height: 1
        // (un peu plus marqué que Theme.separator en sombre)
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Theme.separator
    }

    // Coche (état) ou losange (fenêtre placée dans le Dock) : gouttière gauche
    Item {
        visible: !row.isSeparator && !row.isHeader && !row.isNetwork
        x: row.cols.check - width / 2
        width: 14
        height: parent.height

        Glyph {
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
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
    }

    // Picto (SF Symbol ou icône du thème), colonne des pictos
    Item {
        visible: !row.isSeparator && !row.isHeader && !row.isNetwork
        x: row.cols.icon - width / 2
        width: 16
        height: parent.height

        Glyph {
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            visible: !!row.entry.icon
            name: row.entry.icon ?? ""
            size: 15
            tint: row.fg
        }
        IconImage {
            anchors.centerIn: parent
            visible: !row.entry.icon && !!row.entry.iconSource
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
        x: row.isHeader ? row.cols.plain : row.isNetwork ? 46 : row.textX
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: row.isHeader ? 1.5 : 0
        width: parent.width - x - row.rightEdge - (row.modsW + row.keyW) - (row.hasSubmenu || row.entry.disclosure ? 20 : 0)
            - (row.hasToggle ? 40 : 0) - (row.entry.pathText ? pathLabel.implicitWidth + 12 : 0)
            - (row.entry.locked ? 20 : 0)
        elide: Text.ElideRight
        text: row.entry.text ?? ""
        textFormat: Text.PlainText
        font.family: Theme.font
        renderType: Text.NativeRendering
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
        renderType: Text.NativeRendering
        font.pixelSize: row.isInfo ? Theme.fontSize : Theme.fontSizeSmall
        color: row.fgSecondary
    }

    // Cadenas des réseaux sécurisés
    Glyph {
        visible: !!row.entry.locked
        y: Math.round((parent.height - height) / 2)
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
                    renderType: Text.NativeRendering
                    font.pixelSize: Theme.fontSize
                    color: row.fgShortcut
                }
                // La touche "fn" s'affiche avec le globe, comme sur les claviers Apple
                Glyph {
                    visible: modItem.isGlobe
                    anchors.verticalCenter: parent.verticalCenter
                    name: "globe"
                    size: 12
                    tint: row.fgShortcut
                }
            }
        }
    }
    Item {
        id: keyBox
        anchors.right: parent.right
        anchors.rightMargin: row.rightEdge
        width: row.keyW
        height: parent.height

        // Échap : glyphe ⎋ dessiné (celui d'Inter ne ressemble pas à celui d'Apple)
        Glyph {
            visible: row.entry.key === "⎋"
            anchors.verticalCenter: parent.verticalCenter
            name: "escape"
            size: 12
            tint: row.fgShortcut
        }
        Text {
            visible: row.entry.key !== "⎋"
            anchors.verticalCenter: parent.verticalCenter
            text: row.entry.key ?? ""
            font.family: Theme.font
            renderType: Text.NativeRendering
            font.pixelSize: Theme.fontSize
            color: row.fgShortcut
        }
    }

    // Chevron de sous-menu ; pour une section dépliable, il pivote vers le bas
    // quand la section est ouverte (Wi-Fi > Autres réseaux sur Tahoe).
    // Tahoe : chevron de 5,5 x 9 pt, trait épais (~1,5 pt), couleur du libellé
    // (menu Finder de 512pixels, menu Apple de Jim Nielsen, HIG « Menus »).
    Item {
        visible: row.hasSubmenu || !!row.entry.disclosure
        width: 6
        height: 10
        x: parent.width - row.rightEdge - width
        y: Math.round((parent.height - height) / 2)
        rotation: row.entry.disclosure && row.expanded ? 90 : 0
        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1.6
                strokeColor: row.fg
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: 1; startY: 0.8
                PathLine { x: 5.2; y: 5 }
                PathLine { x: 1; y: 9.2 }
            }
        }
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
