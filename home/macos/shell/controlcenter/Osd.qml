import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.common
import qs.services

// HUD volume / luminosité / rétroéclairage clavier de macOS Tahoe : ce n'est
// plus le grand carré central, mais un petit module Liquid Glass (même dessin
// que le module "Son" du Control Center, avec 16 crans en pointillés) qui
// tombe sous la barre des menus, centré sous l'icône du Control Center.
// Titre = nom de la sortie audio ("Haut-parleurs MacBook Air") / de l'écran.
// Non interactif (les clics le traversent), disparaît après ~1,5 s.
//
// Déclenchement : changement du volume Pipewire par défaut, ou IPC
//   quickshell -c macos ipc call osd volume|brightness|keyboard
Scope {
    id: osd

    // "volume" | "brightness" | "keyboard"
    property string kind: "volume"
    property bool shown: false
    property var targetScreen: Quickshell.screens[0]
    // Ignore les variations de volume du démarrage / changement de sortie
    property bool armed: false

    readonly property string title: kind === "volume" ? (Audio.sinkName || "Son")
        : kind === "keyboard" ? "Luminosité du clavier" : displayName
    readonly property string displayName: {
        const m = Hyprland.focusedMonitor;
        if (!m || (m.name ?? "").startsWith("eDP")) return "Écran intégré";
        return m.lastIpcObject?.model || m.description || m.name;
    }
    readonly property real value: kind === "volume" ? (Audio.muted ? 0 : Audio.volume)
        : kind === "keyboard" ? Brightness.kbdValue : Brightness.value

    function show(k) {
        // Le Control Center ouvert affiche déjà le curseur : pas de HUD.
        if (ShellState.openPanel === "controlcenter") return;
        if (!shown) {
            const name = Hyprland.focusedMonitor?.name ?? "";
            targetScreen = Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
        }
        kind = k;
        shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 1600
        onTriggered: osd.shown = false
    }
    Timer {
        id: armTimer
        interval: 1500
        running: true
        onTriggered: osd.armed = true
    }

    // Volume Pipewire : chaque changement (touches, wpctl, autre appli) affiche le HUD
    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumesChanged() { if (osd.armed) osd.show("volume"); }
        function onMutedChanged() { if (osd.armed) osd.show("volume"); }
    }
    Connections {
        target: Audio
        function onSinkChanged() { osd.armed = false; armTimer.restart(); }
    }

    // Luminosité : relue après brightnessctl, puis affichée
    property string pending: ""
    Connections {
        target: Brightness
        function onScreenRefreshed() { if (osd.pending === "brightness" && Brightness.available) osd.show("brightness"); osd.pending = ""; }
        function onKeyboardRefreshed() { if (osd.pending === "keyboard" && Brightness.kbdAvailable) osd.show("keyboard"); osd.pending = ""; }
    }

    IpcHandler {
        target: "osd"
        function volume(): void { osd.show("volume"); }
        function brightness(): void { osd.pending = "brightness"; Brightness.refresh(); }
        function keyboard(): void { osd.pending = "keyboard"; Brightness.refresh(); }
        // Débogage : maintien affiché (ms, 0 = durée normale)
        function hold(ms: int): void { hideTimer.interval = ms > 0 ? ms : 1600; }
        // Débogage : affiche le HUD sans relire la valeur (machine sans rétroéclairage)
        function preview(k: string): void { osd.show(k); }
    }

    PanelWindow {
        id: win

        readonly property int pad: 24
        screen: osd.targetScreen
        visible: osd.shown || hud.opacity > 0.001
        color: "transparent"
        anchors { top: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        margins.top: Theme.menuBarHeight
        // Centré sous l'icône du Control Center (position fournie par la barre)
        margins.right: {
            const sw = screen?.width ?? 1512;
            const cx = ShellState.controlCenterIconX > 0 ? ShellState.controlCenterIconX : sw - 172;
            return Math.max(0, Math.round(sw - cx - implicitWidth / 2));
        }
        implicitWidth: CCStyle.width + 2 * pad
        implicitHeight: CCStyle.cell + 2 * pad
        WlrLayershell.namespace: "macos-osd"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // Les clics traversent le HUD
        mask: Region {}

        SliderModule {
            id: hud
            x: win.pad
            y: CCStyle.marginTop
            width: CCStyle.width
            height: CCStyle.cell
            hud: true
            title: osd.title
            value: osd.value
            leftSymbol: osd.kind === "volume" ? (Audio.muted ? "speaker.slash.fill" : "speaker.fill")
                : osd.kind === "keyboard" ? "light.min" : "sun.min.fill"
            leftSize: osd.kind === "volume" ? 21 : 19
            rightSymbol: osd.kind === "volume" ? "speaker.wave.3.fill"
                : osd.kind === "keyboard" ? "light.max" : "sun.max.fill"
            rightSize: osd.kind === "volume" ? 26 : 20

            transformOrigin: Item.Top
            opacity: 0
            scale: 0.86
            transform: Translate { id: drop; y: -10 }

            states: State {
                name: "shown"
                when: osd.shown
                PropertyChanges { hud.opacity: 1; hud.scale: 1; drop.y: 0 }
            }
            transitions: [
                Transition {
                    to: "shown"
                    ParallelAnimation {
                        NumberAnimation { target: hud; property: "opacity"; duration: 160; easing.type: Easing.OutCubic }
                        NumberAnimation { target: hud; property: "scale"; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                        NumberAnimation { target: drop; property: "y"; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }
                },
                Transition {
                    from: "shown"
                    ParallelAnimation {
                        NumberAnimation { target: hud; property: "opacity"; duration: 260; easing.type: Easing.InCubic }
                        NumberAnimation { target: hud; property: "scale"; to: 0.94; duration: 260; easing.type: Easing.InCubic }
                        NumberAnimation { target: drop; property: "y"; to: -6; duration: 260; easing.type: Easing.InCubic }
                    }
                }
            ]
        }
    }
}
