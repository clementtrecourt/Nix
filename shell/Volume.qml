import Quickshell.Services.Pipewire
import QtQuick

Text {
    readonly property var sink: Pipewire.defaultAudioSink

    PwObjectTracker { objects: [sink] }

    text: sink && sink.audio
        ? (sink.audio.muted ? "mute" : Math.round(sink.audio.volume * 100))
        : "--"
    color: Colors.textMuted
    font { family: Config.font; pixelSize: 12 }
}
