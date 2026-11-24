import QtQuick
import qs.common

// Mouse (Tahoe 26) : vitesse du pointeur (input:sensitivity), défilement
// naturel (input:natural_scroll), vitesse de défilement (input:scroll_factor),
// accélération (Advanced… : input:accel_profile). Appliqué à chaud et persisté.
PaneBase {
    id: root

    SGroup {
        SRow {
            title: "Tracking speed"
            minHeight: 54
            SSlider {
                width: 230
                ticks: 10
                minLabel: "Slow"; maxLabel: "Fast"
                value: (Number(Prefs.hypr("input:sensitivity", 0)) + 1) / 2
                onReleased: (v) => Prefs.setHypr("input:sensitivity", Math.round((v * 2 - 1) * 100) / 100)
            }
        }
        SRow {
            title: "Natural scrolling"
            subtitle: "Content tracks finger movement"
            SSwitch { checked: !!Number(Prefs.hypr("input:natural_scroll", 0)); onToggled: (on) => Prefs.setHypr("input:natural_scroll", on) }
        }
        SRow {
            title: "Secondary click"
            dimmed: true
            SPopUp { options: [{ text: "Click Right Side", value: "right" }, { text: "Click Left Side", value: "left" }]; value: "right"; enabledPopUp: false }
        }
        SRow {
            title: "Scrolling speed"
            minHeight: 54
            SSlider {
                width: 230
                ticks: 8
                minLabel: "Slow"; maxLabel: "Fast"
                value: Math.max(0, Math.min(1, (Number(Prefs.hypr("input:scroll_factor", 1)) - 0.25) / 2.75))
                onReleased: (v) => Prefs.setHypr("input:scroll_factor", Math.round((0.25 + v * 2.75) * 100) / 100)
            }
        }
    }
    Item {
        width: parent.width
        height: 28
        Row {
            anchors.right: parent.right
            y: 4
            spacing: 10
            SButton { text: "Advanced…"; onClicked: adv.shown = true }
            HelpButton {}
        }
    }
    SSheet {
        id: adv
        sheetWidth: 440
        body: Component {
            Column {
                width: parent ? parent.width : 0
                spacing: SStyle.groupSpacing
                SGroup {
                    SRow {
                        title: "Pointer acceleration"
                        subtitle: "Pointer movement speeds up when you move the mouse faster."
                        SSwitch {
                            checked: String(Prefs.hypr("input:accel_profile", "")) !== "flat"
                            onToggled: (on) => Prefs.setHypr("input:accel_profile", on ? "adaptive" : "flat")
                        }
                    }
                }
            }
        }
    }
}
