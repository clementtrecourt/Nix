import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.common

// Barre d'outils « Screenshot » de macOS Tahoe (Maj+Cmd+5), d'après l'image Apple
// « Take a screenshot on Mac » (macOS 26, 572 × 53 pt) :
//  (×) | Capture Entire Screen · Selected Window · Selected Portion |
//        Record Entire Screen · Selected Window · Selected Portion | Options ⌄  [Capture]
// Plaque de verre arrondie (~12 pt) centrée au-dessus du Dock ; outil choisi sur
// fond gris arrondi ; bouton bleu « Capture » / « Record ». Échap ferme, Entrée
// capture. La barre disparaît AVANT la capture (jamais dans l'image).
// « Selected Portion » : cadre persistant (extérieur assombri, bord pointillé,
// 8 poignées) qu'on déplace ou redimensionne avant de cliquer sur Capture ;
// cliquer-glisser hors du cadre en trace un nouveau.
// Pendant un enregistrement : bouton « Stop Recording » dans la barre des menus
// si elle le gère (Shots.menuBarStopButton), sinon pastille « ● 00:12 ■ ».
Scope {
    id: root

    GlobalShortcut {
        appid: "macos"
        name: "screenshot-ui"
        description: "Screenshot toolbar"
        onPressed: {
            if (Shots.recording) Shots.stopRecording();
            else Shots.toolbarOpen = !Shots.toolbarOpen;
        }
    }

    // Débogage (pas de clic possible dans le banc de test)
    IpcHandler {
        target: "screenshot-debug"
        function options(on: bool): void { win.optionsOpen = on; }
        function mode(m: string): void { win.mode = m; }
        function commit(): void { win.commit(); }
        function tip(i: int): void { win.debugTip = i; }
        function select(x: int, y: int, w: int, h: int): void { win.setSel({ x: x, y: y, w: w, h: h }); }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

        // screen | window | area | rec-screen | rec-window | rec-area
        property string mode: Shots.lastMode
        property bool optionsOpen: false
        property int debugTip: -1
        property real progress: Shots.toolbarOpen && backdrop.pass ? 1 : 0
        Behavior on progress { NumberAnimation { duration: Shots.toolbarOpen ? 260 : 160; easing.type: Easing.OutCubic } }

        // Liquid Glass : capture de l'écran prise juste avant l'ouverture. Pendant
        // une capture (Shots.busy) ou un enregistrement, la fenêtre est démappée
        // immédiatement, sans fondu : elle n'apparaît jamais dans l'image.
        readonly property bool areaMode: mode === "area" || mode === "rec-area"
        readonly property bool recMode: mode.startsWith("rec-")

        // Cadre de la portion d'écran (repère de la fenêtre = de l'écran)
        property var sel: ({ x: 0, y: 0, w: 0, h: 0 })
        function defaultSel() {
            const w = Math.round(width * 0.5), h = Math.round(height * 0.5);
            return { x: Math.round((width - w) / 2), y: Math.round((height - h) / 2), w: w, h: h };
        }
        function setSel(r) {
            sel = r;
            Shots.selection = r;
        }
        onWidthChanged: if (visible) resetSel()
        onHeightChanged: if (visible) resetSel()
        function resetSel() {
            if (width <= 0 || height <= 0) return;
            const r = Shots.selection;
            sel = Shots.rememberSelection && r && r.w > 0 && r.x + r.w <= width && r.y + r.h <= height
                ? r : defaultSel();
        }
        // « x,y lxh » en coordonnées globales (grim, wf-recorder)
        function selGeom() {
            return (screen.x + Math.round(sel.x)) + "," + (screen.y + Math.round(sel.y)) + " "
                + Math.max(1, Math.round(sel.w)) + "x" + Math.max(1, Math.round(sel.h));
        }

        property Item glassBackdrop: backdrop
        GlassBackdrop {
            id: backdrop
            mode: "snapshot"
            screen: win.screen
            want: (Shots.toolbarOpen || win.progress > 0) && !Shots.busy && !Shots.recording
        }
        visible: backdrop.pass
        onVisibleChanged: if (visible) { mode = Shots.lastMode; optionsOpen = false; resetSel(); }

        // "macos-lg-*" : pas de flou Hyprland (le verre floute et réfracte lui-même)
        WlrLayershell.namespace: "macos-lg-screenshot-toolbar"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Shots.toolbarOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        // La barre et le menu captent la souris ; tout l'écran en mode portion
        mask: Region {
            item: bar
            Region { item: menu }
            Region { item: selInput }
        }

        function commit() {
            const g = areaMode ? selGeom() : "";
            if (recMode) Shots.record(mode.substring(4), g);
            else Shots.capture(mode, g);
        }

        Item {
            id: focusItem
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: {
                if (win.optionsOpen) win.optionsOpen = false;
                else Shots.toolbarOpen = false;
            }
            Keys.onReturnPressed: win.commit()
            Keys.onEnterPressed: win.commit()
        }

        // ---- Cadre de sélection (Capture / Record Selected Portion) ----
        Item {
            id: selFrame
            anchors.fill: parent
            visible: win.areaMode && win.progress > 0
            opacity: win.progress
            readonly property color dim: Qt.rgba(0, 0, 0, 0.30)
            // Extérieur assombri
            Rectangle { x: 0; y: 0; width: parent.width; height: win.sel.y; color: selFrame.dim }
            Rectangle { x: 0; y: win.sel.y + win.sel.h; width: parent.width; height: parent.height - y; color: selFrame.dim }
            Rectangle { x: 0; y: win.sel.y; width: win.sel.x; height: win.sel.h; color: selFrame.dim }
            Rectangle { x: win.sel.x + win.sel.w; y: win.sel.y; width: parent.width - x; height: win.sel.h; color: selFrame.dim }
            // Bord : tirets blancs et noirs de 1 px (lisible sur tous les fonds)
            Canvas {
                id: border
                x: Math.round(win.sel.x) - 1
                y: Math.round(win.sel.y) - 1
                width: Math.round(win.sel.w) + 2
                height: Math.round(win.sel.h) + 2
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    c.lineWidth = 1;
                    c.strokeStyle = "white";
                    c.strokeRect(0.5, 0.5, width - 1, height - 1);
                    c.setLineDash([4, 4]);
                    c.strokeStyle = "black";
                    c.strokeRect(0.5, 0.5, width - 1, height - 1);
                }
            }
            // Poignées : coins et milieux des côtés
            Repeater {
                model: [[0, 0], [0.5, 0], [1, 0], [1, 0.5], [1, 1], [0.5, 1], [0, 1], [0, 0.5]]
                Rectangle {
                    required property var modelData
                    width: 9
                    height: 9
                    radius: 4.5
                    x: Math.round(win.sel.x + win.sel.w * modelData[0] - width / 2)
                    y: Math.round(win.sel.y + win.sel.h * modelData[1] - height / 2)
                    color: "#8E8E93"
                    border.width: 1.5
                    border.color: "white"
                }
            }
        }
        // Souris du cadre : déplacer (dedans), redimensionner (bords, poignées),
        // nouveau cadre (dehors)
        MouseArea {
            id: selInput
            readonly property bool live: win.areaMode && Shots.toolbarOpen && win.visible
            width: live ? win.width : 0
            height: live ? win.height : 0
            hoverEnabled: true
            property string op: ""
            property real px: 0
            property real py: 0
            property var start: null
            function hit(x, y) {
                const s = win.sel, m = 6;
                const nl = Math.abs(x - s.x) <= m, nr = Math.abs(x - s.x - s.w) <= m;
                const nt = Math.abs(y - s.y) <= m, nb = Math.abs(y - s.y - s.h) <= m;
                const inX = x >= s.x - m && x <= s.x + s.w + m, inY = y >= s.y - m && y <= s.y + s.h + m;
                let o = "";
                if (nt && inX) o += "t";
                else if (nb && inX) o += "b";
                if (nl && inY) o += "l";
                else if (nr && inY) o += "r";
                if (o) return o;
                if (x > s.x && x < s.x + s.w && y > s.y && y < s.y + s.h) return "move";
                return "new";
            }
            function cursorFor(o) {
                switch (o) {
                case "tl": case "br": return Qt.SizeFDiagCursor;
                case "tr": case "bl": return Qt.SizeBDiagCursor;
                case "t": case "b": return Qt.SizeVerCursor;
                case "l": case "r": return Qt.SizeHorCursor;
                case "move": return pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor;
                default: return Qt.CrossCursor;
                }
            }
            cursorShape: cursorFor(pressed ? op : hit(mouseX, mouseY))
            onPressed: mouse => {
                win.optionsOpen = false;
                op = hit(mouse.x, mouse.y);
                px = mouse.x;
                py = mouse.y;
                if (op === "new") {
                    start = { x: mouse.x, y: mouse.y, w: 0, h: 0 };
                    op = "br";
                } else start = Object.assign({}, win.sel);
            }
            onPositionChanged: mouse => {
                if (!pressed || !start) return;
                const dx = mouse.x - px, dy = mouse.y - py, s = start;
                if (op === "move") {
                    win.sel = { x: Math.max(0, Math.min(win.width - s.w, s.x + dx)),
                                y: Math.max(0, Math.min(win.height - s.h, s.y + dy)), w: s.w, h: s.h };
                    return;
                }
                let l = s.x, t = s.y, r = s.x + s.w, b = s.y + s.h;
                if (op.includes("l")) l += dx;
                if (op.includes("r")) r += dx;
                if (op.includes("t")) t += dy;
                if (op.includes("b")) b += dy;
                l = Math.max(0, Math.min(win.width, l)); r = Math.max(0, Math.min(win.width, r));
                t = Math.max(0, Math.min(win.height, t)); b = Math.max(0, Math.min(win.height, b));
                win.sel = { x: Math.round(Math.min(l, r)), y: Math.round(Math.min(t, b)),
                            w: Math.round(Math.abs(r - l)), h: Math.round(Math.abs(b - t)) };
            }
            onReleased: {
                // Simple clic hors du cadre : on garde l'ancien
                if (win.sel.w < 4 || win.sel.h < 4) win.sel = start && start.w > 0 ? start : win.defaultSel();
                win.setSel(win.sel);
                start = null;
            }
        }

        // ---- Barre ----
        Item {
            id: bar
            width: barRow.implicitWidth + 8 + 9
            height: 52
            anchors.horizontalCenter: parent.horizontalCenter
            // Bas de la barre à 128 pt du bas de l'écran (au-dessus du Dock)
            y: parent.height - height - 128 + (1 - win.progress) * 12
            opacity: win.progress
            scale: 0.97 + 0.03 * win.progress

            NotifGlass {
                anchors.fill: parent
                radius: 13
                tint: Theme.dark ? Qt.rgba(0.15, 0.15, 0.16, 0.78) : Qt.rgba(0.94, 0.945, 0.945, 0.80)
                shadowOffset: 6
                shadowBlur: 1.0
            }

            Row {
                id: barRow
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                // (×) : disque gris plein, croix blanche
                Item {
                    id: closeBtn
                    readonly property bool hovered: closeMouse.containsMouse
                    readonly property string tip: ""
                    width: 30
                    height: 37
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors.centerIn: parent
                        width: 17
                        height: 17
                        radius: 8.5
                        color: Theme.dark ? Qt.rgba(1, 1, 1, closeMouse.pressed ? 0.62 : 0.48)
                                          : Qt.rgba(0, 0, 0, closeMouse.pressed ? 0.62 : 0.50)
                        Symbol {
                            anchors.centerIn: parent
                            name: "xmark"
                            size: 15
                            color: Theme.dark ? "#1c1c1e" : "white"
                        }
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        onClicked: Shots.toolbarOpen = false
                    }
                }
                // (pas de séparateur entre × et le premier outil : image Apple)
                ToolButton { symbol: "screenshot.screen"; tip: "Capture Entire Screen"; m: "screen" }
                ToolButton { symbol: "screenshot.window"; tip: "Capture Selected Window"; m: "window" }
                ToolButton { symbol: "screenshot.selection"; tip: "Capture Selected Portion"; m: "area" }
                Sep {}
                ToolButton { symbol: "screenshot.screen.record"; tip: "Record Entire Screen"; m: "rec-screen"; width: 53 }
                ToolButton { symbol: "screenshot.window.record"; tip: "Record Selected Window"; m: "rec-window"; width: 53 }
                ToolButton { symbol: "screenshot.selection.record"; tip: "Record Selected Portion"; m: "rec-area"; width: 53 }
                Sep {}

                // Options ⌄ (texte gris, sans fond)
                Item {
                    id: optBtn
                    readonly property bool hovered: false
                    readonly property string tip: ""
                    width: optRow.implicitWidth + 12
                    height: 37
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: win.optionsOpen ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.09))
                                               : "transparent"
                    }
                    Row {
                        id: optRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Options"
                            color: win.inkColor
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                        Symbol {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 1
                            name: "chevron.down"
                            size: 11
                            color: win.inkColor
                        }
                    }
                    MouseArea {
                        id: optMouse
                        anchors.fill: parent
                        onClicked: win.optionsOpen = !win.optionsOpen
                    }
                }

                // [Capture] / [Record] : bouton bleu
                Item {
                    readonly property bool hovered: false
                    readonly property string tip: ""
                    width: Math.max(81, capLabel.implicitWidth + 32)
                    height: 37
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: capMouse.pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent
                    }
                    Text {
                        id: capLabel
                        anchors.centerIn: parent
                        text: win.recMode ? "Record" : "Capture"
                        color: "white"
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: capMouse
                        anchors.fill: parent
                        onClicked: win.commit()
                    }
                }
            }
        }

        // Gris des pictogrammes et de « Options » (image Apple : 119/255 sur 238)
        readonly property color inkColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.62) : Qt.rgba(0, 0, 0, 0.53)

        // Bulle d'aide (help tag) façon macOS : après ~1 s d'immobilité sur un
        // outil, sous le pointeur et légèrement à droite ; elle ne suit pas la souris.
        property Item tipBtn: null
        property point tipPos: Qt.point(0, 0)
        property bool tipShown: false
        function hoverTool(btn, on, x, y) {
            if (on) {
                if (tipBtn !== btn) { tipBtn = btn; tipShown = false; }
                if (!tipShown) { tipPos = btn.mapToItem(null, x, y); tipTimer.restart(); }
            } else if (tipBtn === btn) {
                tipBtn = null;
                tipShown = false;
                tipTimer.stop();
            }
        }
        Timer {
            id: tipTimer
            interval: 1000
            onTriggered: win.tipShown = win.tipBtn !== null
        }
        Item {
            id: tipBox
            readonly property Item dbg: {
                if (win.debugTip < 0) return null;
                const l = barRow.children.filter(c => c.tip);
                return l[win.debugTip] ?? null;
            }
            readonly property Item btn: dbg ?? (win.tipShown ? win.tipBtn : null)
            readonly property point at: dbg ? dbg.mapToItem(null, dbg.width / 2, dbg.height / 2) : win.tipPos
            readonly property string text: btn ? btn.tip : ""
            visible: text !== "" && !win.optionsOpen && win.progress > 0.99
            width: tipLabel.implicitWidth + 12
            height: 19
            x: Math.round(Math.max(0, Math.min(win.width - width, at.x + 2)))
            y: Math.round(Math.min(win.height - height - 2, at.y + 20))
            Rectangle {
                anchors.fill: parent
                radius: 5
                color: Theme.dark ? Qt.rgba(0.17, 0.17, 0.18, 0.96) : Qt.rgba(0.97, 0.97, 0.97, 0.97)
                border.width: 1
                border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12)
            }
            Text {
                id: tipLabel
                anchors.centerIn: parent
                text: tipBox.text
                color: Theme.label
                font.family: Theme.font
                font.pixelSize: 11
            }
        }

        // ---- Menu Options ----
        // Le contenu dépend de l'outil (aide Apple : « The available options vary
        // based on whether you're taking a screenshot or a screen recording ») :
        // Microphone et Show Mouse Clicks seulement en enregistrement.
        readonly property var mics: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
        function micName(n) { return n.description || n.nickname || n.name; }
        Item {
            id: menu
            visible: win.optionsOpen && Shots.toolbarOpen
            // Taille nulle quand il est fermé : il sert aussi de masque d'entrée
            readonly property real contentWidth: {
                let m = 0;
                for (const c of menuCol.children) if (c.visible) m = Math.max(m, c.implicitWidth);
                return m;
            }
            width: visible ? Math.ceil(contentWidth) + 12 : 0
            height: visible ? menuCol.implicitHeight + 12 : 0
            x: Math.round(Math.min(win.width - width - 4, bar.x + barRow.x + optBtn.x - 8))
            y: bar.y - height - 8

            NotifGlass {
                anchors.fill: parent
                radius: Theme.radiusMenu
                tint: Theme.menuBackground
                shadowOffset: 6
            }
            Column {
                id: menuCol
                x: 6
                y: 6
                width: parent.width - 12

                // Ordre de macOS Tahoe : Desktop, Documents, Clipboard, Mail, Messages,
                // Preview, emplacement choisi, Other Location…
                MenuHeader { text: "Save to" }
                MenuItem { text: "Desktop"; checked: Shots.saveTo === "desktop"; onTriggered: Shots.saveTo = "desktop" }
                MenuItem { text: "Documents"; checked: Shots.saveTo === "documents"; onTriggered: Shots.saveTo = "documents" }
                MenuItem { text: "Clipboard"; checked: Shots.saveTo === "clipboard"; onTriggered: Shots.saveTo = "clipboard" }
                MenuItem { text: "Mail"; checked: Shots.saveTo === "mail"; onTriggered: Shots.saveTo = "mail" }
                // Pas d'app Messages ici : grisé, comme une destination indisponible
                MenuItem { text: "Messages"; enabled: false; checked: Shots.saveTo === "messages" }
                MenuItem { text: "Preview"; checked: Shots.saveTo === "preview"; onTriggered: Shots.saveTo = "preview" }
                MenuItem {
                    visible: !!Shots.customDir
                    text: Shots.customDir.split("/").pop() || Shots.customDir
                    checked: Shots.saveTo === "custom"
                    onTriggered: Shots.saveTo = "custom"
                }
                MenuItem { text: "Other Location…"; onTriggered: Shots.chooseFolder() }
                MenuSep {}
                MenuHeader { text: "Timer" }
                MenuItem { text: "None"; checked: Shots.delay === 0; onTriggered: Shots.delay = 0 }
                MenuItem { text: "5 Seconds"; checked: Shots.delay === 5; onTriggered: Shots.delay = 5 }
                MenuItem { text: "10 Seconds"; checked: Shots.delay === 10; onTriggered: Shots.delay = 10 }
                MenuSep { visible: win.recMode }
                MenuHeader { visible: win.recMode; text: "Microphone" }
                MenuItem { visible: win.recMode; text: "None"; checked: !Shots.micDevice; onTriggered: Shots.micDevice = "" }
                Repeater {
                    model: win.recMode ? win.mics : []
                    MenuItem {
                        required property var modelData
                        text: win.micName(modelData)
                        checked: Shots.micDevice === modelData.name
                        onTriggered: Shots.micDevice = modelData.name
                    }
                }
                MenuSep {}
                MenuHeader { text: "Options" }
                MenuItem { text: "Show Floating Thumbnail"; checked: Shots.showThumbnail; onTriggered: Shots.showThumbnail = !Shots.showThumbnail }
                MenuItem { text: "Remember Last Selection"; checked: Shots.rememberSelection; onTriggered: Shots.rememberSelection = !Shots.rememberSelection }
                MenuItem { visible: !win.recMode; text: "Show Mouse Pointer"; checked: Shots.showPointer; onTriggered: Shots.showPointer = !Shots.showPointer }
                MenuItem { visible: win.recMode; text: "Show Mouse Clicks"; checked: Shots.showClicks; onTriggered: Shots.showClicks = !Shots.showClicks }
            }
        }

        // ---- Composants locaux ----
        component Sep: Item {
            width: 11
            height: 24
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: parent.height
                color: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12)
            }
        }

        // Outil : pictogramme gris ; choisi = fond gris arrondi (45 × 37 pt)
        component ToolButton: Item {
            id: tb
            property string symbol
            property string tip: ""
            property string m: ""
            readonly property bool selected: win.mode === m
            readonly property bool hovered: tbMouse.containsMouse
            width: 45
            height: 37
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            Rectangle {
                anchors.fill: parent
                radius: 8
                color: tb.selected ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.095))
                     : tbMouse.pressed ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05))
                     : "transparent"
            }
            Symbol {
                anchors.centerIn: parent
                name: tb.symbol
                size: 32
                color: win.inkColor
            }
            MouseArea {
                id: tbMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: win.mode = tb.m
                onContainsMouseChanged: win.hoverTool(tb, containsMouse, mouseX, mouseY)
                onPositionChanged: mouse => win.hoverTool(tb, true, mouse.x, mouse.y)
            }
        }

        component MenuHeader: Text {
            rightPadding: 16
            leftPadding: 10
            topPadding: 4
            bottomPadding: 2
            color: Theme.labelSecondary
            font.family: Theme.font
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        component MenuSep: Item {
            width: parent ? parent.width : 0
            height: 11
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 20
                height: 1
                color: Theme.separator
            }
        }

        component MenuItem: Item {
            id: mi
            property string text
            property bool checked: false
            signal triggered()
            implicitWidth: 26 + miLabel.implicitWidth + 16
            width: parent ? parent.width : 0
            height: 24
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMenuItem
                color: miMouse.containsMouse ? Theme.menuHighlight : "transparent"
            }
            Symbol {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: mi.checked
                name: "checkmark"
                size: 11
                color: miMouse.containsMouse ? Theme.menuHighlightText : Theme.label
            }
            Text {
                id: miLabel
                x: 26
                anchors.verticalCenter: parent.verticalCenter
                text: mi.text
                color: !mi.enabled ? Theme.labelTertiary : miMouse.containsMouse ? Theme.menuHighlightText : Theme.label
                font.family: Theme.font
                font.pixelSize: 13
            }
            MouseArea {
                id: miMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: mi.triggered()
            }
        }
    }

    // ---- Pastille d'enregistrement en cours ----
    // Masquée si la barre des menus affiche son bouton « Stop Recording »
    // (elle positionne Shots.menuBarStopButton = true).
    PanelWindow {
        id: recWin
        screen: win.screen
        visible: Shots.recording && !Shots.menuBarStopButton
        WlrLayershell.namespace: "macos-screenrecord"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true }
        margins.top: Theme.menuBarHeight + 8
        implicitWidth: recRow.implicitWidth + 24
        implicitHeight: 34
        color: "transparent"

        property real elapsed: 0
        Timer {
            interval: 500
            running: Shots.recording
            repeat: true
            triggeredOnStart: true
            onTriggered: recWin.elapsed = (Date.now() - Shots.recordStart) / 1000
        }

        NotifGlass {
            anchors.fill: parent
            radius: height / 2
            tint: Theme.glassThick
        }
        Row {
            id: recRow
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                radius: 5
                color: Theme.red
                SequentialAnimation on opacity {
                    running: Shots.recording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const s = Math.floor(recWin.elapsed);
                    return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0");
                }
                color: Theme.label
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: 11
                color: stopMouse.containsMouse ? Theme.fillHover : Theme.fill
                Symbol {
                    anchors.centerIn: parent
                    name: "stop.fill"
                    size: 12
                    color: Theme.label
                }
                MouseArea {
                    id: stopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Shots.stopRecording()
                }
            }
        }
    }
}
