import QtQuick
import qs.common

// Menu du bouton « ⋯ » (More) de Spotlight (Tahoe). Applications / Fichiers :
// titre grisé « View content as », puis « Grid » / « List » (MacRumors
// « apps-app-macos », MacMagazine « lista » ; Apple Support : « Click the More
// button, then choose Grid or List »). Presse-papiers : « Clear History »
// (Apple Support mchl40d5b86b). « Show iPhone Apps » est omis : pas de recopie
// d'iPhone ici.
// Plaque de verre façon menu AppKit : lignes de 24 pt, colonne de coche,
// surbrillance accent arrondie en retrait de 5 pt, largeur ajustée au texte.
//
// Entrées : { title } (titre de section), { separator: true },
// { text, checked, id } (élément).
Item {
    id: root

    property bool open: false
    property var entries: []
    property int highlighted: -1

    signal picked(string id)

    // Largeur : texte le plus long + colonne de coche (26) + marge droite
    width: Math.max(130, Math.ceil(widest) + 26 + 24)
    property real widest: 0
    function measure() {
        let w = 0;
        for (const e of entries) {
            if (e.separator) continue;
            metrics.font.pixelSize = e.title ? 11 : 13;
            metrics.font.weight = e.title ? Font.DemiBold : Font.Normal;
            metrics.text = e.title ?? e.text;
            w = Math.max(w, metrics.advanceWidth);
        }
        widest = w;
    }
    onEntriesChanged: measure()
    TextMetrics { id: metrics; font.family: Theme.font }

    height: col.implicitHeight + 10
    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.96
    transformOrigin: Item.TopRight
    Behavior on opacity { NumberAnimation { duration: root.open ? 90 : 160 } }
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    onOpenChanged: highlighted = -1

    Glass {
        anchors.fill: parent
        radius: Theme.radiusMenu
        // Le verre réfracte la capture d'écran prise AVANT l'ouverture : le
        // panneau de Spotlight sous le menu n'y figure pas. Voile dense par-
        // dessus (menus AppKit de Tahoe) pour que ce décalage ne se voie pas.
        overlay: Theme.dark ? Qt.rgba(0.17, 0.17, 0.18, 0.90) : Qt.rgba(0.97, 0.97, 0.98, 0.90)
        shadowBlur: 0.8
        shadowOffset: 6
    }

    Column {
        id: col
        x: 5
        y: 5
        width: parent.width - 10
        Repeater {
            model: root.entries
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool isTitle: !!modelData.title
                readonly property bool isSep: !!modelData.separator
                readonly property bool lit: !isTitle && !isSep && (root.highlighted === index || mouse.containsMouse)
                width: col.width
                // Séparateur : 11 pt, trait en retrait (menus AppKit)
                height: isSep ? 11 : 24
                Rectangle {
                    visible: row.isSep
                    x: 9
                    width: parent.width - 18
                    y: 5
                    height: 1
                    color: Theme.separator
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMenuItem - 2
                    color: Theme.menuHighlight
                    visible: row.lit
                }
                Symbol {
                    x: 9
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !row.isTitle && !row.isSep && !!row.modelData.checked
                    name: "checkmark"
                    size: 11
                    color: row.lit ? Theme.menuHighlightText : Theme.label
                }
                // Titre de section : 11 pt demi-gras grisé (« View content as »)
                Text {
                    x: 26
                    visible: !row.isSep
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.title ?? row.modelData.text ?? ""
                    font.family: Theme.font
                    font.pixelSize: row.isTitle ? 11 : 13
                    font.weight: row.isTitle ? Font.DemiBold : Font.Normal
                    color: row.lit ? Theme.menuHighlightText : (row.isTitle ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(0, 0, 0, 0.38)) : Theme.label)
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: !row.isTitle && !row.isSep
                    enabled: !row.isTitle && !row.isSep
                    onClicked: root.picked(row.modelData.id)
                }
            }
        }
    }
}
