import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import qs.common
import qs.services

// Control Center de macOS Tahoe : modules Liquid Glass flottants (pas de fond
// commun), ancrés en haut à droite sous la barre des menus. Disposition par
// défaut de macOS 26 (grille de 4 colonnes) :
//
//   [ Wi-Fi      ] [ Lecture   ]
//   [ Bluetooth  ] [ en cours  ]
//   [ AirDrop    ] (SM) (Recop.)
//   (Sombre)(Calc) [ Concentr. ]
//   [ Écran ---------------- ☼ ]
//   [ Son ------------- 🔊 (⌾) ]
//
// Un clic sur un module (hors pastille) le déplie : la plaque du module se
// transforme (ressort) en carte pleine largeur avec la liste détaillée, les
// autres modules s'effacent. Échap / clic à côté replient puis ferment.
//
// Ouverture : icône de la barre (ShellState "controlcenter") ou raccourci
// global macos:controlcenter.
Scope {
    id: cc

    readonly property bool open: ShellState.openPanel === "controlcenter"
    // Suit `open`, mais seulement après avoir choisi l'écran (évite de recréer
    // la surface sur un autre écran pendant qu'elle est visible).
    property bool shown: false
    property var targetScreen: Quickshell.screens[0]
    // Module déplié : "", "wifi", "bluetooth", "sound", "focus"
    property string expanded: ""
    // Progression du dépliage (0 = grille, 1 = carte), peut dépasser 1 (ressort)
    property real ex: 0
    property rect fromRect: Qt.rect(0, 0, 0, 0)
    property real fromRadius: 0

    // Le singleton Appearance applique l'apparence persistée dès le démarrage.
    readonly property bool _dark: Appearance.dark

    // ---- État des services ----
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) ?? null : null
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var btAdapter: Bt.adapter
    readonly property bool btOn: !!btAdapter && btAdapter.enabled
    readonly property var btConnected: btAdapter ? btAdapter.devices.values.filter(d => d.connected) : []

    function expand(name, tile) {
        if (expanded !== "" || !tile) return;
        const p = tile.mapToItem(grid, 0, 0);
        fromRect = Qt.rect(p.x, p.y, tile.width, tile.height);
        fromRadius = tile.radius;
        expanded = name;
        collapseAnim.stop();
        expandAnim.restart();
    }
    function collapse() {
        if (expanded === "") return;
        expandAnim.stop();
        collapseAnim.restart();
    }
    function close() { ShellState.close(); }

    onOpenChanged: {
        if (open) {
            const name = ShellState.panelScreen || (Hyprland.focusedMonitor?.name ?? "");
            if (!win.visible)
                targetScreen = Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
            Brightness.refresh();
        } else if (expanded !== "") {
            collapse();
        }
        shown = open;
    }

    NumberAnimation {
        id: expandAnim
        target: cc
        property: "ex"
        to: 1
        duration: CCStyle.durExpand
        easing.type: Easing.OutBack
        easing.overshoot: 0.9
    }
    NumberAnimation {
        id: collapseAnim
        target: cc
        property: "ex"
        to: 0
        duration: CCStyle.durCollapse
        easing.type: Easing.OutCubic
        onFinished: cc.expanded = ""
    }

    GlobalShortcut {
        appid: "macos"
        name: "controlcenter"
        description: "Ouvrir le Control Center"
        onPressed: ShellState.toggle("controlcenter")
    }

    // Débogage (banc de test : pas de clic souris possible)
    IpcHandler {
        target: "controlcenter-debug"
        function expand(name: string): void {
            const t = { wifi: wifiTile, bluetooth: btTile, sound: soundTile, focus: focusTile }[name];
            cc.expand(name, t);
        }
        function collapse(): void { cc.collapse(); }
        function dark(on: bool): void { Theme.dark = on; }
        // Simule un rétroéclairage (machine de test sans /sys/class/backlight)
        function fakeBrightness(v: real): void { Brightness.available = true; Brightness.value = v; }
        function state(): string { return JSON.stringify({ open: cc.open, expanded: cc.expanded, ex: cc.ex, opacity: content.opacity, scale: content.scale }); }
    }

    PanelWindow {
        id: win

        screen: cc.targetScreen
        visible: cc.shown || content.opacity > 0.001
        color: "transparent"
        anchors { top: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        margins.top: Theme.menuBarHeight
        implicitWidth: CCStyle.width + CCStyle.marginRight + 48
        implicitHeight: 640
        WlrLayershell.namespace: "macos-controlcenter"
        WlrLayershell.layer: WlrLayer.Overlay
        // Exclusif tant qu'il est ouvert : Échap fonctionne dès l'ouverture au clavier
        WlrLayershell.keyboardFocus: cc.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Clic hors du Control Center : fermeture. Léger délai pour laisser un
        // clic sur l'icône de la barre faire son propre toggle (sinon il rouvrirait).
        HyprlandFocusGrab {
            windows: [win]
            active: cc.open && win.visible
            onCleared: grabClose.restart()
        }
        Timer {
            id: grabClose
            interval: 120
            onTriggered: if (ShellState.openPanel === "controlcenter") ShellState.close()
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: cc.expanded !== "" ? cc.collapse() : cc.close()

            // Clic dans le vide de la surface : replie, sinon ferme
            MouseArea {
                anchors.fill: parent
                onClicked: cc.expanded !== "" ? cc.collapse() : cc.close()
            }
        }

        Item {
            id: content
            x: win.width - CCStyle.marginRight - width
            y: CCStyle.marginTop
            width: CCStyle.width
            height: grid.height
            transformOrigin: Item.TopRight
            opacity: 0
            scale: 0.9

            states: State {
                name: "open"
                when: cc.shown
                PropertyChanges { content.opacity: 1; content.scale: 1 }
            }
            transitions: [
                Transition {
                    to: "open"
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; duration: 170; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; duration: CCStyle.durOpen; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                    }
                },
                Transition {
                    from: "open"
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; duration: CCStyle.durClose; easing.type: Easing.InCubic }
                        NumberAnimation { property: "scale"; to: 0.94; duration: CCStyle.durClose; easing.type: Easing.InCubic }
                    }
                }
            ]

            // ---------------- Grille des modules ----------------
            Item {
                id: grid
                width: CCStyle.width
                height: 6 * CCStyle.cell + 5 * CCStyle.gap
                readonly property int s: CCStyle.cell + CCStyle.gap
                opacity: 1 - Math.min(1, cc.ex * 1.8)
                scale: 1 - 0.05 * Math.min(1, cc.ex)
                visible: opacity > 0.001

                PillModule {
                    id: wifiTile
                    x: 0; y: 0
                    title: "Wi-Fi"
                    subtitle: !cc.wifiDevice ? "Indisponible" : !cc.wifiOn ? "Désactivé" : (cc.wifiNetwork?.name ?? "Non connecté")
                    symbol: "wifi"
                    glyphSize: 22
                    on: cc.wifiOn && !!cc.wifiDevice
                    disabled: !cc.wifiDevice
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    onExpand: cc.expand("wifi", wifiTile)
                }
                PillModule {
                    id: btTile
                    x: 0; y: grid.s
                    title: "Bluetooth"
                    subtitle: !cc.btOn ? "Désactivé" : (cc.btConnected.length === 1 ? cc.btConnected[0].name : "Activé")
                    symbol: "bluetooth"
                    glyphSize: 23
                    on: cc.btOn
                    disabled: !cc.btAdapter
                    onToggled: if (cc.btAdapter) cc.btAdapter.enabled = !cc.btAdapter.enabled
                    onExpand: cc.expand("bluetooth", btTile)
                }
                PillModule {
                    x: 0; y: 2 * grid.s
                    title: "AirDrop"
                    subtitle: "Désactivé"
                    symbol: "airdrop"
                    glyphSize: 23
                    disabled: true
                }

                NowPlaying {
                    x: 2 * grid.s; y: 0
                }
                CircleModule {
                    x: 2 * grid.s; y: 2 * grid.s
                    symbol: "squares.leading.rectangle"
                    glyphSize: 34
                    disabled: true
                }
                CircleModule {
                    x: 3 * grid.s; y: 2 * grid.s
                    symbol: "rectangle.on.rectangle"
                    glyphSize: 35
                    disabled: true
                }

                CircleModule {
                    x: 0; y: 3 * grid.s
                    symbol: "circle.lefthalf.filled.inverse"
                    glyphSize: 30
                    on: Theme.dark
                    onClicked: Appearance.toggle()
                }
                CircleModule {
                    x: grid.s; y: 3 * grid.s
                    symbol: "calculator"
                    glyphSize: 30
                    onClicked: { Apps.launch("org.gnome.Calculator"); cc.close(); }
                }
                PillModule {
                    id: focusTile
                    x: 2 * grid.s; y: 3 * grid.s
                    title: Focus.doNotDisturb ? "Ne pas déranger" : "Concentration"
                    subtitle: Focus.untilLabel
                    symbol: "moon.fill"
                    glyphSize: 20
                    on: Focus.doNotDisturb
                    onGlyph: CCStyle.indigo
                    onToggled: Focus.toggle()
                    onExpand: cc.expand("focus", focusTile)
                }

                SliderModule {
                    x: 0; y: 4 * grid.s
                    title: "Écran"
                    leftSymbol: "sun.min.fill"
                    leftSize: 19
                    rightSymbol: "sun.max.fill"
                    rightSize: 21
                    value: Brightness.value
                    sliderEnabled: Brightness.available
                    onMoved: v => Brightness.set(v)
                }
                SliderModule {
                    id: soundTile
                    x: 0; y: 5 * grid.s
                    title: "Son"
                    leftSymbol: Audio.muted ? "speaker.slash.fill" : "speaker.fill"
                    leftSize: 21
                    rightSymbol: "speaker.wave.3.fill"
                    rightSize: 28
                    accessory: true
                    value: Audio.muted ? 0 : Audio.volume
                    sliderEnabled: Audio.ready
                    onMoved: v => Audio.setVolume(v)
                    onAccessoryClicked: cc.expand("sound", soundTile)
                    onTitleClicked: cc.expand("sound", soundTile)
                }
            }

            // ---------------- Module déplié ----------------
            Item {
                id: card
                visible: cc.expanded !== ""
                readonly property real targetH: Math.min(loader.item ? loader.item.implicitHeight + 6 : 200, win.height - CCStyle.marginTop - 24)
                readonly property real k: cc.ex
                x: cc.fromRect.x + (0 - cc.fromRect.x) * k
                y: cc.fromRect.y + (0 - cc.fromRect.y) * k
                width: cc.fromRect.width + (CCStyle.width - cc.fromRect.width) * k
                height: Math.max(10, cc.fromRect.height + (targetH - cc.fromRect.height) * k)

                Glass {
                    anchors.fill: parent
                    radius: Math.min(height / 2, cc.fromRadius + (CCStyle.radiusCard - cc.fromRadius) * Math.min(1, card.k))
                    // teinte du module -> teinte de carte (un peu plus dense pour la lisibilité)
                    readonly property real m: Math.min(1, card.k)
                    tint: Qt.rgba(CCStyle.tile.r + (CCStyle.card.r - CCStyle.tile.r) * m,
                                  CCStyle.tile.g + (CCStyle.card.g - CCStyle.tile.g) * m,
                                  CCStyle.tile.b + (CCStyle.card.b - CCStyle.tile.b) * m,
                                  CCStyle.tile.a + (CCStyle.card.a - CCStyle.tile.a) * m)
                    shadowBlur: 0.3 + 0.6 * Math.min(1, card.k)
                    shadowOffset: 2 + 4 * Math.min(1, card.k)
                    shadowColor: Qt.rgba(0, 0, 0, 0.25)
                    opacity: Math.min(1, card.k * 4)
                }

                Item {
                    anchors.fill: parent
                    clip: true
                    opacity: Math.max(0, Math.min(1, (card.k - 0.45) / 0.45))

                    Flickable {
                        width: CCStyle.width
                        height: parent.height
                        contentHeight: loader.item ? loader.item.implicitHeight + 6 : 0
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        Loader {
                            id: loader
                            y: 2
                            active: cc.expanded !== ""
                            sourceComponent: ({ wifi: wifiDetail, bluetooth: btDetail, sound: soundDetail, focus: focusDetail })[cc.expanded] ?? null
                        }
                    }
                }

                // Le clic dans la carte ne doit pas la refermer
                MouseArea {
                    anchors.fill: parent
                    z: -1
                }
            }
        }

        Component { id: wifiDetail; WifiDetail {} }
        Component { id: btDetail; BluetoothDetail {} }
        Component { id: soundDetail; SoundDetail {} }
        Component { id: focusDetail; FocusDetail {} }
    }
}
