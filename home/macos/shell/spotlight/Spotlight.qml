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
//   (Applications ⌘1, Files ⌘2, Actions ⌘3, Clipboard ⌘4) sortent de la
//   capsule comme des gouttes.
// - Liquid Glass : la fenêtre fournit un GlassBackdrop « snapshot » (capture de
//   l'écran prise juste avant l'apparition) que tous ses verres réfractent ;
//   l'animation d'apparition ne démarre qu'une fois la fenêtre visible.
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
    property bool filesAsList: false    // options de la vue Fichiers : grille / liste
    property bool menuOpen: false       // menu « ⋯ » ouvert
    property bool openedAsApps: false   // ouvert directement en vue Applications (F4)
    property int historyPos: -1
    property real slow: 1               // ralentissement des animations (débogage)
    property int forceHoverButton: -1   // débogage : survol forcé d'un bouton de mode
    property var targetScreen: Quickshell.screens[0]

    // Symboles des boutons de Tahoe : « A » de l'App Store, dossier, calques
    // (Raccourcis), documents sur presse-papiers. Le nom du mode sert de texte
    // indicatif du champ (« Applications », « Clipboard »…).
    readonly property var modes: [
        { id: "apps", label: "Applications", symbol: "appstore", key: "1" },
        { id: "files", label: "Files", symbol: "folder", key: "2" },
        { id: "actions", label: "Actions", symbol: "square.2.layers.3d", key: "3" },
        { id: "clipboard", label: "Clipboard", symbol: "document.on.clipboard", key: "4" }
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
        openedAsApps = mode === "apps";
        search.fileScope = "";
        search.fileScopeName = "";
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
        openT0 = Date.now();
        lastPointer = Qt.point(-1, -1);
        pointerMoved = false;
        shown = true;
    }
    // Mesure du délai d'ouverture (raccourci -> fenêtre visible), en ms
    property double openT0: 0
    property real openLatency: -1
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
        search.fileScope = "";
        search.fileScopeName = "";
        if (m !== "apps") openedAsApps = false;
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
        description: "Show Spotlight search"
        onPressed: root.wanted ? ShellState.close() : ShellState.open("spotlight")
    }
    GlobalShortcut {
        appid: "macos"
        name: "apps"
        description: "Show Apps"
        onPressed: ShellState.openPanel === "apps" ? ShellState.close() : ShellState.open("apps")
    }

    // =====================================================================
    // Fenêtre plein écran transparente (clic hors du panneau = fermeture)
    // =====================================================================
    PanelWindow {
        id: win
        screen: root.targetScreen
        // Visible une fois la capture du fond arrivée (Liquid Glass)
        visible: bd.pass
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        // « macos-lg-* » : pas de flou Hyprland, le verre réfracte lui-même
        WlrLayershell.namespace: "macos-lg-spotlight"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        property Item glassBackdrop: bd
        GlassBackdrop {
            id: bd
            mode: "snapshot"
            screen: win.screen
            want: root.shown || root.presented > 0.001
            // Repli court : Spotlight doit s'ouvrir en < 100 ms même si la
            // capture tarde (elle arrive en ~50 ms à 60 Hz)
            timeout: 90
        }

        onVisibleChanged: {
            if (!visible) return;
            field.forceActiveFocus();
            if (root.openT0 > 0) { root.openLatency = Date.now() - root.openT0; root.openT0 = 0; }
        }

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
                        readonly property real finalX: Metrics.barWidthWithButtons + Metrics.buttonGap
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
                    width: root.buttonsVisible ? Metrics.barWidthWithButtons : Metrics.groupWidth
                    height: Metrics.barHeight + (root.bodyShown ? root.bodyHeight + 1 : 0)
                    radius: Metrics.barRadius
                    tint: root.glassTint
                    // Ombre douce et diffuse (namespace macos-lg-* : non floutée
                    // par Hyprland, plus de plafond ignore_alpha)
                    shadowBlur: 1.6
                    shadowOffset: 12
                    shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.30 : 0.14)

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
                                color: root.glyphColor
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
                            // Jeton de filtre présent : pas de texte indicatif
                            visible: field.text.length === 0 && !token.visible
                            text: root.modeInfo ? root.modeInfo.label
                                 : (root.hoverInfo ? root.hoverInfo.label : "Spotlight Search")
                            font: field.font
                            // ≈ 72 % en sombre (MacRumors « apps-app-macos »), ≈ 68 % en
                            // clair (Cult of Mac « Spotlight-Applications »)
                            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.72) : Qt.rgba(0, 0, 0, 0.68)
                            elide: Text.ElideRight
                        }

                        // Jeton de filtre (catégorie d'apps / type de fichier) dans le
                        // champ, comme Tahoe : Effacement sur champ vide le retire.
                        Rectangle {
                            id: token
                            readonly property string label: root.filterLabel
                            visible: label !== ""
                            x: Metrics.textX - 6
                            anchors.verticalCenter: parent.verticalCenter
                            // Jeton gris neutre de 30 pt, texte de la taille du champ,
                            // précédé de l'icône de la source (MacRumors
                            // « search-spotlight-location » : « iCloud Drive »)
                            width: visible ? tokenRow.implicitWidth + 14 : 0
                            height: 30
                            radius: 9
                            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.07)
                            Row {
                                id: tokenRow
                                x: 7
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5
                                ItemIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !!root.filterIcon
                                    size: 24
                                    item: root.filterIcon
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: token.label
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Metrics.fieldFontSize
                                    color: Theme.label
                                }
                            }
                        }

                        TextInput {
                            id: field
                            x: token.visible ? token.x + token.width + 8 : Metrics.textX
                            width: parent.width - x - (optionsButton.visible || fieldIcon.visible ? 56 : (keyHint.visible ? keyHint.width + 30 : 22))
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
                                // Captures Tahoe : curseur de la couleur du texte
                                color: Theme.label
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

                        // Complétion du résultat choisi : « — The Edinburgh Minute » dans
                        // une capsule grise discrète, juste après le texte saisi
                        // (MacRumors « spotlight-categories », « search-spotlight-location »)
                        Rectangle {
                            id: completion
                            readonly property string text: root.completionText
                            readonly property real room: field.x + field.width - x
                            visible: text !== "" && field.text.length > 0 && room > 60
                            x: Math.round(field.x + Math.min(field.contentWidth, field.width) + 3)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(room, complRow.implicitWidth + 22)
                            height: Metrics.completionHeight
                            radius: 9
                            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.045)
                            Row {
                                id: complRow
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                Text {
                                    text: "\u2013"
                                    font.family: Theme.font
                                    font.pixelSize: Metrics.completionFontSize
                                    color: root.completionColor
                                }
                                Text {
                                    width: Math.min(implicitWidth, completion.room - 22 - 12 - 12 - 10)
                                    text: completion.text
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    font.family: Theme.font
                                    font.pixelSize: Metrics.completionFontSize
                                    color: root.completionColor
                                }
                            }
                        }

                        // Icône du résultat choisi, à l'extrémité droite du champ
                        // (symétrique de la loupe : centre à 32 pt du bord)
                        ItemIcon {
                            id: fieldIcon
                            // (ne dépend pas de la capsule : sinon boucle avec la largeur du champ)
                            visible: root.completionText !== "" && field.text.length > 0 && !optionsButton.visible
                            x: parent.width - Metrics.leadCenter - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            size: Metrics.fieldIcon
                            item: root.currentListItem
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
                                    width: 22
                                    height: 22
                                    radius: 6
                                    color: Theme.fillHover
                                    Symbol {
                                        visible: parent.index === 0
                                        anchors.centerIn: parent
                                        name: "command"
                                        size: 13
                                        // Couleur opaque : la recoloration de Symbol
                                        // gère mal une couleur semi-transparente
                                        color: Theme.dark ? "#b4b4b9" : "#5c5c61"
                                    }
                                    Text {
                                        visible: parent.index > 0
                                        anchors.centerIn: parent
                                        text: parent.modelData
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: Theme.dark ? "#b4b4b9" : "#5c5c61"
                                    }
                                }
                            }
                        }

                        // Bouton « ⋯ » (Applications, Fichiers, Presse-papiers ; pas en
                        // Actions : Cult of Mac « Spotlight-Files / Clipboard / Actions »)
                        Item {
                            id: optionsButton
                            visible: root.mode === "apps" || root.mode === "files" || root.mode === "clipboard"
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
                                size: 24
                                color: root.glyphColor
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
                                required property int index
                                width: root.chipWidths[index] ?? implicitWidth
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

                        // Vue Liste (Applications, Fichiers) : trait sous les pastilles
                        // (MacMagazine « lista »)
                        Rectangle {
                            visible: root.chipsShown && root.bodyKind === "list" && root.listView
                            x: Metrics.sidePad
                            y: root.chipsArea
                            width: parent.width - 2 * Metrics.sidePad
                            height: 1
                            color: Theme.separator
                        }

                        // Liste (recherche générale, Actions, Presse-papiers, Applications en liste)
                        ListView {
                            id: list
                            visible: root.bodyKind === "list"
                            y: root.chipsArea + (root.chipsShown && root.listView ? 1 : 0)
                            width: parent.width
                            // La marge basse reste hors de la vue : aucune ligne
                            // suivante n'y dépasse au repos
                            height: parent.height - y - Metrics.listPadBottom
                            topMargin: Metrics.listPadTop
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.listModel
                            property int sel: 0
                            highlightFollowsCurrentItem: false
                            delegate: ResultRow {
                                selected: index === list.sel
                                cmdHeld: root.cmdHeld
                                onClicked: { list.sel = index; root.activate(false); }
                                onSecondaryAction: { search.copyClip(modelData.clipId); root.close(); }
                                onPointed: (sx, sy) => { if (root.pointerMovedTo(sx, sy) && !modelData.header && !modelData.separator) list.sel = index; }
                            }
                            // Première ligne sélectionnable (saute un en-tête) ; au repos
                            // (sans saisie) en Actions, Presse-papiers et vues Liste :
                            // aucune ligne surlignée (Cult of Mac « Spotlight-Actions »,
                            // « Spotlight-Clipboard »)
                            onModelChanged: { sel = root.restSelection(); positionViewAtBeginning(); }
                        }
                        ScrollHint { flick: list }

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
                            labelLines: root.mode === "files" ? 2 : 1
                            cellHeight: root.mode === "files" ? Metrics.fileCellHeight : Metrics.gridCellHeight
                            showSelection: root.query.length > 0 || root.gridNavigated
                            hoverActive: root.pointerMoved
                            onPointed: (sx, sy) => root.pointerMovedTo(sx, sy)
                            onActivated: item => root.activateItem(item, false)
                        }
                        ScrollHint { flick: grid }
                        Text {
                            visible: root.bodyKind === "grid" && grid.flat.length === 0
                            anchors.centerIn: grid
                            text: search.filesLoading ? "Searching…" : "No Results"
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
                // Haut du menu à ≈ 30 pt du haut du panneau, sur le bas du bouton
                // (MacMagazine « lista », MacRumors « apps-app-macos »)
                OptionsMenu {
                    id: optionsMenu
                    x: panel.width - width - 10
                    y: 30
                    z: 10
                    open: root.menuOpen
                    entries: root.mode === "clipboard"
                        ? [{ text: "Clear History", id: "clear" }]
                        : [{ title: "View content as" },
                           { text: "Grid", id: "grid", checked: !root.listView },
                           { text: "List", id: "list", checked: root.listView }]
                    onPicked: id => {
                        if (id === "clear") { search.runAction("clearclip"); }
                        else if (root.mode === "files") root.filesAsList = id === "list";
                        else root.appsAsList = id === "list";
                        root.menuOpen = false;
                    }
                }
            }
        }
    }

    // =====================================================================
    // Présentation (apparition / disparition)
    // =====================================================================
    // Démarre quand la fenêtre devient visible (après la capture du fond), pas
    // avant : sinon la première partie de l'animation serait perdue
    property real presented: shown && bd.pass ? 1 : 0
    Behavior on presented {
        NumberAnimation {
            duration: (root.shown ? 340 : 150) * root.slow
            easing.type: root.shown ? Easing.OutBack : Easing.InQuad
            easing.overshoot: 1.1
        }
    }
    onShownChanged: if (shown) field.forceActiveFocus()

    readonly property bool buttonsVisible: shown && buttonsShown && mode === "" && query.length === 0
    // Le pointeur a-t-il réellement bougé ? (une liste qui apparaît ou défile
    // sous un pointeur immobile envoie aussi des événements de survol : ils ne
    // doivent ni sélectionner une ligne ni surligner une case)
    property point lastPointer: Qt.point(-1, -1)
    property bool pointerMoved: false
    function pointerMovedTo(sx, sy) {
        if (lastPointer.x < 0) { lastPointer = Qt.point(sx, sy); return pointerMoved; }
        if (Math.abs(sx - lastPointer.x) + Math.abs(sy - lastPointer.y) < 1) return pointerMoved;
        lastPointer = Qt.point(sx, sy);
        pointerMoved = true;
        return true;
    }

    function revealButtons() {
        if (shown && mode === "" && query.length === 0) buttonsShown = true;
    }

    // ---- Corps ----
    readonly property string bodyKind: {
        if (mode === "apps") return appsAsList ? (listModel.length ? "list" : "empty") : "grid";
        if (mode === "files") return filesAsList ? (listModel.length ? "list" : "empty") : "grid";
        if (mode === "actions" || mode === "clipboard") return listModel.length ? "list" : "empty";
        if (query.trim().length) return listModel.length ? "list" : "empty";
        return "none";
    }
    readonly property bool bodyShown: bodyKind !== "none"

    // ---- Pastilles de filtre ----
    readonly property var chipModel: {
        if (mode === "apps") return search.appCategoriesPresent;
        if (mode === "files") return [
            { id: "folders", name: "Folders" }, { id: "documents", name: "Documents" },
            { id: "pdf", name: "PDF" }, { id: "images", name: "Images" }
        ];
        if (mode === "") return search.resultGroups;
        return [];
    }
    readonly property bool chipsShown: bodyShown && chipModel.length > 0
    // Largeurs des pastilles : quand toutes tiennent, elles s'élargissent pour
    // occuper la rangée ; les courtes prennent une largeur commune, les longues
    // gardent la leur (Cult of Mac « Spotlight-Files » : IINA / Preview / PDF
    // égales, Pixelmator Pro et Xcode plus larges ; MacRumors « search-spotlight-
    // location » : trois tiers). Sinon, largeur naturelle et défilement.
    // (calculé hors liaison : TextMetrics n'est pas réentrant)
    property var chipWidths: []
    onChipModelChanged: chipWidths = computeChipWidths()
    function computeChipWidths() {
        const nat = chipModel.map(c => { chipMetrics.text = c.name; return Math.ceil(chipMetrics.advanceWidth) + 18; });
        const avail = Metrics.groupWidth - 2 * Metrics.sidePad - Math.max(0, nat.length - 1) * Metrics.chipSpacing;
        const sum = nat.reduce((a, b) => a + b, 0);
        if (!nat.length || sum > avail) return nat;
        // w tel que somme(max(nat, w)) = avail
        let w = avail / nat.length;
        for (let it = 0; it < 8; it++) {
            let big = 0, n = 0;
            for (const x of nat) { if (x > w) big += x; else n++; }
            if (!n) break;
            const nw = (avail - big) / n;
            if (Math.abs(nw - w) < 0.01) break;
            w = nw;
        }
        // Pixels entiers ; le reste va à la dernière pastille
        const out = nat.map(x => Math.floor(Math.max(x, w)));
        out[out.length - 1] += avail - out.reduce((a, b) => a + b, 0);
        return out;
    }
    TextMetrics { id: chipMetrics; font.family: Theme.font; font.pixelSize: Metrics.chipFontSize }
    // Vue Applications / Fichiers présentée en liste
    readonly property bool listView: (mode === "apps" && appsAsList) || (mode === "files" && filesAsList)
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
        // Fait défiler la rangée de pastilles jusqu'à la pastille choisie
        const idx = chipModel.findIndex(c => c.id === id);
        if (idx >= 0) chips.positionViewAtIndex(idx, ListView.Contain);
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
        if (mode === "files" && search.fileScope)
            return search.fileScopeName;
        if (mode === "files" && search.fileKind)
            return (chipModel.find(c => c.id === search.fileKind) ?? { name: "" }).name;
        if (mode === "" && search.resultFilter)
            return search.groupNames[search.resultFilter] ?? "";
        return "";
    }
    // Icône du jeton (dossier où l'on cherche)
    readonly property var filterIcon: mode === "files" && search.fileScope
        ? { icon: Quickshell.iconPath("folder", "folder") } : null
    readonly property string emptyText: mode === "clipboard" && !query.length ? "No Clipboard History" : "No Results"

    readonly property var listModel: {
        // Applications en liste : suggestions, trait, puis A à Z ; une ligne
        // par app, sans détail (MacMagazine « lista »)
        if (mode === "apps")
            return search.appGrid.map(i => i.separator || i.header ? i : Object.assign({}, i, { subtitle: "" }));
        if (mode === "files")
            return search.fileGrid.filter(i => !i.header && !i.separator);
        return search.results;
    }
    readonly property var gridItems: {
        if (mode === "apps") return search.appGrid;
        if (mode === "files") {
            const items = search.fileGrid;
            // Sans section « Suggestions » : un seul en-tête « Recents »
            return (!query.trim() && !search.fileScope && items.length && !items[0].header)
                ? [{ header: true, title: "Recents" }].concat(items) : items;
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
        const avail = maxBody - chipsArea - pad;
        let h = 0;
        for (const it of listModel) {
            const rh = it.header ? Metrics.headerHeight : it.separator ? 26 : Metrics.rowHeight;
            if (h + rh > avail) break;
            h += rh;
        }
        return pad + Math.max(h, Math.min(listModel.length, 1) * Metrics.rowHeight);
    }
    function firstSelectable() {
        for (let i = 0; i < listModel.length; i++) if (!listModel[i].header && !listModel[i].separator) return i;
        return 0;
    }
    // Sélection au repos : le meilleur résultat en recherche ; rien sans saisie
    function restSelection() {
        if (!query.length && mode !== "") return -1;
        return firstSelectable();
    }

    // Élément choisi de la liste (complétion du champ, icône à droite)
    readonly property var currentListItem: bodyKind === "list" && list.sel >= 0 ? (listModel[list.sel] ?? null) : null
    readonly property string completionText: {
        const it = currentListItem;
        if (mode !== "" || !it || it.header || it.separator) return "";
        if (it.kind === "web") return "Search the Web";
        return it.title ?? "";
    }
    readonly property color completionColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(0, 0, 0, 0.40)

    // ---- Matériau (Liquid Glass recalibré sur les captures Tahoe) ----
    // Teinte = cible de luminance du fond réfracté. Clair (Cult of Mac
    // « Spotlight-Applications ») : fond L ≈ 0,45 -> panneau ≈ 0,82, fond
    // pastel gardant sa chrominance -> blanc à ~62 %. Sombre (MacRumors
    // « spotlight-clipboard », « search-spotlight-location ») : fond ≈ 0,40
    // -> ≈ 0,19, bleuté -> gris très foncé à ~64 %.
    readonly property color glassTint: Theme.dark ? Qt.rgba(0.09, 0.09, 0.10, 0.64) : Qt.rgba(1, 1, 1, 0.62)
    readonly property color glyphColor: Theme.dark ? "#c8c8cd" : "#55555a"
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
        // Sans sélection (repos) : ↓ prend la première ligne
        if (i < 0) { if (d < 0) return; i = -1; }
        do { i += d; } while (i >= 0 && i < listModel.length && (listModel[i].header || listModel[i].separator));
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
            // Vue Applications ouverte par F4 / Launchpad : Échap ferme
            else if (mode === "apps" && openedAsApps && query.length === 0) close();
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
            // Tahoe : Tab lance l'action de la ligne choisie (« Search <dossier> »),
            // il ne déplace pas la sélection
            tabAction();
            event.accepted = true;
            return;
        case Qt.Key_Backtab:
            event.accepted = true;
            return;
        }
        if (k === Qt.Key_Backspace && query.length === 0 && (mode !== "" || filterLabel !== "")) {
            // Retire d'abord le jeton de filtre, puis sort du mode
            if (search.fileScope) { search.fileScope = ""; search.fileScopeName = ""; setMode(""); }
            else if (filterLabel !== "") clearFilter();
            else setMode("");
            event.accepted = true;
        }
    }

    // Tab sur un dossier : y chercher (vue Fichiers, jeton du dossier dans le champ)
    function tabAction() {
        const it = currentItem();
        if (!it || it.kind !== "file" || !it.isDir) return;
        const rel = it.rel, name = it.title;
        setMode("files");
        search.fileScope = rel;
        search.fileScopeName = name;
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
            else root.openedAsApps = true;
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
        function select(i: int): void { list.sel = i; }
        function category(id: string): void { search.appCategory = id; }
        function chip(id: string): void { root.pickChip(id); }
        function filekind(id: string): void { search.fileKind = id; }
        function cmd(on: bool): void { root.cmdHeld = on; }
        function applist(on: bool): void { root.appsAsList = on; }
        function filelist(on: bool): void { root.filesAsList = on; }
        function menu(on: bool): void { root.menuOpen = on; }
        function dark(on: bool): void { Theme.dark = on; }
        function state(): string {
            return JSON.stringify({ shown: root.shown, mode: root.mode, query: root.query, body: root.bodyKind,
                                    results: root.listModel.length, grid: root.gridItems.length,
                                    sel: list.sel, buttons: root.buttonsVisible, latency: root.openLatency,
                                    apps: search.apps.length, appsAll: Apps.all.length,
                                    files: search.fileHits.length, fileQ: search.fileHitsQuery, fdQ: search.fdQuery });
        }
    }
}
