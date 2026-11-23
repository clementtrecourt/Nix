pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Son : sortie par défaut Pipewire (volume, sourdine) et liste des sorties.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: !!sink && !!sink.audio
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false

    // Sorties matérielles (pas les flux applicatifs)
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    function nameOf(n) {
        if (!n) return "";
        return n.description || n.nickname || n.name;
    }
    readonly property string sinkName: nameOf(sink)

    // Icône SF selon le type de sortie
    function iconOf(n) {
        const s = ((n?.description ?? "") + " " + (n?.name ?? "")).toLowerCase();
        if (s.includes("airpods")) return "headphones";
        if (s.includes("headphone") || s.includes("casque") || s.includes("headset") || s.includes("bluez")) return "headphones";
        if (s.includes("hdmi") || s.includes("displayport")) return "display";
        if (s.includes("usb")) return "hifispeaker.fill";
        return "laptopcomputer";
    }

    function setVolume(v) {
        if (!ready) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMute() { if (ready) sink.audio.muted = !sink.audio.muted; }
    function setDefault(n) { Pipewire.preferredDefaultAudioSink = n; }

    PwObjectTracker { objects: [root.sink, ...root.outputs].filter(o => !!o) }
}
