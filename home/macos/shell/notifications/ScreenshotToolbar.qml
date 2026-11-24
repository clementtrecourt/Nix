import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.common

// Barre d'outils « Screenshot » de macOS Tahoe (Maj+Cmd+5), d'après l'image Apple
// « Take a screenshot on Mac » (macOS 26, 572 × 53 pt) :
//  (×) | Capture Entire Screen · Selected Window · Selected Portion |
//        Record Entire Screen · Selected Window · Selected Portion | Options ⌄  [Capture]
// Plaque de verre arrondie (~12 pt) centrée au-dessus du Dock ; outil choisi sur
// fond gris arrondi ; bouton bleu « Capture » / « Record ». Échap ferme, Entrée
// capture. La barre disparaît AVANT la capture (jamais dans l'image).
// Pendant un enregistrement : pastille « ● 00:12 ■ » en haut de l'écran.
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
        property Item glassBackdrop: backdrop
        GlassBackdrop {
            id: backdrop
            mode: "snapshot"
            screen: win.screen
            want: (Shots.toolbarOpen || win.progress > 0) && !Shots.busy && !Shots.recording
        }
        visible: backdrop.pass
        onVisibleChanged: if (visible) { mode = Shots.lastMode; optionsOpen = false; }

        // "macos-lg-*" : pas de flou Hyprland (le verre floute et réfracte lui-même)
        WlrLayershell.namespace: "macos-lg-screenshot-toolbar"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Shots.toolbarOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { bottom: true }
        margins.bottom: 104
        implicitWidth: 680
        implicitHeight: 560
        color: "transparent"

        // Seuls la barre, l'infobulle et le menu captent la souris
        mask: Region {
            item: bar
            Region { item: menu }
        }

        function commit() {
            if (mode.startsWith("rec-")) Shots.record(mode.substring(4));
            else Shots.capture(mode);
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

        // ---- Barre ----
        Item {
            id: bar
            width: barRow.implicitWidth + 8 + 9
            height: 52
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 24 + (1 - win.progress) * 12
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
                Sep {}
                ToolButton { symbol: "screenshot.screen"; tip: "Capture Entire Screen"; m: "screen" }
                ToolButton { symbol: "screenshot.window"; tip: "Capture Selected Window"; m: "window" }
                ToolButton { symbol: "screenshot.selection"; tip: "Capture Selected Portion"; m: "area" }
                Sep {}
                ToolButton { symbol: "screenshot.screen.record"; tip: "Record Entire Screen"; m: "rec-screen"; width: 55 }
                ToolButton { symbol: "screenshot.window.record"; tip: "Record Selected Window"; m: "rec-window"; width: 55 }
                ToolButton { symbol: "screenshot.selection.record"; tip: "Record Selected Portion"; m: "rec-area"; width: 55 }
                Sep {}

                // Options ⌄ (texte gris, sans fond)
                Item {
                    id: optBtn
                    readonly property bool hovered: false
                    readonly property string tip: ""
                    width: optRow.implicitWidth + 16
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
                            size: 9
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
                        radius: 9
                        color: capMouse.pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent
                    }
                    Text {
                        id: capLabel
                        anchors.centerIn: parent
                        text: win.mode.startsWith("rec-") ? "Record" : "Capture"
                        color: "white"
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.Medium
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

        // Bulle d'aide (help tag) du bouton survolé, au-dessus de la barre
        Item {
            id: tipBox
            readonly property Item btn: {
                const l = barRow.children.filter(c => c.tip);
                if (win.debugTip >= 0) return l[win.debugTip] ?? null;
                for (const c of l) if (c.hovered) return c;
                return null;
            }
            readonly property string text: btn ? btn.tip : ""
            readonly property real cx: btn ? bar.x + barRow.x + btn.x + btn.width / 2 : 0
            visible: text !== "" && !win.optionsOpen && win.progress > 0.99
            width: tipLabel.implicitWidth + 16
            height: 22
            x: Math.round(Math.max(0, Math.min(win.width - width, cx - width / 2)))
            y: bar.y - height - 8
            NotifGlass {
                anchors.fill: parent
                radius: 7
                tint: Theme.dark ? Qt.rgba(0.17, 0.17, 0.18, 0.85) : Qt.rgba(0.97, 0.97, 0.97, 0.88)
                shadowOffset: 2
                shadowBlur: 0.4
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
        Item {
            id: menu
            visible: win.optionsOpen && Shots.toolbarOpen
            // Taille nulle quand il est fermé : il sert aussi de masque d'entrée
            width: visible ? 240 : 0
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

                MenuHeader { text: "Save to" }
                // Ordre de macOS : Bureau, Documents, Presse-papiers, (Mail, Messages :
                // sans équivalent ici), Aperçu, emplacements choisis, Autre emplacement…
                MenuItem { text: "Desktop"; checked: Shots.saveTo === "desktop"; onTriggered: Shots.saveTo = "desktop" }
                MenuItem { text: "Documents"; checked: Shots.saveTo === "documents"; onTriggered: Shots.saveTo = "documents" }
                MenuItem { text: "Clipboard"; checked: Shots.saveTo === "clipboard"; onTriggered: Shots.saveTo = "clipboard" }
                MenuItem { text: "Preview"; checked: Shots.saveTo === "preview"; onTriggered: Shots.saveTo = "preview" }
                MenuItem { text: "Screenshots"; checked: Shots.saveTo === "screenshots"; onTriggered: Shots.saveTo = "screenshots" }
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
                MenuSep {}
                MenuHeader { text: "Microphone" }
                MenuItem { text: "None"; checked: !Shots.microphone; onTriggered: Shots.microphone = false }
                MenuItem { text: "Default Microphone"; checked: Shots.microphone; onTriggered: Shots.microphone = true }
                MenuSep {}
                MenuHeader { text: "Options" }
                MenuItem { text: "Show Floating Thumbnail"; checked: Shots.showThumbnail; onTriggered: Shots.showThumbnail = !Shots.showThumbnail }
                MenuItem { text: "Show Mouse Pointer"; checked: Shots.showPointer; onTriggered: Shots.showPointer = !Shots.showPointer }
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
            }
        }

        component MenuHeader: Text {
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
                x: 26
                anchors.verticalCenter: parent.verticalCenter
                text: mi.text
                color: miMouse.containsMouse ? Theme.menuHighlightText : Theme.label
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
    PanelWindow {
        id: recWin
        screen: win.screen
        visible: Shots.recording
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
