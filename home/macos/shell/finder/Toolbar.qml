import QtQuick
import Quickshell
import qs.common

// Barre d'outils unifiée de Tahoe (sans fond ni séparateur) : capsule
// Précédent/Suivant, titre du dossier (15 pt gras), puis à droite les capsules
// Présentations (Icônes, Liste, Colonnes, Galerie), Grouper, Partager / Tags /
// Action « … », et le bouton rond Rechercher qui se déploie en champ.
// Mesures : gros plan MacStories (2x) et capture 2x de Daring Fireball.
Item {
    id: root

    required property var fw
    property Item backdropItem: null

    function focusSearch() { searchInput.forceActiveFocus(); }

    // Marge gauche : feux tricolores quand la barre latérale est masquée
    readonly property real leftX: fw.showSidebar ? 8.5 : FStyle.lightX + 3 * FStyle.lightSize + 2 * FStyle.lightGap + 14
    // Place disponible : présentations repliées en un bouton si trop étroit
    readonly property bool compact: width < 640
    readonly property var viewSymbols: ({ icon: "square.grid.2x2", list: "list.bullet", column: "rectangle.split.3x1", gallery: "finder.gallery" })
    readonly property var hasSel: fw.selection.length > 0

    ToolCapsule {
        id: nav
        x: root.leftX
        y: FStyle.capsuleY
        backdropItem: root.backdropItem
        ToolButton {
            symbol: "chevron.left"
            symbolSize: 15
            buttonWidth: 32
            enabledButton: root.fw.canGoBack
            onClicked: root.fw.goBack()
        }
        Rectangle {
            width: 1
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            color: FStyle.gridLine
        }
        ToolButton {
            symbol: "chevron.right"
            symbolSize: 15
            buttonWidth: 32
            enabledButton: root.fw.canGoForward
            onClicked: root.fw.goForward()
        }
    }

    Text {
        id: titleText
        x: nav.x + nav.width + 14
        width: Math.max(0, right.x - x - 12)
        anchors.verticalCenter: nav.verticalCenter
        text: Fs.displayName(root.fw.path)
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: FStyle.titleSize
        font.weight: Font.Bold
        color: root.fw.active ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(0, 0, 0, 0.80))
                              : (Theme.dark ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(0, 0, 0, 0.35))
    }

    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: FStyle.capsuleY
        spacing: FStyle.capsuleGap

        // ---- Présentations ----
        ToolCapsule {
            visible: !root.compact
            backdropItem: root.backdropItem
            Repeater {
                model: ["icon", "list", "column", "gallery"]
                Item {
                    required property string modelData
                    required property int index
                    width: FStyle.buttonWidth
                    height: FStyle.buttonHeight
                    ToolButton {
                        anchors.fill: parent
                        symbol: root.viewSymbols[parent.modelData]
                        selected: root.fw.viewMode === parent.modelData
                        onClicked: root.fw.viewMode = parent.modelData
                    }
                    // Séparateur entre deux boutons non choisis
                    Rectangle {
                        readonly property var order: ["icon", "list", "column", "gallery"]
                        visible: parent.index > 0 && root.fw.viewMode !== parent.modelData
                                 && root.fw.viewMode !== order[parent.index - 1]
                        width: 1
                        height: 18
                        x: -0.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: FStyle.gridLine
                    }
                }
            }
        }
        // Repliées : un bouton (présentation courante + ⌃⌄) qui ouvre un menu
        ToolCapsule {
            visible: root.compact
            backdropItem: root.backdropItem
            ToolButton {
                id: viewBtn
                symbol: root.viewSymbols[root.fw.viewMode]
                chevron: true
                chevronSymbol: "chevron.up.chevron.down"
                onClicked: root.fw.finder.viewMenu(root.fw, viewBtn.mapToItem(null, 0, viewBtn.height + 6))
            }
        }

        // ---- Grouper ----
        ToolCapsule {
            backdropItem: root.backdropItem
            ToolButton {
                id: groupBtn
                symbol: "finder.group"
                chevron: true
                onClicked: root.fw.finder.groupMenu(root.fw, groupBtn.mapToItem(null, 0, groupBtn.height + 6))
            }
        }

        // ---- Partager / Tags / Action ----
        ToolCapsule {
            visible: root.width > 470
            backdropItem: root.backdropItem
            ToolButton {
                id: shareBtn
                symbol: "square.and.arrow.up"
                buttonWidth: 34
                enabledButton: root.hasSel
                onClicked: root.fw.finder.shareMenu(root.fw, shareBtn.mapToItem(null, 0, shareBtn.height + 6))
            }
            ToolButton {
                id: tagBtn
                symbol: "tag"
                buttonWidth: 34
                enabledButton: root.hasSel
                onClicked: root.fw.finder.tagMenu(root.fw, tagBtn.mapToItem(null, 0, tagBtn.height + 6))
            }
            ToolButton {
                id: moreBtn
                symbol: "ellipsis"
                buttonWidth: 34
                onClicked: root.fw.finder.actionMenu(root.fw, moreBtn.mapToItem(null, 0, moreBtn.height + 6))
            }
        }

        // ---- Rechercher : rond, se déploie en champ ----
        Item {
            id: search
            width: root.fw.searching ? Math.min(240, Math.max(150, root.width * 0.26)) : FStyle.capsuleHeight
            height: FStyle.capsuleHeight
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            FinderGlass {
                anchors.fill: parent
                radius: height / 2
                backdropItem: root.backdropItem
                tint: FStyle.capsuleTint
            }
            Symbol {
                x: root.fw.searching ? 11 : (parent.width - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                name: "magnifyingglass"
                size: root.fw.searching ? 14 : 18
                color: root.fw.searching ? FStyle.secondaryText : FStyle.toolIconColor
            }
            MouseArea {
                anchors.fill: parent
                enabled: !root.fw.searching
                onClicked: { root.fw.searching = true; searchInput.forceActiveFocus(); }
            }
            TextInput {
                id: searchInput
                visible: root.fw.searching
                x: 31
                width: parent.width - x - 28
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.label
                selectionColor: Theme.accent
                selectedTextColor: "white"
                clip: true
                text: root.fw.searchText
                onTextEdited: root.fw.searchText = text
                Keys.onEscapePressed: { root.fw.searching = false; root.fw.searchText = ""; root.fw.focusStage(); }
                Keys.onReturnPressed: root.fw.focusStage()
                Keys.onDownPressed: root.fw.focusStage()
                Text {
                    visible: !searchInput.text
                    text: "Search"
                    font: searchInput.font
                    color: FStyle.secondaryText
                }
            }
            // Effacer
            Rectangle {
                visible: root.fw.searching && root.fw.searchText !== ""
                width: 14
                height: 14
                radius: 7
                x: parent.width - 24
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.dark ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(0, 0, 0, 0.30)
                Symbol { anchors.centerIn: parent; name: "xmark"; size: 7; color: FStyle.contentBg }
                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: { root.fw.searchText = ""; searchInput.forceActiveFocus(); } }
            }
        }
    }
}
