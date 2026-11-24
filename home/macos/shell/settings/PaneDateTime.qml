import QtQuick
import Quickshell
import qs.common

// General > Date & Time (Tahoe 26) : réglage automatique (NTP de
// systemd-timesyncd via timedatectl), source, date et heure, fuseau horaire,
// format 24 heures.
PaneBase {
    id: root

    property bool ntp: true
    property string server: ""
    property string zone: ""
    property date now: new Date()

    function refresh() { probe.running = true; }
    Component.onCompleted: refresh()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    ProcessText {
        id: probe
        command: ["sh", "-c", 'timedatectl show -p NTP -p Timezone 2>/dev/null; printf "Server=%s\\n" "$(timedatectl show-timesync -p ServerName --value 2>/dev/null)"']
        onDone: (t) => {
            for (const l of t.split("\n")) {
                const [k, v] = [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)];
                if (k === "NTP") root.ntp = v === "yes";
                else if (k === "Timezone") root.zone = v;
                else if (k === "Server") root.server = v;
            }
        }
    }
    ProcessText { id: setter; onExited: root.refresh() }

    readonly property string dateText: Qt.formatDateTime(now, "M/d/yyyy, ") + Qt.formatDateTime(now, Prefs.v.clock24 ? "HH:mm" : "h:mm AP")

    SGroup {
        SRow {
            title: "Set time and date automatically"
            SSwitch {
                checked: root.ntp
                onToggled: (on) => { setter.command = ["timedatectl", "set-ntp", on ? "true" : "false"]; setter.running = true; }
            }
        }
        SRow {
            dimmed: !root.ntp
            title: "Source"
            detail: root.server || "NixOS (systemd-timesyncd)"
        }
        SRow {
            title: "Date and time"
            detail: root.dateText
            SButton { text: "Set…"; enabledButton: false }
        }
    }
    SGroup {
        SRow {
            title: "Set time zone automatically using your current location"
            SSwitch { checked: false; enabledSwitch: false }
        }
        SRow {
            title: "Closest city"
            detail: root.zone ? root.zone.split("/").pop().replace(/_/g, " ") : "—"
        }
        SRow {
            title: "Time zone"
            detail: root.zone ? Qt.formatDateTime(root.now, "t") + " (" + root.zone + ")" : "—"
        }
    }
    SGroup {
        SRow {
            title: "24-hour time"
            SSwitch { checked: !!Prefs.v.clock24; onToggled: (on) => Prefs.set("clock24", on) }
        }
        SRow {
            title: "Show 24-hour time on Lock Screen"
            dimmed: !Prefs.v.clock24
            SSwitch { checked: !!Prefs.v.clock24Lock; enabledSwitch: !!Prefs.v.clock24; onToggled: (on) => Prefs.set("clock24Lock", on) }
        }
    }
    SNote { text: "The time zone and automatic time are system settings: changes may ask for an administrator password." }
}
