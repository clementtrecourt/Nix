import QtQuick
import qs.common

// Trackpad (Tahoe 26, Apple mchlp1226) : onglets Point & Click / Scroll &
// Zoom / More Gestures ; vitesse (input:sensitivity), clic secondaire
// (input:touchpad:clickfinger_behavior), toucher pour cliquer
// (input:touchpad:tap-to-click), défilement naturel et vitesse
// (input:touchpad:natural_scroll / scroll_factor).
PaneBase {
    id: root

    property string tab: "point"

    Item {
        width: parent.width
        height: 26
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 330; height: 24; radius: 12
            color: SStyle.controlFill
            Row {
                anchors.fill: parent
                Repeater {
                    model: [["point", "Point & Click"], ["scroll", "Scroll & Zoom"], ["gestures", "More Gestures"]]
                    Item {
                        required property var modelData
                        width: 110; height: 24
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 2
                            radius: height / 2
                            visible: root.tab === modelData[0]
                            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.22) : "#FFFFFF"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: modelData[1]
                            font.family: Theme.font; font.pixelSize: SStyle.body
                            font.weight: root.tab === modelData[0] ? Font.DemiBold : Font.Normal
                            color: SStyle.label
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.tab = modelData[0] }
                    }
                }
            }
        }
    }
    SGroup {
        visible: root.tab === "point"
        SRow {
            title: "Tracking speed"
            minHeight: 54
            SSlider {
                width: 230; ticks: 10; minLabel: "Slow"; maxLabel: "Fast"
                value: (Number(Prefs.hypr("input:sensitivity", 0)) + 1) / 2
                onReleased: (v) => Prefs.setHypr("input:sensitivity", Math.round((v * 2 - 1) * 100) / 100)
            }
        }
        SRow { title: "Click"; dimmed: true; SPopUp { options: ["Light", "Medium", "Firm"]; value: "Medium"; enabledPopUp: false } }
        SRow { title: "Force Click and haptic feedback"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
        SRow {
            title: "Secondary click"
            SPopUp {
                options: [{ text: "Click with Two Fingers", value: 1 }, { text: "Click in Bottom Right Corner", value: 0 }]
                value: Number(Prefs.hypr("input:touchpad:clickfinger_behavior", 1))
                onActivated: (v) => Prefs.setHypr("input:touchpad:clickfinger_behavior", v)
            }
        }
        SRow {
            title: "Tap to click"
            subtitle: "Tap with one finger"
            SSwitch { checked: !!Number(Prefs.hypr("input:touchpad:tap-to-click", 1)); onToggled: (on) => Prefs.setHypr("input:touchpad:tap-to-click", on) }
        }
    }
    SGroup {
        visible: root.tab === "scroll"
        SRow {
            title: "Natural scrolling"
            subtitle: "Content tracks finger movement"
            SSwitch { checked: !!Number(Prefs.hypr("input:touchpad:natural_scroll", 0)); onToggled: (on) => Prefs.setHypr("input:touchpad:natural_scroll", on) }
        }
        SRow {
            title: "Scrolling speed"
            minHeight: 54
            SSlider {
                width: 230; ticks: 8; minLabel: "Slow"; maxLabel: "Fast"
                value: Math.max(0, Math.min(1, (Number(Prefs.hypr("input:touchpad:scroll_factor", 1)) - 0.25) / 2.75))
                onReleased: (v) => Prefs.setHypr("input:touchpad:scroll_factor", Math.round((0.25 + v * 2.75) * 100) / 100)
            }
        }
        SRow { title: "Zoom in or out"; subtitle: "Pinch with two fingers"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
        SRow { title: "Smart zoom"; subtitle: "Double-tap with two fingers"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
        SRow { title: "Rotate"; subtitle: "Rotate with two fingers"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
    }
    SGroup {
        visible: root.tab === "gestures"
        SRow { title: "Swipe between full-screen applications"; subtitle: "Swipe left or right with three fingers"; detail: "Managed by Hyprland gestures" }
        SRow { title: "Mission Control"; subtitle: "Swipe up with three fingers"; detail: "Managed by Hyprland gestures" }
        SRow { title: "App Exposé"; dimmed: true; SPopUp { options: ["Off"]; value: "Off"; enabledPopUp: false } }
        SRow { title: "Launchpad"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
    }
    Item {
        width: parent.width
        height: 28
        HelpButton { anchors.right: parent.right; y: 4; url: "https://support.apple.com/guide/mac-help/mchlp1226/mac" }
    }
}
