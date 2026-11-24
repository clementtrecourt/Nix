import QtQuick
import qs.common

// Appearance (Tahoe 26), d'après Apple mh15217 / mchldfdf4f86 (1,61 px/pt) :
// vignettes Auto / Light / Dark de 66 × 43 pt au pas de 77 pt (anneau
// d'accent de 3 pt sur la vignette choisie, libellé 11 pt dessous, gras si
// choisi), Liquid Glass (Clear / Tinted), Theme > Color (9 pastilles de 22 pt
// au pas de 35 pt), Text highlight color, Icon & widget style, Folder color,
// Windows > Sidebar icon size, Tint window background…, Show scroll bars,
// Click in the scroll bar to.
PaneBase {
    id: root

    // ---- Vignette sélectionnable (Appearance, Liquid Glass, Icon style) ----
    component Choice: Item {
        id: ch
        property string label
        property bool selected
        property real tw: 66
        property real th: 43
        property real tr: 6
        default property alias art: artBox.data
        signal picked()
        width: tw
        height: th + 22
        Rectangle {
            x: -3; y: -3
            width: ch.tw + 6
            height: ch.th + 6
            radius: ch.tr + 3
            color: "transparent"
            border.width: 3
            border.color: SStyle.accent
            visible: ch.selected
        }
        Item {
            id: artBox
            width: ch.tw
            height: ch.th
            clip: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: ch.th + 6
            text: ch.label
            font.family: Theme.font
            font.pixelSize: SStyle.small
            font.weight: ch.selected ? Font.DemiBold : Font.Normal
            color: ch.selected ? SStyle.label : SStyle.secondary
        }
        MouseArea { anchors.fill: parent; onClicked: ch.picked() }
    }

    // Mini fenêtre sur fond Tahoe (vignettes d'apparence)
    component Mini: Item {
        id: mini
        property bool darkArt
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            radius: 6
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: mini.darkArt ? "#1B2A6B" : "#9CC4F2" }
                GradientStop { position: 1; color: mini.darkArt ? "#3150C8" : "#3C78E0" }
            }
        }
        // Fenêtre arrière (barre bleue)
        Rectangle {
            x: 6; y: 6; width: parent.width - 18; height: 16; radius: 3
            color: mini.darkArt ? "#2C2C2E" : "#F4F4F6"
            Rectangle { x: 3; y: 4; width: parent.width * 0.6; height: 5; radius: 2; color: "#2F7BF5" }
        }
        // Fenêtre avant (feux)
        Rectangle {
            x: parent.width * 0.28; y: parent.height * 0.52; width: parent.width * 0.62; height: parent.height * 0.42; radius: 4
            color: mini.darkArt ? "#1C1C1E" : "#FFFFFF"
            Row {
                x: 5
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Repeater {
                    model: ["#FF5F57", "#FEBC2E", "#28C840"]
                    Rectangle { required property string modelData; width: 5; height: 5; radius: 2.5; color: modelData }
                }
            }
        }
    }

    SGroup {
        SRow {
            title: "Appearance"
            minHeight: 85
            alignTop: true
            controlTop: 13
            Row {
                spacing: 11
                Choice {
                    label: "Auto"
                    selected: Prefs.appearance === "auto"
                    onPicked: Prefs.setAppearance("auto")
                    Mini { darkArt: false }
                    Item {
                        anchors.fill: parent
                        clip: true
                        Item {
                            x: parent.width / 2
                            width: parent.width / 2
                            height: parent.height
                            clip: true
                            Item { x: -parent.x; width: 66; height: 43; Mini { darkArt: true } }
                        }
                    }
                }
                Choice { label: "Light"; selected: Prefs.appearance === "light"; onPicked: Prefs.setAppearance("light"); Mini { darkArt: false } }
                Choice { label: "Dark"; selected: Prefs.appearance === "dark"; onPicked: Prefs.setAppearance("dark"); Mini { darkArt: true } }
            }
        }
        SRow {
            title: "Liquid Glass"
            subtitle: "Choose your preferred look for Liquid Glass."
            minHeight: 84
            alignTop: true
            controlTop: 13
            Row {
                spacing: 11
                Repeater {
                    model: [["clear", "Clear"], ["tinted", "Tinted"]]
                    Choice {
                        required property var modelData
                        label: modelData[1]
                        selected: (Prefs.v.liquidGlass ?? "clear") === modelData[0]
                        onPicked: Prefs.set("liquidGlass", modelData[0])
                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: "#F3C36B" }
                                GradientStop { position: 0.45; color: "#7FB7F0" }
                                GradientStop { position: 1; color: "#2F6FE0" }
                            }
                        }
                        Rectangle {
                            x: 8; y: 10; width: 50; height: 22; radius: 11
                            color: modelData[0] === "clear" ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(0.93, 0.93, 0.95, 0.92)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.8)
                        }
                    }
                }
            }
        }
    }

    SSection { text: "Theme" }
    SGroup {
        SRow {
            title: "Color"
            minHeight: 60
            alignTop: true
            controlTop: 6
            Row {
                spacing: 13
                Repeater {
                    model: Prefs.accents
                    Item {
                        id: sw_
                        required property var modelData
                        readonly property bool sel: Prefs.v.accent === modelData.id
                        width: 22
                        height: 40
                        Rectangle {
                            anchors.centerIn: dot
                            width: 30; height: 30; radius: 15
                            color: "transparent"
                            border.width: 3
                            border.color: SStyle.accent
                            visible: sw_.sel
                        }
                        Rectangle {
                            id: dot
                            y: 4
                            width: 22; height: 22; radius: 11
                            color: Theme.dark ? sw_.modelData.dark : sw_.modelData.light
                            border.width: 0.5
                            border.color: Qt.rgba(0, 0, 0, 0.12)
                            // Multicolore : roue de couleurs
                            ConicalGradientCircle { visible: sw_.modelData.id === "multicolor" }
                        }
                        Text {
                            visible: sw_.sel
                            anchors.horizontalCenter: dot.horizontalCenter
                            y: 31
                            text: sw_.modelData.name
                            font.family: Theme.font
                            font.pixelSize: SStyle.small
                            color: SStyle.secondary
                        }
                        MouseArea { anchors.fill: dot; anchors.margins: -4; onClicked: Prefs.setAccent(sw_.modelData.id) }
                    }
                }
            }
        }
        SRow {
            title: "Text highlight color"
            SPopUp {
                options: [{ text: "Automatic", value: "automatic" }, { separator: true }].concat(Prefs.accents.slice(1).map(a => ({ text: a.name, value: a.id }))).concat([{ separator: true }, { text: "Other…", value: "other", enabled: false }])
                value: Prefs.v.highlight
                swatch: Prefs.v.highlight === "automatic" ? Qt.rgba(SStyle.accent.r, SStyle.accent.g, SStyle.accent.b, 0.55)
                                                           : (Prefs.accentInfo(Prefs.v.highlight).light)
                onActivated: (v) => Prefs.set("highlight", v)
            }
        }
    }

    SGroup {
        SRow {
            title: "Icon & widget style"
            minHeight: 86
            alignTop: true
            controlTop: 13
            Row {
                spacing: 18
                Repeater {
                    model: [["default", "Default"], ["dark", "Dark"], ["clear", "Clear"], ["tinted", "Tinted"]]
                    Choice {
                        required property var modelData
                        tw: 32; th: 32; tr: 8
                        label: modelData[1]
                        selected: Prefs.v.iconStyle === modelData[0]
                        onPicked: Prefs.set("iconStyle", modelData[0])
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            gradient: Gradient {
                                GradientStop { position: 0; color: ({ "default": "#5AB0FF", dark: "#3A3A3C", clear: "#C9CBD0", tinted: "#6BB6FF" })[modelData[0]] }
                                GradientStop { position: 1; color: ({ "default": "#1E6FE0", dark: "#0E0E10", clear: "#8E9096", tinted: "#2C8CF2" })[modelData[0]] }
                            }
                            Symbol {
                                visible: modelData[0] === "default" || modelData[0] === "dark"
                                x: 16; y: 6; size: 11; name: "sun.max.fill"; color: "#FFD60A"
                            }
                            Symbol {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 2
                                size: 21
                                name: "icloud.fill"
                                color: modelData[0] === "dark" ? "#C7C7CC" : "#FFFFFF"
                            }
                        }
                    }
                }
            }
        }
        SRow {
            title: "Folder color"
            SPopUp {
                options: [{ text: "Automatic", value: "automatic" }, { separator: true }].concat(Prefs.accents.slice(1).map(a => ({ text: a.name, value: a.id })))
                value: Prefs.v.folderColor
                swatch: Prefs.v.folderColor === "automatic" ? SStyle.accent : Prefs.accentInfo(Prefs.v.folderColor).light
                onActivated: (v) => Prefs.set("folderColor", v)
            }
        }
    }

    SSection { text: "Windows" }
    SGroup {
        SRow {
            title: "Sidebar icon size"
            SPopUp {
                options: [{ text: "Small", value: "small" }, { text: "Medium", value: "medium" }, { text: "Large", value: "large" }]
                value: Prefs.v.sidebarIconSize
                onActivated: (v) => Prefs.set("sidebarIconSize", v)
            }
        }
        SRow {
            title: "Tint window background with wallpaper color"
            SSwitch { checked: Prefs.v.tintWindow; onToggled: (on) => Prefs.set("tintWindow", on) }
        }
    }
    SGroup {
        Item {
            width: parent.width
            height: sbCol.implicitHeight + 22
            Column {
                id: sbCol
                x: SStyle.pad
                y: 11
                spacing: 6
                Text { text: "Show scroll bars"; font.family: Theme.font; font.pixelSize: SStyle.body; color: SStyle.label; bottomPadding: 2 }
                Repeater {
                    model: [["auto", "Automatically based on mouse or trackpad"], ["scrolling", "When scrolling"], ["always", "Always"]]
                    SRadio { required property var modelData; text: modelData[1]; checked: Prefs.v.scrollBars === modelData[0]; onClicked: Prefs.set("scrollBars", modelData[0]) }
                }
            }
        }
        Item {
            width: parent.width
            height: clCol.implicitHeight + 22
            Rectangle { x: SStyle.pad; width: parent.width - 2 * SStyle.pad; height: 1; color: SStyle.separator }
            Column {
                id: clCol
                x: SStyle.pad
                y: 11
                spacing: 6
                Text { text: "Click in the scroll bar to"; font.family: Theme.font; font.pixelSize: SStyle.body; color: SStyle.label; bottomPadding: 2 }
                Repeater {
                    model: [["page", "Jump to the next page"], ["spot", "Jump to the spot that’s clicked"]]
                    SRadio { required property var modelData; text: modelData[1]; checked: Prefs.v.clickScrollBar === modelData[0]; onClicked: Prefs.set("clickScrollBar", modelData[0]) }
                }
            }
        }
    }
}
