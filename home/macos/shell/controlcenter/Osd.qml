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
// Touches de luminosité (un cran de 1/16, écrit puis affiche le HUD) :
//   quickshell -c macos ipc call osd brightnessUp|brightnessDown
//   quickshell -c macos ipc call osd keyboardUp|keyboardDown
Scope {
    id: osd

    // "volume" | "brightness" | "keyboard"
    property string kind: "volume"
    property bool shown: false
    property var targetScreen: Quickshell.screens[0]
    // Ignore les variations de volume du démarrage / changement de sortie
    property bool armed: false

    readonly property string title: kind === "volume" ? (Audio.sinkName || "Sound")
        : kind === "keyboard" ? "Keyboard Brightness" : displayName
    // Comme le module "Display" du Control Center ; un seul écran externe
    // piloté en DDC/CI : son modèle (EDID). Plusieurs écrans pilotés ensemble :
    // "Display".
    readonly property string displayName: Brightness.backend === "ddc" && Brightness.ddcDisplays.length === 1
        && Brightness.ddcDisplays[0].model !== "" ? Brightness.ddcDisplays[0].model : "Display"
    readonly property real value: kind === "volume" ? (Audio.muted ? 0 : Audio.volume)
        : kind === "keyboard" ? Brightness.kbdValue : Brightness.value

    // Publie l'état du HUD pour la barre des menus (surbrillance de l'élément Son)
    Binding { target: ShellState; property: "osdKind"; value: osd.shown ? osd.kind : "" }

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
        // Touches de luminosité : un cran, puis HUD (rien si aucun moyen de
        // régler la luminosité n'est disponible)
        function brightnessUp(): void { if (Brightness.stepBy(1)) osd.show("brightness"); }
        function brightnessDown(): void { if (Brightness.stepBy(-1)) osd.show("brightness"); }
        function keyboardUp(): void { if (Brightness.stepKeyboard(1)) osd.show("keyboard"); }
        function keyboardDown(): void { if (Brightness.stepKeyboard(-1)) osd.show("keyboard"); }
        // Débogage : maintien affiché (ms, 0 = durée normale)
        function hold(ms: int): void { hideTimer.interval = ms > 0 ? ms : 1600; }
        // Débogage : affiche le HUD sans relire la valeur (machine sans rétroéclairage)
        function preview(k: string): void { osd.show(k); }
    }

    PanelWindow {
        id: win

        readonly property int pad: 24
        // Marge minimale entre le HUD et le bord droit de l'écran
        readonly property int edge: 8
        screen: osd.targetScreen
        // Liquid Glass : le HUD réfracte une capture de l'écran prise juste avant
        // son apparition. Un nouvel appel pendant qu'il est visible (touches de
        // volume répétées, animation de fermeture) garde la capture courante.
        property Item glassBackdrop: hudBackdrop
        GlassBackdrop {
            id: hudBackdrop
            mode: "snapshot"
            screen: win.screen
            want: osd.shown || hud.opacity > 0.001
        }
        visible: hudBackdrop.pass
        color: "transparent"
        // Surface transparente collée au bord droit (sans marge : le HUD se
        // place dedans, ce qui permet de le rapprocher du bord sans marge négative)
        anchors { top: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        margins.top: Theme.menuBarHeight
        implicitWidth: Math.min(screen?.width ?? 1512, CCStyle.width + 2 * pad + 320)
        implicitHeight: CCStyle.cell + 2 * pad

        // Centre visé (repère de l'écran) : élément Son/Écran de la barre s'il est
        // publié, sinon icône du Control Center, sinon position par défaut.
        readonly property real anchorX: {
            const sw = screen?.width ?? 1512;
            if (ShellState.osdAnchorX > 0) return ShellState.osdAnchorX;
            if (ShellState.controlCenterIconX > 0) return ShellState.controlCenterIconX;
            return sw - 165;
        }
        // "macos-lg-*" : pas de flou Hyprland (le verre floute lui-même)
        WlrLayershell.namespace: "macos-lg-osd"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // Les clics traversent le HUD
        mask: Region {}

        SliderModule {
            id: hud
            // x dans la surface : centré sous anchorX, sans déborder de l'écran
            x: {
                const left = (win.screen?.width ?? 1512) - win.width;
                return Math.round(Math.max(win.pad, Math.min(win.width - win.edge - width, win.anchorX - left - width / 2)));
            }
            y: CCStyle.marginTop
            width: CCStyle.width
            height: CCStyle.cell
            hud: true
            radius: CCStyle.radiusHud
            tint: CCStyle.hudTint
            glassSaturation: CCStyle.hudSaturation
            // Cotes du HUD Tahoe (capture à 2 px/pt, HUD de 290 pt), mesurées sur
            // le dessin visible : haut-parleur gauche centré à 18,3 pt, piste de
            // 29,8 pt à 38,5 pt du bord droit, haut-parleur droit (ondes comprises)
            // centré à 23 pt du bord droit, piste à ~41,5 pt du haut (42 : pixels
            // entiers). Valeurs nominales ci-dessous = centre de la boîte du
            // pictogramme (le dessin du haut-parleur est décalé dans sa boîte).
            leftCenterX: 19.5
            trackLeft: 30
            trackRightInset: 38.5
            rightInset: 23.5
            title: osd.title
            value: osd.value
            leftSymbol: osd.kind === "volume" ? (Audio.muted ? "speaker.slash.fill" : "speaker.fill")
                : osd.kind === "keyboard" ? "light.min" : "sun.min.fill"
            // Même taille de pictos que les modules Son / Écran
            leftSize: osd.kind === "volume" ? 19 : osd.kind === "keyboard" ? 18 : 17
            rightSymbol: osd.kind === "volume" ? "speaker.wave.3.fill"
                : osd.kind === "keyboard" ? "light.max" : "sun.max.fill"
            rightSize: osd.kind === "volume" ? 20 : osd.kind === "keyboard" ? 20 : 17

            transformOrigin: Item.Top
            opacity: 0
            scale: 0.86
            transform: Translate { id: drop; y: -10 }

            // L'apparition attend la capture (pass) : animation jamais tronquée
            states: State {
                name: "shown"
                when: osd.shown && hudBackdrop.pass
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
