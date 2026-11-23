import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.common

// Barre d'outils « Capture d'écran » de macOS (Cmd+Maj+5) :
//  (×) | écran entier · fenêtre · portion | enregistrer écran · enregistrer portion | Options ⌄  [Capturer]
// Capsule de verre centrée au-dessus du Dock. Échap ferme, Entrée capture.
// Pendant un enregistrement : pastille « ● 00:12 ■ » en haut de l'écran.
Scope {
    id: root

    GlobalShortcut {
        appid: "macos"
        name: "screenshot-ui"
        description: "Barre d'outils de capture d'écran"
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
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

        property string mode: Shots.lastMode     // screen | window | area | rec-screen | rec-area
        property bool optionsOpen: false
        property real progress: Shots.toolbarOpen ? 1 : 0
        Behavior on progress { NumberAnimation { duration: Shots.toolbarOpen ? 320 : 180; easing.type: Easing.OutCubic } }

        visible: Shots.toolbarOpen || progress > 0
        onVisibleChanged: if (visible) { mode = Shots.lastMode; optionsOpen = false; }

        WlrLayershell.namespace: "macos-screenshot-toolbar"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Shots.toolbarOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { bottom: true }
        margins.bottom: 104
        implicitWidth: 620
        implicitHeight: 460
        color: "transparent"

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

        // ---- Capsule ----
        Item {
            id: bar
            width: barRow.implicitWidth + 12
            height: 50
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 8 + (1 - win.progress) * 16
            opacity: win.progress
            scale: 0.96 + 0.04 * win.progress

            NotifGlass {
                anchors.fill: parent
                radius: height / 2
                tint: Theme.glassThick
            }

            Row {
                id: barRow
                anchors.centerIn: parent
                spacing: 2

                // (×) fermer
                ToolButton {
                    symbol: "xmark"
                    symbolSize: 10
                    round: true
                    tip: "Fermer"
                    onClicked: Shots.toolbarOpen = false
                }
                Sep {}
                ToolButton { symbol: "rectangle.inset.filled"; tip: "Capturer l'écran entier"; selected: win.mode === "screen"; onClicked: win.mode = "screen" }
                ToolButton { symbol: "macwindow.on.rectangle"; tip: "Capturer la fenêtre sélectionnée"; selected: win.mode === "window"; onClicked: win.mode = "window" }
                ToolButton { symbol: "rectangle.dashed"; tip: "Capturer la portion sélectionnée"; selected: win.mode === "area"; onClicked: win.mode = "area" }
                Sep {}
                ToolButton { symbol: "rectangle.inset.filled.badge.record"; tip: "Enregistrer l'écran entier"; selected: win.mode === "rec-screen"; onClicked: win.mode = "rec-screen" }
                ToolButton { symbol: "rectangle.dashed.badge.record"; tip: "Enregistrer la portion sélectionnée"; selected: win.mode === "rec-area"; onClicked: win.mode = "rec-area" }
                Sep {}

                // Options ⌄
                Item {
                    id: optBtn
                    width: optRow.implicitWidth + 22
                    height: 38
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: win.optionsOpen ? Qt.rgba(1, 1, 1, Theme.dark ? 0.16 : 0.5)
                             : optMouse.containsMouse ? Theme.fill : "transparent"
                    }
                    Row {
                        id: optRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Options"
                            color: Theme.label
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                        Symbol {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "chevron.down"
                            size: 9
                            color: Theme.label
                        }
                    }
                    MouseArea {
                        id: optMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: win.optionsOpen = !win.optionsOpen
                    }
                }

                // [Capturer] / [Enregistrer]
                Item {
                    width: capLabel.implicitWidth + 30
                    height: 38
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: capMouse.pressed ? Qt.rgba(1, 1, 1, Theme.dark ? 0.30 : 0.7)
                             : capMouse.containsMouse ? Qt.rgba(1, 1, 1, Theme.dark ? 0.22 : 0.6)
                             : Qt.rgba(1, 1, 1, Theme.dark ? 0.14 : 0.45)
                        border.width: 1
                        border.color: Theme.glassStroke
                    }
                    Text {
                        id: capLabel
                        anchors.centerIn: parent
                        text: win.mode.startsWith("rec-") ? "Enregistrer" : "Capturer"
                        color: Theme.label
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        id: capMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: win.commit()
                    }
                }
            }
        }

        // Infobulle du bouton survolé (au-dessus de la capsule)
        Item {
            id: tipBox
            readonly property Item btn: {
                for (const c of barRow.children) if (c.hovered && c.tip) return c;
                return null;
            }
            readonly property string text: btn ? btn.tip : ""
            readonly property real cx: btn ? bar.x + barRow.x + btn.x + btn.width / 2 : 0
            visible: text !== "" && !win.optionsOpen
            width: tipLabel.implicitWidth + 16
            height: 22
            x: Math.max(0, Math.min(win.width - width, cx - width / 2))
            y: bar.y - height - 8
            NotifGlass {
                anchors.fill: parent
                radius: 7
                tint: Theme.glassThick
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
            width: 260
            height: menuCol.implicitHeight + 12
            x: Math.min(win.width - width - 4, bar.x + barRow.x + optBtn.x - 8)
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

                MenuHeader { text: "Enregistrer dans" }
                // Ordre de macOS : Bureau, Documents, Presse-papiers, (Mail, Messages :
                // sans équivalent ici), Aperçu, emplacements choisis, Autre emplacement…
                MenuItem { text: "Bureau"; checked: Shots.saveTo === "desktop"; onTriggered: Shots.saveTo = "desktop" }
                MenuItem { text: "Documents"; checked: Shots.saveTo === "documents"; onTriggered: Shots.saveTo = "documents" }
                MenuItem { text: "Presse-papiers"; checked: Shots.saveTo === "clipboard"; onTriggered: Shots.saveTo = "clipboard" }
                MenuItem { text: "Aperçu"; checked: Shots.saveTo === "preview"; onTriggered: Shots.saveTo = "preview" }
                MenuItem { text: "Captures d’écran"; checked: Shots.saveTo === "screenshots"; onTriggered: Shots.saveTo = "screenshots" }
                MenuItem {
                    visible: !!Shots.customDir
                    text: Shots.customDir.split("/").pop() || Shots.customDir
                    checked: Shots.saveTo === "custom"
                    onTriggered: Shots.saveTo = "custom"
                }
                MenuItem { text: "Autre emplacement…"; onTriggered: Shots.chooseFolder() }
                MenuSep {}
                MenuHeader { text: "Minuteur" }
                MenuItem { text: "Aucun"; checked: Shots.delay === 0; onTriggered: Shots.delay = 0 }
                MenuItem { text: "5 secondes"; checked: Shots.delay === 5; onTriggered: Shots.delay = 5 }
                MenuItem { text: "10 secondes"; checked: Shots.delay === 10; onTriggered: Shots.delay = 10 }
                MenuSep {}
                MenuHeader { text: "Options" }
                MenuItem { text: "Afficher la vignette flottante"; checked: Shots.showThumbnail; onTriggered: Shots.showThumbnail = !Shots.showThumbnail }
                MenuItem { text: "Afficher le pointeur de la souris"; checked: Shots.showPointer; onTriggered: Shots.showPointer = !Shots.showPointer }
            }
        }

        // ---- Composants locaux ----
        component Sep: Rectangle {
            width: 13
            height: 24
            color: "transparent"
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: parent.height
                color: Theme.separator
            }
        }

        component ToolButton: Item {
            id: tb
            property string symbol
            property int symbolSize: 22
            property bool selected: false
            property bool round: false
            property string tip: ""
            readonly property bool hovered: tbMouse.containsMouse
            signal clicked()
            width: round ? 38 : 44
            height: 38
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            Rectangle {
                anchors.fill: parent
                anchors.margins: tb.round ? 7 : 0
                radius: height / 2
                color: tb.selected ? Qt.rgba(1, 1, 1, Theme.dark ? 0.18 : 0.55)
                     : tb.round ? (tbMouse.containsMouse ? Theme.fillHover : Theme.fill)
                     : tbMouse.containsMouse ? Theme.fill : "transparent"
            }
            Symbol {
                anchors.centerIn: parent
                name: tb.symbol
                size: tb.symbolSize
                color: Theme.label
            }
            MouseArea {
                id: tbMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: tb.clicked()
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
