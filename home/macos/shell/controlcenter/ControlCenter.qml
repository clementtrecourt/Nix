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
//   (Sombre)(Capt.)[ Concentr. ]
//   [ Écran ---------------- ☼ ]
//   [ Son ------------- 🔊 (⌾) ]
//          ( Modifier les commandes )
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
    // Module déplié : "", "wifi", "bluetooth", "sound", "focus", "display", "mirroring"
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

    // Module d'origine du dépliage : sa plaque est masquée pendant que la carte
    // en sort (morphose : une seule plaque visible, pas deux superposées).
    property Item sourceTile: null

    function expand(name, tile) {
        if (!tile) return;
        // Déjà déplié (hors repli en cours) : on ignore. Pendant le repli d'un
        // autre module, on enchaîne directement (le clic n'est pas perdu).
        if (expanded !== "" && !collapseAnim.running) return;
        collapseAnim.stop();
        if (sourceTile) sourceTile.glassVisible = true;
        const p = tile.mapToItem(grid, 0, 0);
        fromRect = Qt.rect(p.x, p.y, tile.width, tile.height);
        fromRadius = tile.radius;
        sourceTile = tile;
        tile.glassVisible = false;
        expanded = name;
        ex = 0;
        expandAnim.restart();
    }
    function collapse() {
        if (expanded === "") return;
        expandAnim.stop();
        collapseAnim.restart();
        keys.forceActiveFocus();
    }
    function close() { ShellState.close(); }

    onOpenChanged: {
        if (open) {
            const name = ShellState.panelScreen || (Hyprland.focusedMonitor?.name ?? "");
            if (!win.visible)
                targetScreen = Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
            Brightness.refresh();
            // Échap doit toujours atteindre `keys` (un champ de saisie d'un
            // module déplié a pu garder le focus)
            keys.forceActiveFocus();
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
        onFinished: {
            cc.expanded = "";
            if (cc.sourceTile) cc.sourceTile.glassVisible = true;
            cc.sourceTile = null;
        }
    }

    // Capture : laisse le Control Center disparaître avant d'ouvrir la barre
    Timer {
        id: shotTimer
        interval: CCStyle.durClose + 60
        onTriggered: Quickshell.execDetached(["hyprctl", "dispatch", "global", "macos:screenshot-ui"])
    }

    GlobalShortcut {
        appid: "macos"
        name: "controlcenter"
        description: "Open Control Center"
        onPressed: ShellState.toggle("controlcenter")
    }

    // Débogage (banc de test : pas de clic souris possible)
    IpcHandler {
        target: "controlcenter-debug"
        function expand(name: string): void {
            const t = { wifi: wifiTile, bluetooth: btTile, sound: soundTile, focus: focusTile, display: displayTile, mirroring: mirrorTile }[name];
            cc.expand(name, t);
        }
        function collapse(): void { cc.collapse(); }
        function dark(on: bool): void { Theme.dark = on; }
        // Simule un rétroéclairage (machine de test sans /sys/class/backlight)
        function fakeBrightness(v: real): void { Brightness.available = true; Brightness.value = v; }
        function state(): string {
            // latence de la capture du fond à la dernière ouverture (ms)
            const snap = ccBackdrop.children.find(c => c.latencyMs !== undefined);
            return JSON.stringify({ open: cc.open, expanded: cc.expanded, ex: cc.ex, opacity: content.opacity, scale: content.scale, captureMs: snap?.latencyMs ?? -1 });
        }
        // Fige la progression du dépliage (captures image par image), -1 = libère
        function freeze(name: string, k: real): void {
            if (k < 0) { cc.collapse(); return; }
            const t = { wifi: wifiTile, bluetooth: btTile, sound: soundTile, focus: focusTile, display: displayTile, mirroring: mirrorTile }[name];
            cc.expand(name, t);
            expandAnim.stop();
            cc.ex = k;
        }
    }

    PanelWindow {
        id: win

        screen: cc.targetScreen
        // Le verre réfracte une capture de l'écran prise juste avant l'ouverture
        property Item glassBackdrop: ccBackdrop
        GlassBackdrop {
            id: ccBackdrop
            mode: "snapshot"
            screen: win.screen
            want: cc.shown || content.opacity > 0.001
        }
        visible: ccBackdrop.pass
        color: "transparent"
        anchors { top: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        margins.top: Theme.menuBarHeight
        implicitWidth: CCStyle.width + CCStyle.marginRight + 48
        implicitHeight: 640
        WlrLayershell.namespace: "macos-lg-controlcenter"
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

            // L'ouverture attend la capture du fond (pass, ~50 ms) : sans quoi le
            // début de l'animation se jouerait fenêtre encore cachée.
            states: State {
                name: "open"
                when: cc.shown && ccBackdrop.pass
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
                height: editTile.y + editTile.height
                readonly property int s: CCStyle.cell + CCStyle.gap
                opacity: 1 - Math.min(1, cc.ex * 1.8)
                scale: 1 - 0.05 * Math.min(1, cc.ex)
                visible: opacity > 0.001

                PillModule {
                    id: wifiTile
                    x: 0; y: 0
                    title: "Wi-Fi"
                    subtitle: !cc.wifiDevice ? "Not Available" : !cc.wifiOn ? "Off" : (cc.wifiNetwork?.name ?? "Not Connected")
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
                    subtitle: !cc.btOn ? "Off" : (cc.btConnected.length === 1 ? cc.btConnected[0].name : "On")
                    symbol: "bluetooth"
                    glyphSize: 23
                    on: cc.btOn
                    disabled: !cc.btAdapter
                    onToggled: if (cc.btAdapter) cc.btAdapter.enabled = !cc.btAdapter.enabled
                    onExpand: cc.expand("bluetooth", btTile)
                }
                // AirDrop n'existe pas ici : affiché dans son état "Désactivé" de
                // Tahoe (pastille grise, pictogramme barré), sans action.
                PillModule {
                    x: 0; y: 2 * grid.s
                    title: "AirDrop"
                    subtitle: "Off"
                    symbol: "airdrop.slash"
                    glyphSize: 23
                }

                NowPlaying {
                    x: 2 * grid.s; y: 0
                }
                // Stage Manager : pas d'équivalent sous Hyprland. Affiché pleinement
                // (disposition par défaut de Tahoe), réagit au survol / à la
                // pression, sans action.
                CircleModule {
                    x: 2 * grid.s; y: 2 * grid.s
                    symbol: "squares.leading.rectangle"
                    glyphSize: 32
                }
                // Recopie de l'écran : se déplie comme sur Tahoe (liste des
                // récepteurs AirPlay ; ici aucun, lien vers les réglages des écrans).
                CircleModule {
                    id: mirrorTile
                    x: 3 * grid.s; y: 2 * grid.s
                    symbol: "rectangle.on.rectangle"
                    glyphSize: 33
                    onClicked: cc.expand("mirroring", mirrorTile)
                }

                CircleModule {
                    x: 0; y: 3 * grid.s
                    symbol: "circle.lefthalf.filled.inverse"
                    glyphSize: 28
                    on: Theme.dark
                    onClicked: Appearance.toggle()
                }
                // Capture d'écran (défaut de Tahoe) : ferme le Control Center puis
                // ouvre la barre de capture (raccourci global macos:screenshot-ui,
                // contrat Cmd+Maj+5, porté par le composant notifications).
                CircleModule {
                    x: grid.s; y: 3 * grid.s
                    symbol: "camera.viewfinder"
                    glyphSize: 27
                    onClicked: {
                        cc.close();
                        shotTimer.restart();
                    }
                }
                PillModule {
                    id: focusTile
                    x: 2 * grid.s; y: 3 * grid.s
                    title: Focus.doNotDisturb ? Focus.modeNameEn : "Focus"
                    subtitle: Focus.untilLabelEn
                    symbol: Focus.doNotDisturb ? Focus.modeSymbol : "moon.fill"
                    glyphSize: 20
                    on: Focus.doNotDisturb
                    onGlyph: Focus.modeColor
                    onToggled: Focus.toggle()
                    onExpand: cc.expand("focus", focusTile)
                }

                SliderModule {
                    id: displayTile
                    x: 0; y: 4 * grid.s
                    expandable: true
                    onTitleClicked: cc.expand("display", displayTile)
                    title: "Display"
                    leftSymbol: "sun.min.fill"
                    leftSize: 17
                    rightSymbol: "sun.max.fill"
                    rightSize: 17
                    value: Brightness.value
                    sliderEnabled: Brightness.available
                    onMoved: v => Brightness.set(v)
                }
                SliderModule {
                    id: soundTile
                    x: 0; y: 5 * grid.s
                    title: "Sound"
                    leftSymbol: Audio.muted ? "speaker.slash.fill" : "speaker.fill"
                    leftSize: 19
                    leftCenterX: 21
                    trackLeft: 34.5
                    trackRightInset: 78.5
                    rightInset: 61
                    rightSymbol: "speaker.wave.3.fill"
                    rightSize: 20
                    accessory: true
                    expandable: true
                    value: Audio.muted ? 0 : Audio.volume
                    sliderEnabled: Audio.ready
                    onMoved: v => Audio.setVolume(v)
                    onAccessoryClicked: cc.expand("sound", soundTile)
                    onTitleClicked: cc.expand("sound", soundTile)
                }

                // « Modifier les commandes » : petite capsule de verre centrée à
                // 17 pt sous le module Son (Tahoe : 23,5 pt de haut, texte 13 pt
                // en vibrancy, 10 pt de marge). La personnalisation n'existe pas
                // ici : elle ouvre les réglages d'apparence du système.
                CCTile {
                    id: editTile
                    y: 5 * grid.s + CCStyle.cell + 17
                    x: (grid.width - width) / 2
                    width: editLabel.implicitWidth + 22
                    height: 24
                    radius: height / 2
                    onClicked: {
                        CCActions.openSettings("appearance");
                        cc.close();
                    }
                    Text {
                        renderType: Text.NativeRendering
                        id: editLabel
                        anchors.centerIn: parent
                        text: "Edit Controls"
                        color: CCStyle.vibrant
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
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
                    blur: CCStyle.glassBlur + (CCStyle.cardBlur - CCStyle.glassBlur) * m
                    saturation: CCStyle.glassSaturation
                    adaptive: CCStyle.glassAdaptive
                    shadowBlur: 0.3 + 0.6 * Math.min(1, card.k)
                    shadowOffset: 2 + 4 * Math.min(1, card.k)
                    shadowColor: Qt.rgba(0, 0, 0, 0.25)
                }

                // Morphose : le contenu du module d'origine (pastille, titre…)
                // reste à sa place dans la carte qui grandit et s'efface pendant
                // le premier tiers, avant l'apparition de la liste détaillée.
                ShaderEffectSource {
                    width: cc.fromRect.width
                    height: cc.fromRect.height
                    sourceItem: cc.sourceTile ? cc.sourceTile.contentLayer : null
                    live: true
                    opacity: Math.max(0, 1 - card.k / 0.4)
                    visible: opacity > 0 && sourceItem !== null
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
                            sourceComponent: ({ wifi: wifiDetail, bluetooth: btDetail, sound: soundDetail, focus: focusDetail, display: displayDetail, mirroring: mirrorDetail })[cc.expanded] ?? null
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
        Component { id: displayDetail; DisplayDetail {} }
        Component { id: mirrorDetail; MirroringDetail {} }

        // Un champ de saisie d'un module déplié (mot de passe Wi-Fi) rend le
        // focus clavier : Échap doit de nouveau replier / fermer.
        Connections {
            target: loader.item
            ignoreUnknownSignals: true
            function onFocusReleased() { keys.forceActiveFocus(); }
        }
    }
}
