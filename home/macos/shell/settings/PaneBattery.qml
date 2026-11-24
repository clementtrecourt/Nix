import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.common

// Battery (portables) / Energy (ordinateurs de bureau) de Tahoe 26 : mode
// d'énergie (power-profiles-daemon : Automatic = balanced, Low Power =
// power-saver, High Power = performance), niveau et état de la batterie
// (UPower), options de veille affichées comme Tahoe.
PaneBase {
    id: root

    property string profile: ""
    property bool ppd: false
    function refresh() { probe.running = true; }
    Component.onCompleted: refresh()
    ProcessText {
        id: probe
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null"]
        onDone: (t) => { root.profile = t.trim(); root.ppd = root.profile !== ""; }
    }
    ProcessText { id: setter; onExited: root.refresh() }
    readonly property var dev: UPower.displayDevice

    SHeaderCard {
        visible: Nav.hasBattery
        pane: root.spec
        title: "Battery Level " + Math.round((root.dev?.percentage ?? 0) * 100) + "%"
        description: root.dev?.state === UPowerDeviceState.Charging ? "Charging" : root.dev?.state === UPowerDeviceState.FullyCharged ? "Fully Charged" : "On Battery"
    }
    SGroup {
        SRow {
            title: Nav.hasBattery ? "Low Power Mode" : "Energy Mode"
            subtitle: root.ppd ? "" : "Requires power-profiles-daemon."
            SPopUp {
                enabledPopUp: root.ppd
                options: Nav.hasBattery ? [{ text: "Never", value: "balanced" }, { text: "Always", value: "power-saver" }]
                                        : [{ text: "Automatic", value: "balanced" }, { text: "Low Power", value: "power-saver" }, { text: "High Power", value: "performance" }]
                value: root.profile
                onActivated: (v) => { setter.command = ["powerprofilesctl", "set", v]; setter.running = true; }
            }
        }
        SRow { visible: Nav.hasBattery; title: "Battery Health"; detail: (root.dev?.healthPercentage ?? 0) > 0 ? (root.dev.healthPercentage >= 80 ? "Normal" : "Service Recommended") : "Normal" }
    }
    SGroup {
        SRow { title: "Prevent automatic sleeping when the display is off"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
        SRow { title: "Wake for network access"; dimmed: true; SPopUp { options: ["Always", "Only on Power Adapter", "Never"]; value: "Never"; enabledPopUp: false } }
        SRow { title: "Start up automatically after a power failure"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
    }
    Item {
        width: parent.width
        height: 28
        Row {
            anchors.right: parent.right
            y: 4
            spacing: 10
            SButton { text: "Lock Screen Settings…"; onClicked: Nav.go("lockscreen") }
            HelpButton {}
        }
    }
}
