import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.common
import qs.services

// Spotlight de macOS 26 Tahoe.
//
// - ⌘Espace (GlobalShortcut macos:spotlight) : capsule Liquid Glass centrée au
//   tiers supérieur de l'écran ; en bougeant le pointeur, les 4 boutons de mode
//   (Applications ⌘1, Fichiers ⌘2, Actions ⌘3, Presse-papiers ⌘4) sortent de
//   la capsule comme des gouttes.
// - Dès la frappe, la capsule s'étire en panneau de résultats groupés.
// - F4 / Launchpad (macos:apps) : ouvre directement la vue Applications.
//
// ShellState : "spotlight" (recherche) et "apps" (vue Applications).
// Débogage : quickshell ipc call spotlight-debug <fonction> (voir en bas).
Scope {
    id: root

    // ---- État ----
    readonly property bool wanted: ShellState.openPanel === "spotlight" || ShellState.openPanel === "apps"
    property bool shown: false
    property string mode: ""            // "", "apps", "files", "actions", "clipboard"
    property string query: ""
    property bool buttonsShown: false
    property bool cmdHeld: false
    property bool appsAsList: false     // options de la vue Applications : grille / liste
    property bool menuOpen: false       // menu « … » de la vue Applications ouvert
    property int historyPos: -1
    property real slow: 1               // ralentissement des animations (débogage)
    property int forceHoverButton: -1   // débogage : survol forcé d'un bouton de mode
    property var targetScreen: Quickshell.screens[0]

    // Symboles des boutons de Tahoe : « A » de l'App Store, dossier, calques
    // (Raccourcis), documents sur presse-papiers. Le nom du mode sert de texte
    // indicatif du champ (« Applications », « Presse-papiers »…).
    readonly property var modes: [
        { id: "apps", label: "Applications", symbol: "appstore", key: "1" },
        { id: "files", label: "Fichiers", symbol: "folder", key: "2" },
        { id: "actions", label: "Actions", symbol: "square.2.layers.3d", key: "3" },
        { id: "clipboard", label: "Presse-papiers", symbol: "document.on.clipboard", key: "4" }
    ]
    readonly property var modeInfo: modes.find(m => m.id === mode) ?? null
    // Bouton de mode survolé (-1 = aucun) : le champ annonce le mode et son raccourci
    property int hoverMode: -1
    readonly property var hoverInfo: buttonsVisible && hoverMode >= 0 ? modes[hoverMode] : null

    Search {
        id: search
        active: root.shown
        query: root.query
        mode: root.mode
    }

    onWantedChanged: wanted ? show() : hide()

    Connections {
        target: ShellState
        function onOpenPanelChanged() {
            if (ShellState.openPanel === "apps" && root.mode !== "apps") root.setMode("apps", true);
            else if (ShellState.openPanel === "spotlight" && root.mode === "apps" && !root.switching) root.setMode("", true);
        }
    }
    property bool switching: false
    property bool gridNavigated: false  // sélection visible dans la grille après ↑↓←→

    function show() {
        if (shown) return;
        const mon = ShellState.panelScreen || Hyprland.focusedMonitor?.name;
        targetScreen = Quickshell.screens.find(s => s.name === mon) ?? Quickshell.screens[0];
        mode = ShellState.openPanel === "apps" ? "apps" : "";
        query = "";
        historyPos = -1;
        buttonsShown = false;
        cmdHeld = false;
        gridNavigated = false;
        search.appCategory = "";
        search.fileKind = "";
        menuOpen = false;
        hoverMode = -1;
        search.resultFilter = "";
        shown = true;
    }
    function hide() {
        if (!shown) return;
        shown = false;
        if (wanted) ShellState.close();
    }
    function close() { hide(); }

    // Change de mode ; `fromState` évite de réécrire ShellState en boucle.
    function setMode(m, fromState) {
        mode = m;
        query = "";
        historyPos = -1;
        gridNavigated = false;
        menuOpen = false;
        search.appCategory = "";
        search.fileKind = "";
        if (m !== "") buttonsShown = false;
        if (!fromState) {
            switching = true;
            ShellState.openPanel = (m === "apps") ? "apps" : "spotlight";
            switching = false;
        }
    }
    function toggleMode(m) { setMode(mode === m ? "" : m); }

    // ---- Raccourcis globaux (liés par Hyprland : global, macos:<nom>) ----
    GlobalShortcut {
        appid: "macos"
        name: "spotlight"
        description: "Ouvrir / fermer Spotlight"
        onPressed: root.wanted ? ShellState.close() : ShellState.open("spotlight")
    }
    GlobalShortcut {
        appid: "macos"
        name: "apps"
        description: "Vue Applications (Launchpad)"
        onPressed: ShellState.openPanel === "apps" ? ShellState.close() : ShellState.open("apps")
    }

    // =====================================================================
    // Fenêtre plein écran transparente (clic hors du panneau = fermeture)
    // =====================================================================
    PanelWindow {
        id: win
        screen: root.targetScreen
        visible: root.shown || root.presented > 0.001
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "macos-spotlight"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: if (visible) field.forceActiveFocus()

        Item {
            id: stage
            anchors.fill: parent

            // Clic en dehors : ferme. Mouvement du pointeur : sort les boutons.
            MouseArea {
                id: backdrop
                anchors.fill: parent
                hoverEnabled: true
                property point origin: Qt.point(-1, -1)
                onPositionChanged: mouse => {
                    if (origin.x < 0) { origin = Qt.point(mouse.x, mouse.y); return; }
                    if (Math.abs(mouse.x - origin.x) + Math.abs(mouse.y - origin.y) > 4) root.revealButtons();
                }
                onClicked: root.close()
                Connections {
                    target: root
                    function onShownChanged() { if (root.shown) backdrop.origin = Qt.point(-1, -1); }
                }
            }

            // ---- Groupe : capsule / panneau + boutons de mode ----
            Item {
                id: group
                width: Metrics.groupWidth
                height: panel.height
                x: Math.round((stage.width - width) / 2)
                y: Math.round(stage.height * Metrics.topRatio)

                // Apparition : fondu + léger rebond d'échelle depuis le centre du champ
                opacity: Math.min(1, root.presented * 1.6)
                transform: Scale {
                    origin.x: group.width / 2
                    origin.y: Metrics.barHeight / 2
                    xScale: 0.9 + 0.1 * root.presented
                    yScale: 0.9 + 0.1 * root.presented
                }

                // Absorbe les clics dans le groupe (ne ferment pas)
                MouseArea { anchors.fill: panel; onClicked: {} }

                // Boutons de mode : derrière la capsule, ils en sortent en glissant
                Repeater {
                    model: root.modes
                    delegate: ModeButton {
                        id: mb
                        required property var modelData
                        required property int index
                        // 0 = caché sous l'extrémité droite de la capsule, 1 = en place
                        property real t: root.buttonsVisible ? 1 : 0
                        Behavior on t {
                            SequentialAnimation {
                                PauseAnimation { duration: (root.buttonsVisible ? mb.index : (3 - mb.index)) * 28 * root.slow }
                                NumberAnimation {
                                    duration: (root.buttonsVisible ? 520 : 260) * root.slow
                                    easing.type: root.buttonsVisible ? Easing.OutBack : Easing.InCubic
                                    easing.overshoot: 1.3
                                }
                            }
                        }
                        readonly property real finalX: Metrics.groupWidth - Metrics.buttonsWidth + Metrics.buttonGap
                                                       + index * (Metrics.buttonSize + Metrics.buttonSpacing)
                        // Départ : à moitié sous l'extrémité droite ACTUELLE de la capsule
                        // (qui se rétracte en même temps). Le verre de la capsule est
                        // translucide : le bouton n'est opaque qu'à mesure qu'il en sort,
                        // et « bourgeonne » hors de l'extrémité en grossissant, comme une
                        // goutte.
                        readonly property real hiddenX: panel.width - Metrics.buttonSize * 0.75
                        x: hiddenX + (finalX - hiddenX) * t
                        y: 0
                        z: -1
                        opacity: Math.max(0, Math.min(1, (x + Metrics.buttonSize * 0.6 - panel.width) / (Metrics.buttonSize * 0.5)))
                        scale: 0.35 + 0.65 * Math.min(1.15, t)
                        visible: t > 0.01
                        symbol: modelData.symbol
                        forceHover: root.forceHoverButton === index
                        onHoveredChanged: {
                            if (hovered) root.hoverMode = index;
                            else if (root.hoverMode === index) root.hoverMode = -1;
                        }
                        onClicked: root.setMode(modelData.id)
                    }
                }

                // ---- Capsule / panneau de verre ----
                Glass {
                    id: panel
                    width: root.buttonsVisible ? Metrics.groupWidth - Metrics.buttonsWidth : Metrics.groupWidth
                    height: Metrics.barHeight + (root.bodyShown ? root.bodyHeight + 1 : 0)
                    radius: Metrics.barRadius
                    // Ombre douce et légère : au-delà de 5 % d'opacité Hyprland
                    // floute aussi la zone d'ombre (layerrule ignore_alpha 0.05),
                    // ce qui dessinerait une bande floue sous la capsule. On plafonne
                    // donc l'ombre juste sous ce seuil (plateau large et diffus).
                    shadowBlur: 1.4
                    shadowOffset: 10
                    shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.35 : 0.2)
                    shadowMax: 0.045

                    Behavior on width {
                        NumberAnimation {
                            duration: (root.buttonsVisible ? 520 : 340) * root.slow
                            easing.type: root.buttonsVisible ? Easing.OutBack : Easing.OutCubic
                            easing.overshoot: 0.9
                        }
                    }
                    Behavior on height {
                        enabled: root.presented > 0.99
                        NumberAnimation { duration: 260 * root.slow; easing.type: Easing.OutCubic }
                    }

                    // ---- Champ de recherche ----
                    Item {
                        id: fieldRow
                        width: parent.width
                        height: Metrics.barHeight

                        // Loupe, ou symbole du mode (survol : chevron retour)
                        Item {
                            id: lead
                            x: Metrics.leadCenter - width / 2
                            width: Metrics.glyphSize
                            height: parent.height
                            Symbol {
                                anchors.centerIn: parent
                                name: root.mode === "" ? "magnifyingglass"
                                     : (leadMouse.containsMouse ? "chevron.left" : root.modeInfo.symbol)
                                size: Metrics.glyphSize
                                color: Theme.dark ? "#c2c2c7" : "#606065"
                            }
                            MouseArea {
                                id: leadMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                enabled: root.mode !== ""
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setMode("")
                            }
                        }

                        Text {
                            id: placeholder
                            anchors.fill: field
                            verticalAlignment: Text.AlignVCenter
                            visible: field.text.length === 0
                            text: root.modeInfo ? root.modeInfo.label
                                 : (root.hoverInfo ? root.hoverInfo.label : "Recherche Spotlight")
                            font: field.font
                            color: Theme.labelSecondary
                            elide: Text.ElideRight
                        }

                        // Jeton de filtre (catégorie d'apps / type de fichier) dans le
                        // champ, comme Tahoe : Effacement sur champ vide le retire.
                        Rectangle {
                            id: token
                            readonly property string label: root.filterLabel
                            visible: label !== ""
                            x: Metrics.textX - 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: visible ? tokenText.implicitWidth + 20 : 0
                            height: 30
                            radius: height / 2
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85)
                            Text {
                                id: tokenText
                                anchors.centerIn: parent
                                text: token.label
                                font.family: Theme.font
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                color: "white"
                            }
                        }

                        TextInput {
                            id: field
                            x: token.visible ? token.x + token.width + 8 : Metrics.textX
                            width: parent.width - x - (optionsButton.visible ? 52 : (keyHint.visible ? keyHint.width + 30 : 22))
                            height: parent.height
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.fontDisplay
                            font.pixelSize: Metrics.fieldFontSize
                            color: Theme.label
                            selectionColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45)
                            selectedTextColor: Theme.label
                            clip: true
                            focus: true
                            cursorDelegate: Rectangle {
                                width: 2
                                radius: 1
                                color: Theme.accent
                                visible: field.activeFocus
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: field.activeFocus
                                    PauseAnimation { duration: 500 }
                                    NumberAnimation { to: 0; duration: 120 }
                                    PauseAnimation { duration: 380 }
                                    NumberAnimation { to: 1; duration: 120 }
                                }
                            }
                            onTextChanged: {
                                if (root.query !== text) root.query = text;
                                if (text.length) root.buttonsShown = false;
                            }
                            Connections {
                                target: root
                                function onQueryChanged() { if (field.text !== root.query) field.text = root.query; }
                            }

                            Keys.onPressed: event => root.handleKey(event)
                            Keys.onReleased: event => {
                                if (event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R)
                                    root.cmdHeld = false;
                            }
                        }

                        // Survol d'un bouton de mode : touches du raccourci (« ⌘ » « 1 »)
                        // en petites touches grises à droite du champ, comme Tahoe
                        Row {
                            id: keyHint
                            visible: root.hoverInfo !== null && field.text.length === 0
                            anchors.right: parent.right
                            anchors.rightMargin: 22
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Repeater {
                                model: ["command", root.hoverInfo ? root.hoverInfo.key : ""]
                                delegate: Rectangle {
                                    required property string modelData
                                    required property int index
                                    width: 19
                                    height: 19
                                    radius: 5
                                    color: Theme.fillHover
                                    Symbol {
                                        visible: parent.index === 0
                                        anchors.centerIn: parent
                                        name: "command"
                                        size: 12
                                        // Couleur opaque : la recoloration de Symbol
                                        // gère mal une couleur semi-transparente
                                        color: Theme.dark ? "#b4b4b9" : "#5c5c61"
                                    }
                                    Text {
                                        visible: parent.index > 0
                                        anchors.centerIn: parent
                                        text: parent.modelData
                                        font.family: Theme.font
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: Theme.dark ? "#b4b4b9" : "#5c5c61"
                                    }
                                }
                            }
                        }

                        // Bouton « ⋯ » (vue Applications) : menu Grille / Liste
                        Item {
                            id: optionsButton
                            visible: root.mode === "apps"
                            anchors.right: parent.right
                            anchors.rightMargin: 17
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 26
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.fill
                                visible: optMouse.containsMouse || root.menuOpen
                            }
                            Symbol {
                                anchors.centerIn: parent
                                name: "ellipsis.circle"
                                size: 22
                                color: Theme.dark ? "#c2c2c7" : "#606065"
                            }
                            MouseArea {
                                id: optMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.menuOpen = !root.menuOpen
                            }
                        }
                    }

                    // ---- Corps : résultats / grilles ----
                    Rectangle {
                        id: sep
                        visible: root.bodyShown
                        y: Metrics.barHeight
                        x: Metrics.sidePad
                        width: parent.width - 2 * Metrics.sidePad
                        height: 1
                        color: Theme.separator
                    }

                    Item {
                        id: body
                        y: Metrics.barHeight + 1
                        width: parent.width
                        height: Math.max(0, panel.height - y)
                        clip: true
                        opacity: root.bodyShown ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 140 * root.slow } }

                        // Pastilles de filtre (groupes de résultats, catégories
                        // d'apps, types de fichiers), en fondu sur le bord droit
                        ListView {
                            id: chips
                            visible: root.chipsShown
                            x: Metrics.sidePad
                            y: Metrics.chipsTop
                            width: parent.width - 2 * Metrics.sidePad
                            height: Metrics.chipHeight
                            orientation: ListView.Horizontal
                            spacing: Metrics.chipSpacing
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.chipModel
                            layer.enabled: contentWidth > width
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: chipsFade
                                maskThresholdMin: 0.0
                                maskSpreadAtMin: 1.0
                            }
                            delegate: Chip {
                                required property var modelData
                                text: modelData.name
                                checked: root.chipChecked(modelData.id)
                                onClicked: root.pickChip(modelData.id)
                            }
                        }

                        // Masque : opaque, puis fondu sur les 36 derniers points
                        Rectangle {
                            id: chipsFade
                            visible: false
                            layer.enabled: true
                            width: chips.width
                            height: chips.height
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "white" }
                                GradientStop { position: 1 - 36 / Math.max(36, chipsFade.width); color: "white" }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        // Liste (recherche générale, Actions, Presse-papiers, Applications en liste)
                        ListView {
                            id: list
                            visible: root.bodyKind === "list"
                            y: root.chipsArea
                            width: parent.width
                            // La marge basse reste hors de la vue : aucune ligne
                            // suivante n'y dépasse au repos
                            height: parent.height - y - Metrics.listPadBottom
                            topMargin: Metrics.listPadTop
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.listModel
                            property int sel: 0
                            delegate: ResultRow {
                                selected: index === list.sel
                                cmdHeld: root.cmdHeld
                                onClicked: { list.sel = index; root.activate(false); }
                                onSecondaryAction: { search.copyClip(modelData.clipId); root.close(); }
                            }
                            onModelChanged: { sel = 0; positionViewAtBeginning(); }
                        }

                        // Message vide (presse-papiers vide, aucun résultat…)
                        Text {
                            visible: root.bodyKind === "empty"
                            x: 0
                            y: root.chipsArea
                            width: parent.width
                            height: parent.height - y
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: root.emptyText
                            font.family: Theme.font
                            font.pixelSize: 15
                            color: Theme.labelSecondary
                        }

                        // Grilles (Applications, Fichiers)
                        IconGrid {
                            id: grid
                            visible: root.bodyKind === "grid"
                            y: root.chipsArea
                            width: parent.width
                            height: parent.height - y
                            bottomMargin: 8
                            items: root.gridItems
                            columns: Metrics.gridColumns
                            showSelection: root.query.length > 0 || root.gridNavigated
                            onActivated: item => root.activateItem(item, false)
                        }
                        Text {
                            visible: root.bodyKind === "grid" && grid.flat.length === 0
                            anchors.centerIn: grid
                            text: search.filesLoading ? "Recherche…" : "Aucun résultat"
                            font.family: Theme.font
                            font.pixelSize: 15
                            color: Theme.labelSecondary
                        }
                    }
                }

                // Menu du bouton « … » (au-dessus du panneau, aligné à droite)
                MouseArea {
                    // clic ailleurs dans le panneau : ferme le menu
                    anchors.fill: panel
                    visible: root.menuOpen
                    onClicked: root.menuOpen = false
                }
                OptionsMenu {
                    id: optionsMenu
                    x: panel.width - width - 10
                    y: Metrics.barHeight - 6
                    z: 10
                    open: root.menuOpen
                    asList: root.appsAsList
                    onPicked: asList => { root.appsAsList = asList; root.menuOpen = false; }
                }
            }
        }
    }

    // =====================================================================
    // Présentation (apparition / disparition)
    // =====================================================================
    property real presented: shown ? 1 : 0
    Behavior on presented {
        NumberAnimation {
            duration: (root.shown ? 340 : 150) * root.slow
            easing.type: root.shown ? Easing.OutBack : Easing.InQuad
            easing.overshoot: 1.1
        }
    }
    onShownChanged: if (shown) field.forceActiveFocus()

    readonly property bool buttonsVisible: shown && buttonsShown && mode === "" && query.length === 0
    function revealButtons() {
        if (shown && mode === "" && query.length === 0) buttonsShown = true;
    }

    // ---- Corps ----
    readonly property string bodyKind: {
        if (mode === "apps") return appsAsList ? (listModel.length ? "list" : "empty") : "grid";
        if (mode === "files") return "grid";
        if (mode === "actions" || mode === "clipboard") return listModel.length ? "list" : "empty";
        if (query.trim().length) return listModel.length ? "list" : "empty";
        return "none";
    }
    readonly property bool bodyShown: bodyKind !== "none"

    // ---- Pastilles de filtre ----
    readonly property var chipModel: {
        if (mode === "apps") return search.appCategoriesPresent;
        if (mode === "files") return [
            { id: "folders", name: "Dossiers" }, { id: "documents", name: "Documents" },
            { id: "pdf", name: "PDF" }, { id: "images", name: "Images" }
        ];
        if (mode === "") return search.resultGroups;
        return [];
    }
    readonly property bool chipsShown: bodyShown && chipModel.length > 0
    readonly property int chipsArea: chipsShown ? Metrics.chipsTop + Metrics.chipHeight + Metrics.chipsBottom : 0
    function chipChecked(id) {
        if (mode === "apps") return search.appCategory === id;
        if (mode === "files") return search.fileKind === id;
        return search.resultFilter === id;
    }
    // Une pastille choisie se désélectionne au second clic
    function pickChip(id) {
        if (mode === "apps") search.appCategory = search.appCategory === id ? "" : id;
        else if (mode === "files") search.fileKind = search.fileKind === id ? "" : id;
        else search.resultFilter = search.resultFilter === id ? "" : id;
        gridNavigated = false;
    }
    function clearFilter() {
        search.appCategory = "";
        search.fileKind = "";
        search.resultFilter = "";
    }

    // Libellé du jeton de filtre affiché dans le champ ("" = aucun filtre)
    readonly property string filterLabel: {
        if (mode === "apps" && search.appCategory)
            return (search.appCategoriesPresent.find(c => c.id === search.appCategory) ?? { name: "" }).name;
        if (mode === "files" && search.fileKind)
            return (chipModel.find(c => c.id === search.fileKind) ?? { name: "" }).name;
        if (mode === "" && search.resultFilter)
            return search.groupNames[search.resultFilter] ?? "";
        return "";
    }
    readonly property string emptyText: mode === "clipboard" && !query.length ? "Aucun élément dans le presse-papiers" : "Aucun résultat"

    readonly property var listModel: {
        if (mode === "apps") {
            // Applications en liste : mêmes éléments que la grille, sans le trait
            return search.appGrid.filter(i => !i.separator && !i.header);
        }
        return search.results;
    }
    readonly property var gridItems: {
        if (mode === "apps") return search.appGrid;
        if (mode === "files") {
            const items = search.fileGrid;
            return (!query.trim() && items.length) ? [{ header: true, title: "Récents" }].concat(items) : items;
        }
        return [];
    }

    // Hauteur disponible sous le champ : s'arrête au-dessus du Dock (~90 pt).
    readonly property real screenH: targetScreen?.height ?? 982
    readonly property real maxBody: Math.max(200, screenH * (1 - Metrics.topRatio) - Metrics.barHeight - 96)
    // Liste : coupée sur une limite de ligne (pas de ligne à moitié visible
    // en bas du panneau au repos, comme Tahoe).
    readonly property real listHeight: {
        const pad = Metrics.listPadTop + Metrics.listPadBottom;
        const fit = Math.max(1, Math.floor((maxBody - chipsArea - pad) / Metrics.rowHeight));
        return pad + Math.min(listModel.length, fit) * Metrics.rowHeight;
    }
    readonly property real bodyHeight: {
        // Grilles : panneau de hauteur fixe (≈ carré comme Tahoe), les
        // rangées suivantes défilent sous le bord bas
        if (bodyKind === "grid") return Math.min(maxBody, Metrics.appsPanelHeight - Metrics.barHeight - 1);
        if (bodyKind === "empty") return chipsArea + 72;
        return chipsArea + listHeight;
    }

    // =====================================================================
    // Clavier
    // =====================================================================
    function moveList(d) {
        let i = list.sel;
        do { i += d; } while (i >= 0 && i < listModel.length && listModel[i].header);
        if (i < 0 || i >= listModel.length) return;
        list.sel = i;
        list.positionViewAtIndex(i, ListView.Contain);
        // Fait aussi apparaître l'en-tête de section au-dessus du premier élément
        if (i > 0 && listModel[i - 1].header && d < 0) list.positionViewAtIndex(i - 1, ListView.Contain);
    }

    function handleKey(event) {
        const meta = (event.modifiers & Qt.MetaModifier) || (event.modifiers & Qt.ControlModifier);
        const k = event.key;
        if (k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R) { cmdHeld = true; return; }

        // ⌘1…⌘4 : modes
        if (meta && k >= Qt.Key_1 && k <= Qt.Key_4) {
            toggleMode(modes[k - Qt.Key_1].id);
            event.accepted = true;
            return;
        }
        switch (k) {
        case Qt.Key_Escape:
            if (menuOpen) menuOpen = false;
            else if (filterLabel !== "" && query.length === 0) clearFilter();
            else if (mode !== "") setMode("");
            else if (query.length) query = "";
            else close();
            event.accepted = true;
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activate(!!(event.modifiers & Qt.MetaModifier) || !!(event.modifiers & Qt.ControlModifier));
            event.accepted = true;
            return;
        case Qt.Key_Down:
            if (bodyKind === "grid") moveGrid(0, 1);
            else moveList(1);
            historyPos = -1;
            event.accepted = true;
            return;
        case Qt.Key_Up:
            // Champ vide : rappelle les recherches précédentes (comme Tahoe)
            if (mode === "" && (query.length === 0 || historyPos >= 0)) {
                if (historyPos + 1 < search.historyCount) {
                    historyPos++;
                    query = search.historyAt(historyPos);
                    field.selectAll();
                }
            } else if (bodyKind === "grid") moveGrid(0, -1);
            else moveList(-1);
            event.accepted = true;
            return;
        case Qt.Key_Left:
        case Qt.Key_Right:
            if (bodyKind === "grid") {
                moveGrid(k === Qt.Key_Left ? -1 : 1, 0);
                event.accepted = true;
            }
            return;
        case Qt.Key_Tab:
            if (bodyKind === "grid") moveGrid(1, 0);
            else moveList(1);
            event.accepted = true;
            return;
        case Qt.Key_Backtab:
            if (bodyKind === "grid") moveGrid(-1, 0);
            else moveList(-1);
            event.accepted = true;
            return;
        }
        if (k === Qt.Key_Backspace && query.length === 0 && (mode !== "" || filterLabel !== "")) {
            // Retire d'abord le jeton de filtre, puis sort du mode
            if (filterLabel !== "") clearFilter();
            else setMode("");
            event.accepted = true;
        }
    }

    function moveGrid(dx, dy) {
        // Premier appui : rend la sélection visible sans la déplacer
        if (!gridNavigated && query.length === 0) { gridNavigated = true; return; }
        gridNavigated = true;
        grid.moveSelection(dx, dy);
    }

    function currentItem() {
        if (bodyKind === "grid") return grid.current();
        if (bodyKind === "list") return listModel[list.sel] ?? null;
        return null;
    }

    function activate(reveal) { activateItem(currentItem(), reveal); }

    function activateItem(item, reveal) {
        if (!item || item.header) return;
        search.activate(item, reveal);
        close();
    }

    // =====================================================================
    // Débogage (banc de test : pas de clic possible)
    //   quickshell ipc call spotlight-debug open apps
    //   quickshell ipc call spotlight-debug type "calc"
    // =====================================================================
    IpcHandler {
        target: "spotlight-debug"
        function open(m: string): void {
            ShellState.open(m === "apps" ? "apps" : "spotlight");
            if (m !== "apps") root.setMode(m === "main" ? "" : m);
        }
        function type(text: string): void { root.query = text; }
        function buttons(on: bool): void { if (on) root.revealButtons(); else root.buttonsShown = false; }
        function hover(i: int): void { root.forceHoverButton = i; }
        function key(name: string): void {
            const map = { up: Qt.Key_Up, down: Qt.Key_Down, left: Qt.Key_Left, right: Qt.Key_Right,
                          escape: Qt.Key_Escape, tab: Qt.Key_Tab, return: Qt.Key_Return };
            const ev = { key: map[name] ?? 0, modifiers: 0, accepted: false };
            root.handleKey(ev);
        }
        function slowdown(f: real): void { root.slow = f; }
        function category(id: string): void { search.appCategory = id; }
        function chip(id: string): void { root.pickChip(id); }
        function filekind(id: string): void { search.fileKind = id; }
        function cmd(on: bool): void { root.cmdHeld = on; }
        function applist(on: bool): void { root.appsAsList = on; }
        function menu(on: bool): void { root.menuOpen = on; }
        function dark(on: bool): void { Theme.dark = on; }
        function state(): string {
            return JSON.stringify({ shown: root.shown, mode: root.mode, query: root.query, body: root.bodyKind,
                                    results: root.listModel.length, grid: root.gridItems.length,
                                    sel: list.sel, buttons: root.buttonsVisible,
                                    files: search.fileHits.length, fileQ: search.fileHitsQuery, fdQ: search.fdQuery });
        }
    }
}
