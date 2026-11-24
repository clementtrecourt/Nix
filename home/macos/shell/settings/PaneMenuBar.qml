import QtQuick
import qs.common
import qs.services

// Menu Bar (Tahoe 26 : remplace l'ancien panneau Control Center ; capture 2x
// MacStories) : masquage automatique, fond de la barre, éléments récents,
// Menu Bar Controls (cases à cocher + pastille + « Show When Active »).
// Choix persistés dans l'état de Réglages (menuBarAutohide,
// menuBarBackground, recentItems, menuControls) pour la barre des menus.
PaneBase {
    id: root

    function ctl(id) { return (Prefs.v.menuControls ?? {})[id] ?? "hide"; }
    function setCtl(id, v) { Prefs.setIn("menuControls", id, v); }
    readonly property var whenActive: [{ text: "Always Show in Menu Bar", value: "show" }, { text: "Show When Active", value: "active" }]

    SGroup {
        SRow {
            title: "Automatically hide and show the menu bar"
            SPopUp {
                options: [{ text: "Always", value: "always" }, { text: "On Desktop Only", value: "desktop" }, { text: "In Full Screen Only", value: "fullscreen" }, { text: "Never", value: "never" }]
                value: Prefs.v.menuBarAutohide
                onActivated: (v) => Prefs.set("menuBarAutohide", v)
            }
        }
        SRow {
            title: "Show menu bar background"
            SSwitch { checked: Prefs.v.menuBarBackground; onToggled: (on) => Prefs.set("menuBarBackground", on) }
        }
        SRow {
            title: "Recent documents, applications, and servers"
            SPopUp {
                options: [0, 5, 10, 15, 20, 30, 50].map(n => ({ text: n ? String(n) : "None", value: n }))
                value: Prefs.v.recentItems
                onActivated: (v) => Prefs.set("recentItems", v)
            }
        }
    }

    SSection { text: "Menu Bar Controls" }
    SGroup {
        Item {
            width: parent.width
            height: 88
            Text {
                x: SStyle.pad; y: 12
                width: parent.width * 0.6
                wrapMode: Text.WordWrap
                text: "System and app controls can be configured to appear in both Control Center and the menu bar."
                font.family: Theme.font; font.pixelSize: SStyle.small
                lineHeight: 14; lineHeightMode: Text.FixedHeight
                color: SStyle.secondary
            }
            SButton { x: SStyle.pad; y: 52; text: "Add Controls…"; onClicked: ShellState.open("controlcenter") }
            // Illustration : grille de contrôles
            Grid {
                anchors.right: parent.right
                anchors.rightMargin: 12
                y: 12
                columns: 3
                spacing: 4
                Repeater {
                    model: 9
                    Rectangle { width: 18; height: 18; radius: 9; color: SStyle.controlFill }
                }
            }
        }
    }
    SGroup {
        SRow {
            title: "Clock"
            leadOffset: 22
            pane: ({ icon: "clock", c: ["#FFFFFF", "#ECECEC"], glyph: "#3A3A3C" })
            SButton { text: "Clock Options…"; onClicked: Nav.go("datetime") }
        }
        Repeater {
            model: [
                { id: "spotlight", name: "Spotlight", pane: Nav.info("spotlight") },
                { id: "wifi", name: "Wi‑Fi", pane: Nav.info("wifi") },
                { id: "bluetooth", name: "Bluetooth", pane: Nav.info("bluetooth") },
                { id: "focus", name: "Focus", pane: Nav.info("focus"), popup: true },
                { id: "screenMirroring", name: "Screen Mirroring", pane: ({ icon: "rectangle.on.rectangle", c: ["#6BD8F5", "#26B2E0"] }), popup: true },
                { id: "display", name: "Display", pane: Nav.info("displays"), popup: true },
                { id: "sound", name: "Sound", pane: Nav.info("sound"), popup: true },
                { id: "nowPlaying", name: "Now Playing", pane: ({ icon: "music.note", c: ["#FFFFFF", "#ECECEC"], glyph: "#FF2D55" }), popup: true },
                { id: "battery", name: "Battery", pane: Nav.info("battery"), popup: false },
                { id: "userSwitch", name: "Fast User Switching", pane: ({ icon: "person.crop.circle", c: Nav.gray }), user: true }
            ]
            SRow {
                id: cr
                required property var modelData
                readonly property string state_: root.ctl(modelData.id)
                title: modelData.name
                pane: modelData.pane
                leadOffset: 22
                SPopUp {
                    visible: !!cr.modelData.popup || !!cr.modelData.user
                    enabledPopUp: cr.state_ !== "hide"
                    options: cr.modelData.user ? [{ text: "Full Name", value: "name" }, { text: "Account Name", value: "account" }, { text: "Icon", value: "icon" }] : root.whenActive
                    value: cr.modelData.user ? (Prefs.v.userSwitchStyle ?? "icon") : (cr.state_ === "hide" ? "active" : cr.state_)
                    onActivated: (v) => { if (cr.modelData.user) Prefs.set("userSwitchStyle", v); else root.setCtl(cr.modelData.id, v); }
                }
                SCheckBox {
                    parent: cr
                    x: SStyle.pad
                    anchors.verticalCenter: parent.verticalCenter
                    checked: cr.state_ !== "hide"
                    onToggled: (on) => root.setCtl(cr.modelData.id, on ? (cr.modelData.popup ? "active" : "show") : "hide")
                }
            }
        }
    }
    Item {
        width: parent.width
        height: 28
        HelpButton { anchors.right: parent.right; y: 4 }
    }
}
