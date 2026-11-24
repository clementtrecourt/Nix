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
    readonly property real leftX: fw.showSidebar ? 8 : FStyle.lightX + 3 * FStyle.lightSize + 2 * FStyle.lightGap + 14
    readonly property var viewSymbols: ({ icon: "square.grid.2x2", list: "list.bullet", column: "rectangle.split.3x1", gallery: "finder.gallery" })
    readonly property var hasSel: fw.selection.length > 0

    // ---- Place disponible : repli des éléments (NSToolbar de Tahoe) ----
    // 0 : tout ; 1 : présentations repliées en un bouton (⊞⌃⌄, capture Apple
    // mchl83c9e8b8) ; 2 : présentations, Grouper, Partager et Tags passent
    // dans un bouton rond « » » (chevron.forward.2) qui ouvre un menu ; restent
    // « … » et Rechercher (capture 2x de Daring Fireball). Le titre garde sa
    // place (jusqu'à 140 pt) avant tout repli.
    readonly property real _gap: FStyle.capsuleGap
    readonly property real _wViews: 4 * FStyle.buttonWidth + 2 * FStyle.capsulePad
    readonly property real _wViewsC: 48 + 2 * FStyle.capsulePad
    readonly property real _wGroup: 48 + 2 * FStyle.capsulePad
    readonly property real _wShare: 3 * 34 + 2 * FStyle.capsulePad
    readonly property real _wAction: 34 + 2 * FStyle.capsulePad
    readonly property real _wSearch: search.width
    readonly property real _titleNeed: Math.min(titleMetrics.advanceWidth(titleText.text), 140) + (proxyIcon.visible ? 22 : 0)
    readonly property real _avail: width - 8 - (nav.x + nav.width + 14) - _titleNeed - 12
    readonly property int stage: {
        const base = _wSearch + _wGroup + _wShare + 2 * _gap;
        if (_avail >= base + _wViews + _gap + root.paneGap) return 0;
        if (_avail >= base + _wViewsC + _gap + root.paneGap) return 1;
        return 2;
    }
    readonly property bool compact: stage === 1
    // Galerie : le volet d'informations occupe toute la hauteur ; les éléments
    // à droite de la présentation (Grouper, Partager…, Rechercher) sont posés
    // au-dessus du volet, le sélecteur de présentation reste au-dessus du
    // contenu (capture Apple mchldaafb302, « Gallery view »).
    readonly property real paneW: fw.inspectorWidth
    readonly property real paneGap: paneW > 0 ? 16 : 0

    FontMetrics { id: titleMetrics; font: titleText.font }
    function debugOverflow() { overflowMenu(overflowBtn, true); }
    function _menuPos(it) { return it.mapToItem(null, 0, it.height + 6); }
    function overflowMenu(it, noGrab) {
        const w = root.fw;
        const v = [["as Icons", "icon", "square.grid.2x2"], ["as List", "list", "list.bullet"],
                   ["as Columns", "column", "rectangle.split.3x1"], ["as Gallery", "gallery", "finder.gallery"]];
        const l = v.map(x => ({ text: x[0], icon: x[2], checked: w.viewMode === x[1] ? true : undefined, action: () => w.viewMode = x[1] }));
        l.push({ separator: true });
        l.push({ text: "Group", icon: "finder.group.rows", submenu: w.finder.groupItems(w) });
        l.push({ text: "Share…", icon: "square.and.arrow.up", enabled: root.hasSel, action: () => w.finder.shareMenu(w, root._menuPos(overflowBtn)) });
        l.push({ text: "Tags…", icon: "tag", enabled: root.hasSel, action: () => w.finder.tagMenu(w, root._menuPos(overflowBtn)) });
        w.finder.showMenu(w, Qt.point(root._menuPos(it).x - 10, root._menuPos(it).y), l, noGrab);
    }

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

    // Icône du dossier (icône « proxy ») : apparaît au survol du titre
    FileIcon {
        id: proxyIcon
        visible: titleHover.hovered && !root.fw.isVirtual
        x: nav.x + nav.width + 14
        anchors.verticalCenter: nav.verticalCenter
        size: 16
        thumbnails: false
        entry: root.fw.currentFolderEntry()
    }
    Text {
        id: titleText
        x: nav.x + nav.width + 14 + (proxyIcon.visible ? 22 : 0)
        width: Math.max(0, Math.min(implicitWidth, root.titleRight - x - 12))
        anchors.verticalCenter: nav.verticalCenter
        // Pendant une recherche : « Searching “This Mac” »
        text: root.fw.searchText !== "" ? "Searching \u201C" + (root.fw.searchScope === "mac" ? "This Mac" : Fs.displayName(root.fw.path)) + "\u201D"
                                        : Fs.displayName(root.fw.path)
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: FStyle.titleSize
        font.weight: Font.Bold
        color: root.fw.active ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(0, 0, 0, 0.80))
                              : (Theme.dark ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(0, 0, 0, 0.35))
        HoverHandler { id: titleHover }
    }
    // Bord droit disponible pour le titre
    readonly property real titleRight: views.visible ? views.x : (viewsC.visible ? viewsC.x : right.x)

    // ---- Présentations (au-dessus du contenu, même en Galerie) ----
    ToolCapsule {
        id: views
        visible: root.stage === 0
        y: FStyle.capsuleY
        x: root.paneW > 0 ? root.width - root.paneW - root.paneGap - width : right.x - root._gap - width
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
        id: viewsC
        visible: root.stage === 1
        y: FStyle.capsuleY
        x: root.paneW > 0 ? root.width - root.paneW - root.paneGap - width : right.x - root._gap - width
        backdropItem: root.backdropItem
        ToolButton {
            id: viewBtn
            symbol: root.viewSymbols[root.fw.viewMode]
            chevron: true
            chevronSymbol: "chevron.up.chevron.down"
            onClicked: root.fw.finder.viewMenu(root.fw, viewBtn.mapToItem(null, 0, viewBtn.height + 6))
        }
    }

    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: FStyle.capsuleY
        spacing: FStyle.capsuleGap

        // ---- Grouper ----
        ToolCapsule {
            visible: root.stage < 2
            backdropItem: root.backdropItem
            ToolButton {
                id: groupBtn
                symbol: "finder.group.rows"
                chevron: true
                onClicked: root.fw.finder.groupMenu(root.fw, groupBtn.mapToItem(null, 0, groupBtn.height + 6))
            }
        }

        // ---- Partager / Tags / Action ----
        ToolCapsule {
            backdropItem: root.backdropItem
            ToolButton {
                id: shareBtn
                visible: root.stage < 2
                symbol: "square.and.arrow.up"
                buttonWidth: 34
                enabledButton: root.hasSel
                onClicked: root.fw.finder.shareMenu(root.fw, shareBtn.mapToItem(null, 0, shareBtn.height + 6))
            }
            ToolButton {
                id: tagBtn
                visible: root.stage < 2
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

        // ---- Débordement « » » ----
        Item {
            visible: root.stage === 2
            width: FStyle.capsuleHeight
            height: FStyle.capsuleHeight
            FinderGlass {
                anchors.fill: parent
                radius: height / 2
                backdropItem: root.backdropItem
                tint: FStyle.capsuleTint
            }
            ToolButton {
                id: overflowBtn
                anchors.centerIn: parent
                buttonWidth: FStyle.buttonHeight
                symbol: "chevron.forward.2"
                symbolSize: 16
                onClicked: root.overflowMenu(overflowBtn)
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
