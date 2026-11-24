import QtQuick
import qs.common

// Ligne de résultat de Spotlight (Tahoe) : icône (dessin de 30 pt), titre et
// détail sur deux lignes (ou titre seul, centré : vue Applications en liste),
// information à droite (date), « Add quick keys » (vue Actions), action « tab »
// de la ligne choisie, ou bouton « copier » rond (presse-papiers). La ligne sélectionnée est une capsule GRISE neutre en
// retrait des bords du panneau, texte inchangé (captures MacRumors
// « search-spotlight-location », « spotlight-kind » : pas d'accent bleu).
//
// Élément { header: true, title } : en-tête de section en gras avec un filet
// dessous (vue Actions : « Suggestions », nom de l'app).
// Élément { separator: true } : trait entre les apps suggérées et la liste
// de A à Z (vue Applications en liste, MacMagazine « lista »).
Item {
    id: root

    required property var modelData
    required property int index
    property bool selected: false
    // ⌘ maintenu : affiche le chemin complet des fichiers (comme Tahoe)
    property bool cmdHeld: false

    signal clicked()
    signal doubleClicked()
    signal secondaryAction()   // bouton « copier » du presse-papiers
    // Le pointeur a BOUGÉ sur la ligne : comme Spotlight, le survol sélectionne
    // (un pointeur immobile sous la liste ne sélectionne rien)
    signal pointed(real sx, real sy)

    readonly property bool isHeader: !!modelData.header
    readonly property bool isSeparator: !!modelData.separator
    readonly property bool isClip: modelData.kind === "clip"
    readonly property bool showPath: modelData.kind === "file" && cmdHeld && selected
    readonly property string detail: showPath ? (modelData.location ?? "") : (modelData.subtitle ?? "")
    // Dossier parent (fichiers) : « · <dossier> » précédé d'un petit dossier
    readonly property string folder: !showPath && modelData.kind === "file" ? (modelData.folder ?? "") : ""

    // Sélection : voile neutre (plus clair en sombre, plus sombre en clair)
    readonly property color selColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.075)
    // Détail : ≈ 35 % de noir en clair (« Messages », Cult of Mac « Spotlight-Actions »)
    readonly property color detailColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.50) : Qt.rgba(0, 0, 0, 0.36)
    // Action « tab » de la ligne choisie (« Search <dossier> »)
    readonly property bool showTab: selected && !!modelData.tabHint && !cmdHeld

    width: ListView.view ? ListView.view.width : 0
    height: isHeader ? Metrics.headerHeight : isSeparator ? 26 : Metrics.rowHeight

    // ---- Trait (apps suggérées / liste de A à Z) ----
    Rectangle {
        visible: root.isSeparator
        x: Metrics.sidePad
        y: 24
        width: parent.width - 2 * Metrics.sidePad
        height: 1
        color: Theme.separator
    }

    // ---- En-tête de section ----
    Item {
        anchors.fill: parent
        visible: root.isHeader
        // Texte centré à 21 pt du haut, trait à 34 pt (Cult of Mac « Spotlight-Actions »)
        Text {
            x: Metrics.sidePad
            y: Math.round(21 - height / 2)
            text: root.modelData.title ?? ""
            font.family: Theme.font
            font.pixelSize: Metrics.headerFontSize
            font.weight: Font.Bold
            color: Theme.label
        }
        Rectangle {
            id: headerRule
            x: Metrics.sidePad
            y: parent.height - 1
            width: parent.width - 2 * Metrics.sidePad
            height: 1
            color: Theme.separator
        }
    }

    Rectangle {
        id: bg
        visible: !root.isHeader && !root.isSeparator
        anchors.fill: parent
        anchors.leftMargin: Metrics.rowInset
        anchors.rightMargin: Metrics.rowInset
        radius: Metrics.rowRadius
        color: root.selected ? root.selColor : "transparent"
        Behavior on color { ColorAnimation { duration: 80 } }

        // Icône : dessin à ≈ 20 pt du bord du panneau (cadre 34, marge 2)
        ItemIcon {
            id: icon
            x: 18 - Metrics.rowInset
            anchors.verticalCenter: parent.verticalCenter
            size: Metrics.rowIcon
            item: root.modelData
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 71 - Metrics.rowInset
            anchors.right: trailing.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                width: parent.width
                text: root.modelData.title ?? ""
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
                font.family: Theme.font
                font.pixelSize: Metrics.titleSize
                color: Theme.label
            }
            Row {
                width: parent.width
                visible: root.detail.length > 0 || root.folder.length > 0
                spacing: 0
                Text {
                    id: detailText
                    width: Math.min(implicitWidth, parent.width - (folderRow.visible ? Math.min(folderRow.implicitWidth, parent.width * 0.4) : 0))
                    text: root.detail + (root.folder ? " · " : "")
                    elide: root.showPath ? Text.ElideMiddle : Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                    font.family: Theme.font
                    font.pixelSize: Metrics.detailSize
                    color: root.detailColor
                }
                Row {
                    id: folderRow
                    visible: root.folder.length > 0
                    spacing: 4
                    width: Math.min(implicitWidth, parent.width - detailText.width)
                    clip: true
                    Symbol {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "folder"
                        size: Metrics.detailSize - 1
                        // (couleur opaque : Symbol recolore mal l'alpha)
                        color: Theme.dark ? "#8e8e93" : "#8a8a8e"
                    }
                    Text {
                        text: root.folder
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                        font.family: Theme.font
                        font.pixelSize: Metrics.detailSize
                        color: root.detailColor
                    }
                }
            }
        }

        // À droite : information courte, action « tab », « Add quick keys »,
        // ou bouton copier (presse-papiers). Bord droit à 19 pt du panneau.
        Item {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: Metrics.sidePad - Metrics.rowInset
            anchors.verticalCenter: parent.verticalCenter
            width: root.isClip ? Metrics.copyButton
                 : root.showTab ? tabRow.implicitWidth
                 : root.modelData.quickKeys ? quickKeys.width
                 : trailText.implicitWidth
            height: Metrics.copyButton

            Text {
                id: trailText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.isClip && !root.showTab && !root.modelData.quickKeys && text.length > 0
                text: root.modelData.trailing ?? ""
                font.family: Theme.font
                font.pixelSize: 14
                color: root.detailColor
            }

            // « Search recent receipts and invoices  [tab] » (MacRumors
            // « search-spotlight-location ») : texte 11 px, touche en capsule
            Row {
                id: tabRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showTab
                spacing: 9
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.modelData.tabHint ?? ""
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.letterSpacing: 0.3
                    color: root.detailColor
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: tabText.implicitWidth + 12
                    height: 18
                    radius: 5
                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.08)
                    Text {
                        id: tabText
                        anchors.centerIn: parent
                        text: "tab"
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.70)
                    }
                }
            }

            // « Add quick keys » : capsule grise discrète, texte 11 px
            // (Cult of Mac « Spotlight-Actions » : 92 x 18 pt, rayon ≈ 5)
            Rectangle {
                id: quickKeys
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.isClip && !root.showTab && !!root.modelData.quickKeys
                width: qkText.implicitWidth + 14
                height: Metrics.quickKeysHeight
                radius: 5
                color: qkMouse.containsMouse ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.09))
                                             : (Theme.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.05))
                Text {
                    id: qkText
                    anchors.centerIn: parent
                    text: "Add quick keys"
                    font.family: Theme.font
                    font.pixelSize: Metrics.quickKeysFontSize
                    font.weight: Font.Medium
                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.38) : Qt.rgba(0, 0, 0, 0.30)
                }
                MouseArea {
                    id: qkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            // Bouton copier rond de 26 pt, symbole plein (Tahoe : toujours
            // visible sur chaque élément, Cult of Mac « Spotlight-Clipboard »)
            Rectangle {
                anchors.fill: parent
                visible: root.isClip
                radius: width / 2
                color: copyMouse.containsMouse ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.12))
                                               : (Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.07))
                Symbol {
                    anchors.centerIn: parent
                    name: "doc.on.doc.fill"
                    size: 17
                    // (couleur opaque : Symbol recolore mal l'alpha)
                    color: Theme.dark ? "#d6d6db" : "#3a3a3f"
                }
                MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.secondaryAction()
                }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            z: -1
            onClicked: root.clicked()
            onDoubleClicked: root.doubleClicked()
            onPositionChanged: mouse => {
                const p = mapToItem(null, mouse.x, mouse.y);
                root.pointed(p.x, p.y);
            }
        }
    }
}
