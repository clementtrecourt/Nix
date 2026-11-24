pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io

// Son : sortie par défaut Pipewire (volume, sourdine) et liste des sorties.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: !!sink && !!sink.audio
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false

    // Sorties matérielles (pas les flux applicatifs)
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    // Portable (batterie présente) : la sortie analogique est le haut-parleur
    // interne ; sur un ordinateur de bureau c'est la prise jack.
    property bool laptop: false
    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/power_supply 2>/dev/null | grep -q '^BAT'"]
        onExited: code => root.laptop = code === 0
    }

    // Nom affiché façon macOS : sortie analogique "Internal Speakers" sur un
    // portable, "External Headphones" (prise jack, comme un Mac mini / Mac
    // Studio) sur un ordinateur de bureau ; nom de l'écran pour une sortie
    // HDMI/DisplayPort (ex. "C27JG5x"), nom de l'appareil Bluetooth / USB.
    // Les descriptions ALSA brutes ("Starship/Matisse HD Audio Controller Analog
    // Stereo") ne sont jamais montrées telles quelles.
    function nameOf(n) {
        if (!n) return "";
        const name = n.name ?? "";
        const desc = n.description || "";
        const nick = n.nickname || "";
        if (name.startsWith("bluez_")) return desc || nick || name;
        if (/hdmi|displayport|\.dp-/i.test(name)) {
            // nick = nom du moniteur (EDID) quand il est connu
            return nick && !/hdmi|displayport|analog/i.test(nick) ? nick : "HDMI";
        }
        if (name.includes(".usb-") || /usb/i.test(desc)) return desc.replace(/ (Analog|Digital) Stereo.*$/, "") || nick;
        if (/analog/i.test(name)) return root.laptop ? "Internal Speakers" : "External Headphones";
        return desc || nick || name;
    }
    readonly property string sinkName: nameOf(sink)

    // Icône SF selon le type de sortie
    function iconOf(n) {
        const s = ((n?.description ?? "") + " " + (n?.name ?? "")).toLowerCase();
        if (s.includes("airpods")) return "headphones";
        if (s.includes("headphone") || s.includes("casque") || s.includes("headset") || s.includes("bluez")) return "headphones";
        if (s.includes("hdmi") || s.includes("displayport")) return "display";
        if (s.includes("usb")) return "hifispeaker.fill";
        if (/analog/.test(s) && !root.laptop) return "headphones";
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
