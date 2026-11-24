import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.common

// Sound (Tahoe 26, Apple mchl9777ee30) : Sound Effects (son d'alerte joué à
// la sélection, sortie des effets, volume d'alerte, sons de l'interface,
// retour au changement de volume), Output & Input (onglets segmentés, liste
// des appareils Pipewire, volume, sourdine, balance ; niveau d'entrée en
// direct) — via Quickshell.Services.Pipewire.
PaneBase {
    id: root

    property string tab: "output"
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio && !(n.name ?? "").endsWith(".monitor"))
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property PwNode node: tab === "output" ? sink : source
    readonly property var list: tab === "output" ? sinks : sources

    PwObjectTracker { objects: root.sinks.concat(root.sources).filter(o => !!o) }
    PwNodePeakMonitor { id: peak; node: root.source; enabled: root.tab === "input" && !!root.source }

    function label(n) { return n ? (n.description || n.nickname || n.name) : ""; }
    function kind(n) {
        const p = n?.properties ?? {};
        const bus = p["device.bus"] ?? "", ff = p["device.form-factor"] ?? "", api = p["device.api"] ?? "";
        if (bus === "bluetooth" || api === "bluez5") return "Bluetooth";
        if (bus === "usb") return "USB";
        if ((n.name ?? "").includes("hdmi") || (label(n)).match(/HDMI|DisplayPort/i)) return "HDMI";
        if (ff === "headphone" || ff === "headset") return "Headphones";
        return n.isSink ? "Built-in" : "Built-in";
    }
    // Balance : différence gauche / droite sur les deux premiers canaux
    readonly property real balance: {
        const v = sink?.audio?.volumes ?? [];
        if (v.length < 2) return 0.5;
        const m = Math.max(v[0], v[1], 0.0001);
        return 0.5 + (v[1] - v[0]) / (2 * m);
    }
    function setBalance(b) {
        if (!sink?.audio) return;
        const v = sink.audio.volumes.slice();
        if (v.length < 2) return;
        const m = Math.max(v[0], v[1]);
        v[0] = m * Math.min(1, 2 * (1 - b));
        v[1] = m * Math.min(1, 2 * b);
        sink.audio.volumes = v;
    }

    SSection { text: "Sound Effects" }
    SGroup {
        SRow {
            title: "Alert sound"
            SPopUp {
                options: Prefs.alertSounds.slice(0, 14).concat([{ separator: true }]).concat(Prefs.alertSounds.slice(14))
                value: Prefs.v.alertSound
                onActivated: (v) => { Prefs.set("alertSound", v); Prefs.playAlert(v); }
            }
        }
        SRow {
            title: "Play sound effects through"
            SPopUp {
                options: [{ text: "Selected Sound Output Device", value: "" }, { separator: true }].concat(root.sinks.map(n => ({ text: root.label(n), value: n.name })))
                value: Prefs.v.effectsDevice ?? ""
                onActivated: (v) => Prefs.set("effectsDevice", v)
            }
        }
        SRow {
            title: "Alert volume"
            SSlider {
                width: 210
                minSymbol: "speaker.fill"; maxSymbol: "speaker.wave.3.fill"
                value: Prefs.v.alertVolume
                onReleased: (v) => { Prefs.set("alertVolume", v); Prefs.playAlert(); }
            }
        }
        SRow { title: "Play sound on startup"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
        SRow { title: "Play user interface sound effects"; SSwitch { checked: Prefs.v.uiSounds; onToggled: (on) => Prefs.set("uiSounds", on) } }
        SRow { title: "Play feedback when volume is changed"; SSwitch { checked: Prefs.v.volumeFeedback; onToggled: (on) => Prefs.set("volumeFeedback", on) } }
    }

    SSection { text: "Output & Input" }
    // Onglets segmentés Output | Input
    Item {
        width: parent.width
        height: 26
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 190
            height: 24
            radius: 12
            color: SStyle.controlFill
            Rectangle {
                x: root.tab === "output" ? 2 : parent.width / 2
                y: 2
                width: parent.width / 2 - 2
                height: parent.height - 4
                radius: height / 2
                color: Theme.dark ? Qt.rgba(1, 1, 1, 0.22) : "#FFFFFF"
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
            Row {
                anchors.fill: parent
                Repeater {
                    model: [["output", "Output"], ["input", "Input"]]
                    Item {
                        required property var modelData
                        width: 95; height: 24
                        Text {
                            anchors.centerIn: parent
                            text: modelData[1]
                            font.family: Theme.font
                            font.pixelSize: SStyle.body
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
        // En-tête du tableau Name | Type
        Item {
            width: parent.width
            height: 28
            Text { x: SStyle.pad; anchors.verticalCenter: parent.verticalCenter; text: "Name"; font.family: Theme.font; font.pixelSize: SStyle.small; font.weight: Font.DemiBold; color: SStyle.secondary }
            Text { x: parent.width * 0.68; anchors.verticalCenter: parent.verticalCenter; text: "Type"; font.family: Theme.font; font.pixelSize: SStyle.small; font.weight: Font.DemiBold; color: SStyle.secondary }
        }
        Repeater {
            model: root.list
            Item {
                id: dev
                required property var modelData
                readonly property bool sel: root.node === modelData
                width: parent.width
                height: 28
                Rectangle {
                    x: 6; width: parent.width - 12; height: parent.height
                    radius: 6
                    color: dev.sel ? SStyle.accent : "transparent"
                }
                Text {
                    x: SStyle.pad
                    width: parent.width * 0.68 - x - 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.label(dev.modelData)
                    elide: Text.ElideRight
                    font.family: Theme.font; font.pixelSize: SStyle.body
                    color: dev.sel ? "#FFFFFF" : SStyle.label
                }
                Text {
                    x: parent.width * 0.68
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.kind(dev.modelData)
                    font.family: Theme.font; font.pixelSize: SStyle.body
                    color: dev.sel ? Qt.rgba(1, 1, 1, 0.85) : SStyle.secondary
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.tab === "output") Pipewire.preferredDefaultAudioSink = dev.modelData;
                        else Pipewire.preferredDefaultAudioSource = dev.modelData;
                    }
                }
            }
        }
        Item { width: 1; height: 6 }
    }
    SGroup {
        SRow {
            title: root.tab === "output" ? "Output volume" : "Input volume"
            Row {
                spacing: 12
                SSlider {
                    width: 210
                    anchors.verticalCenter: parent.verticalCenter
                    minSymbol: root.tab === "output" ? "speaker.fill" : ""
                    maxSymbol: root.tab === "output" ? "speaker.wave.3.fill" : ""
                    value: root.node?.audio ? Math.min(1, root.node.audio.volume) : 0
                    enabledSlider: !!root.node?.audio
                    onMoved: (v) => { root.node.audio.muted = false; root.node.audio.volume = v; }
                    onReleased: if (root.tab === "output" && Prefs.v.volumeFeedback) Prefs.playAlert()
                }
                SCheckBox {
                    visible: root.tab === "output"
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Mute"
                    checked: root.sink?.audio?.muted ?? false
                    onToggled: (on) => { if (root.sink?.audio) root.sink.audio.muted = on; }
                }
            }
        }
        SRow {
            visible: root.tab === "output"
            title: "Balance"
            minHeight: 50
            SSlider {
                width: 210
                ticks: 0
                minLabel: "Left"; maxLabel: "Right"
                value: root.balance
                enabledSlider: (root.sink?.audio?.volumes?.length ?? 0) >= 2
                onMoved: (v) => root.setBalance(Math.abs(v - 0.5) < 0.04 ? 0.5 : v)
            }
        }
        SRow {
            visible: root.tab === "input"
            title: "Input level"
            Row {
                spacing: 3
                Repeater {
                    model: 15
                    Rectangle {
                        required property int index
                        width: 10; height: 10; radius: 5
                        readonly property bool lit: peak.peak * 15 * 1.6 > index
                        color: lit ? (index > 12 ? SStyle.red : index > 9 ? SStyle.orange : SStyle.green) : SStyle.sliderTrack
                    }
                }
            }
        }
    }
    Item {
        width: parent.width
        height: 28
        HelpButton { anchors.right: parent.right; y: 4; url: "https://support.apple.com/guide/mac-help/mchl9777ee30/mac" }
    }
}
