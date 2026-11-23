import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Networking
import qs.common
import qs.services

// Barre de menus Tahoe d'un écran : transparente, libellés blancs (ou noirs sur
// fond clair) avec un léger halo. À gauche : logo, app en gras, menus ; à
// droite : barre d'état, batterie, Wi-Fi, Spotlight, Control Center, horloge.
PanelWindow {
    id: bar

    property var controller
    property var menus
    // Affiche le pourcentage de batterie (Réglages > Barre des menus)
    property bool showBatteryPercent: false
    // Debug : affiche batterie et Wi-Fi même sans matériel (captures du banc de test)
    property bool demo: false

    readonly property string screenName: screen?.name ?? ""
    readonly property bool menuHere: controller.isOpen && controller.screenName === screenName

    // ---- Plein écran : la barre se cache, et réapparaît au survol du bord ----
    readonly property var hmon: Hyprland.monitorFor(screen)
    readonly property bool fullscreen: {
        const ws = hmon?.activeWorkspace;
        if (!ws || !ws.hasFullscreen) return false;
        // "fullscreen 1" (Zoom / agrandir) ne cache pas la barre, seul le vrai plein écran
        const tops = ws.toplevels?.values ?? [];
        for (const t of tops)
            if ((t.lastIpcObject?.fullscreen ?? 0) === 2) return true;
        return false;
    }
    property bool revealed: false
    readonly property bool shown: !fullscreen || revealed || menuHere

    // Hyprland ne renvoie pas toujours l'état plein écran à jour : on rafraîchit
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["fullscreen", "openwindow", "closewindow", "workspacev2", "movewindowv2", "changefloatingmode"].includes(event.name))
                refresh.restart();
        }
    }
    Timer {
        id: refresh
        interval: 50
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
        }
    }

    color: "transparent"
    implicitHeight: Theme.menuBarHeight
    anchors {
        top: true
        left: true
        right: true
    }
    exclusionMode: fullscreen ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: fullscreen ? 0 : Theme.menuBarHeight
    WlrLayershell.layer: fullscreen ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "macos-menubar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // En plein écran masqué, seule une bande de 2 px reçoit la souris
    mask: Region {
        item: bar.shown ? content : revealStrip
    }
    Item {
        id: revealStrip
        width: parent.width
        height: 2
    }

    Component.onCompleted: {
        controller.registerBar(screenName, bar);
        refresh.restart();
    }

    // ---- Couleur du premier plan selon le fond ----
    BackdropTone {
        id: tone
        screen: bar.screen
        active: !!bar.hmon && !(bar.hmon.lastIpcObject?.disabled ?? false) && !bar.fullscreen
        stripHeight: Theme.menuBarHeight
        // Zones mesurées séparément : fin des menus, début des icônes d'état
        leftEnd: left.x + left.width + 12
        rightStart: right.x - 12
    }
    readonly property real backdropLuminance: tone.luminance
    readonly property real backdropLuminanceLeft: tone.luminanceLeft
    readonly property real backdropLuminanceRight: tone.luminanceRight
    property bool forceLight: false
    property bool forceDark: false
    // En plein écran, la barre révélée a un fond opaque aux couleurs de
    // l'apparence (clair ou sombre) : texte noir en mode clair, blanc en sombre.
    function toneFor(measured) {
        if (bar.fullscreen) return !Theme.dark;
        return forceLight || (!forceDark && measured);
    }
    readonly property bool light: toneFor(tone.light)
    readonly property bool lightLeft: toneFor(tone.lightLeft)
    readonly property bool lightRight: toneFor(tone.lightRight)
    readonly property color fg: light ? Qt.rgba(0, 0, 0, 0.88) : "white"
    readonly property color fgLeft: lightLeft ? Qt.rgba(0, 0, 0, 0.88) : "white"
    readonly property color fgRight: lightRight ? Qt.rgba(0, 0, 0, 0.88) : "white"

    // Centre de l'icône Control Center (repère de l'écran) : le HUD volume /
    // luminosité (controlcenter/Osd.qml) s'affiche dessous, comme sur Tahoe.
    // Publié par la barre de l'écran focalisé.
    readonly property real ccCenterX: right.x + ccBtn.x + ccBtn.width / 2
    readonly property bool focusedScreen: (Hyprland.focusedMonitor?.name ?? screenName) === screenName
    function publishCcX() { if (focusedScreen) ShellState.controlCenterIconX = ccCenterX; }
    onCcCenterXChanged: publishCcX()
    onFocusedScreenChanged: publishCcX()

    // ---- Menus ----
    readonly property var order: ["logo", "app"].concat(menus.titles().map(t => t.id))

    function buttonFor(id) {
        if (id === "logo") return logoBtn;
        if (id === "app") return appBtn;
        for (let i = 0; i < titleRep.count; i++) {
            const b = titleRep.itemAt(i);
            if (b && b.menuId === id) return b;
        }
        return null;
    }

    function openMenu(id, btn, viaKeyboard) {
        btn = btn ?? buttonFor(id);
        if (!btn) return;
        const p = btn.mapToItem(content, 0, 0);
        controller.open(id, screenName, p.x, btn.width, menus.build(id), viaKeyboard);
    }

    function openTray(item, btn) {
        const p = btn.mapToItem(content, 0, 0);
        controller.open("tray:" + item.id, screenName, p.x, btn.width, { handle: item.menu }, false);
    }

    function trayDebug() {
        const out = [];
        for (let i = 0; i < trayRep.count; i++) {
            const b = trayRep.itemAt(i);
            out.push({ id: b.modelData.id, icon: String(b.modelData.icon).slice(0, 80), visible: b.visible, active: b.active, x: b.x, w: b.width });
        }
        return out;
    }

    function openTrayIndex(i) {
        const btn = trayRep.itemAt(i);
        if (btn && btn.modelData.hasMenu) openTray(btn.modelData, btn);
    }

    // Menus des icônes d'état (batterie, Wi-Fi)
    function openStatus(id, btn, noToggle) {
        if (!noToggle && controller.openId === id && menuHere) { controller.close(false); return; }
        const p = btn.mapToItem(content, 0, 0);
        // (mode démo : batterie fictive à 82 %, comme le picto)
        const dev = bar.demo && !(batteryBtn.dev?.isLaptopBattery)
            ? { demo: true, percentage: 0.82, state: UPowerDeviceState.Discharging, timeToEmpty: 5 * 3600 + 20 * 60 }
            : batteryBtn.dev;
        const items = id === "battery" ? menus.batteryMenu(dev)
            : menus.wifiMenu(wifiBtn.device, wifiBtn.network);
        controller.open(id, screenName, p.x, btn.width, items, false);
    }
    function openStatusById(id) {
        openStatus(id, id === "battery" ? batteryBtn : wifiBtn, true);
    }
    function hoverStatus(id, btn) {
        if (menuHere && controller.openId !== id) openStatus(id, btn, true);
    }

    function openSibling(id, delta) {
        const i = order.indexOf(id);
        if (i < 0) return;
        openMenu(order[(i + delta + order.length) % order.length], null, true);
    }

    // Clic sur un titre : ouvre (ou ferme si c'est déjà lui)
    function press(id, btn) {
        if (controller.openId === id && menuHere) controller.close(false);
        else openMenu(id, btn, false);
    }
    // Survol d'un titre pendant qu'un menu est ouvert : bascule
    function hoverTitle(id, btn) {
        if (menuHere && controller.openId !== id) openMenu(id, btn, false);
    }

    // ---- Contenu ----
    Item {
        id: content
        width: parent.width
        height: Theme.menuBarHeight
        y: bar.shown ? 0 : -height
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        // Fond (uniquement en plein écran, quand la barre est révélée) : opaque,
        // comme la barre que macOS fait descendre au-dessus d'une app plein écran
        Rectangle {
            anchors.fill: parent
            visible: bar.fullscreen
            color: Theme.dark ? Qt.rgba(0.14, 0.14, 0.15, 1) : Qt.rgba(0.95, 0.95, 0.96, 1)
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.separator
            }
        }

        // Clic dans le vide de la barre : ferme le menu ouvert
        MouseArea {
            anchors.fill: parent
            onPressed: bar.controller.close(false)
        }

        HoverHandler {
            id: barHover
            onHoveredChanged: {
                if (!bar.fullscreen) return;
                if (hovered) hideTimer.stop();
                else hideTimer.restart();
            }
        }

        // ---- Gauche ----
        Row {
            id: left
            x: 7
            height: parent.height

            BarButton {
                id: logoBtn
                readonly property string menuId: "logo"
                padding: 11
                fg: bar.fgLeft
                lightBackdrop: bar.lightLeft
                halo: !bar.fullscreen
                active: bar.menuHere && bar.controller.openId === "logo"
                onPressed: bar.press("logo", logoBtn)
                onEntered: bar.hoverTitle("logo", logoBtn)

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -0.5
                    name: "nixos"
                    size: 18
                    tint: bar.fgLeft
                }
            }

            BarButton {
                id: appBtn
                readonly property string menuId: "app"
                fg: bar.fgLeft
                lightBackdrop: bar.lightLeft
                halo: !bar.fullscreen
                active: bar.menuHere && bar.controller.openId === "app"
                onPressed: bar.press("app", appBtn)
                onEntered: bar.hoverTitle("app", appBtn)

                BarText {
                    text: bar.menus.appName
                    font.weight: Font.Bold
                    color: bar.fgLeft
                }
            }

            Repeater {
                id: titleRep
                model: bar.menus.titles()
                delegate: BarButton {
                    id: tb
                    required property var modelData
                    readonly property string menuId: modelData.id
                    fg: bar.fgLeft
                    lightBackdrop: bar.lightLeft
                    halo: !bar.fullscreen
                    active: bar.menuHere && bar.controller.openId === menuId
                    onPressed: bar.press(menuId, tb)
                    onEntered: bar.hoverTitle(menuId, tb)

                    BarText {
                        text: tb.modelData.text
                        color: bar.fgLeft
                    }
                }
            }
        }

        // ---- Droite ----
        Row {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: 5
            height: parent.height

            // Barre d'état (StatusNotifierItem)
            Repeater {
                id: trayRep
                model: SystemTray.items
                delegate: BarButton {
                    id: tray
                    required property var modelData
                    visible: modelData.status !== Status.Passive
                    padding: 10
                    pillExtra: 5
                    fg: bar.fgRight
                    lightBackdrop: bar.lightRight
                    halo: !bar.fullscreen
                    active: bar.menuHere && bar.controller.openId === "tray:" + modelData.id
                    onPressed: mouse => {
                        const it = tray.modelData;
                        if (mouse.button === Qt.MiddleButton) it.secondaryActivate();
                        // Comme sur macOS, un clic ouvre le menu de l'élément s'il en a un
                        else if (it.hasMenu) {
                            if (bar.controller.openId === "tray:" + it.id) bar.controller.close(false);
                            else bar.openTray(it, tray);
                        } else it.activate();
                    }
                    onEntered: if (bar.menuHere && tray.modelData.hasMenu && bar.controller.openId !== "tray:" + tray.modelData.id) bar.openTray(tray.modelData, tray)

                    // Icônes « modèles » (symboliques, monochromes) : recolorées
                    // dans la couleur de la barre, comme les template images de
                    // macOS ; les icônes en couleur restent telles quelles.
                    // Détection : nom « -symbolic », ou analyse des pixels (MonoProbe).
                    IconImage {
                        id: trayIcon
                        readonly property bool template: /symbolic/i.test(tray.modelData.icon) || probe.mono
                        anchors.verticalCenter: parent.verticalCenter
                        source: tray.modelData.icon
                        implicitSize: 16
                        layer.enabled: template
                        layer.effect: MultiEffect {
                            // brightness 1 : tout pixel visible devient blanc,
                            // puis prend la couleur de la barre (silhouette unie)
                            brightness: 1.0
                            colorization: 1.0
                            colorizationColor: bar.fgRight
                        }
                    }
                    MonoProbe {
                        id: probe
                        target: trayIcon
                        key: String(tray.modelData.icon)
                    }
                }
            }

            // Batterie
            BarButton {
                id: batteryBtn
                readonly property var dev: UPower.displayDevice
                visible: bar.demo || (dev && dev.isLaptopBattery && dev.isPresent)
                padding: 10
                pillExtra: 5
                fg: bar.fgRight
                lightBackdrop: bar.lightRight
                halo: !bar.fullscreen
                active: bar.menuHere && bar.controller.openId === "battery"
                onPressed: bar.openStatus("battery", batteryBtn)
                onEntered: bar.hoverStatus("battery", batteryBtn)

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    BarText {
                        visible: bar.showBatteryPercent
                        text: (bar.demo ? 82 : Math.round((batteryBtn.dev?.percentage ?? 0) * 100)) + " %"
                        color: bar.fgRight
                        font.pixelSize: 12
                    }
                    BatteryGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        color: bar.fgRight
                        level: bar.demo ? 0.82 : (batteryBtn.dev?.percentage ?? 1)
                        charging: batteryBtn.dev?.state === UPowerDeviceState.Charging || batteryBtn.dev?.state === UPowerDeviceState.PendingCharge
                        pluggedFull: !UPower.onBattery && batteryBtn.dev?.state === UPowerDeviceState.FullyCharged
                        lowPower: PowerProfiles.profile === PowerProfile.PowerSaver
                    }
                }
            }

            // Wi-Fi
            BarButton {
                id: wifiBtn
                readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
                readonly property var network: device ? (device.networks.values.find(n => n.connected) ?? null) : null
                visible: bar.demo || device !== null
                padding: 10
                pillExtra: 5
                fg: bar.fgRight
                lightBackdrop: bar.lightRight
                halo: !bar.fullscreen
                active: bar.menuHere && bar.controller.openId === "wifi"
                onPressed: bar.openStatus("wifi", wifiBtn)
                onEntered: bar.hoverStatus("wifi", wifiBtn)

                WifiGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    color: bar.fgRight
                    off: !bar.demo && !Networking.wifiEnabled
                    level: {
                        if (bar.demo) return 3;
                        const s = wifiBtn.network?.signalStrength ?? 0;
                        if (!wifiBtn.network) return 0;
                        return s > 0.6 ? 3 : s > 0.3 ? 2 : 1;
                    }
                }
            }

            // Spotlight
            BarButton {
                id: spotBtn
                padding: 10
                pillExtra: 5
                fg: bar.fgRight
                lightBackdrop: bar.lightRight
                halo: !bar.fullscreen
                active: ShellState.openPanel === "spotlight"
                onPressed: ShellState.toggle("spotlight")

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "magnifyingglass"
                    size: 15
                    tint: bar.fgRight
                }
            }

            // Control Center
            BarButton {
                id: ccBtn
                padding: 10
                pillExtra: 5
                fg: bar.fgRight
                lightBackdrop: bar.lightRight
                halo: !bar.fullscreen
                active: ShellState.openPanel === "controlcenter"
                onPressed: ShellState.toggle("controlcenter")

                ControlCenterGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    color: bar.fgRight
                }

            }

            // Date et heure ("lun. 23 nov. 17:20")
            BarButton {
                id: clockBtn
                padding: 10
                fg: bar.fgRight
                lightBackdrop: bar.lightRight
                halo: !bar.fullscreen
                active: ShellState.openPanel === "notificationcenter"
                onPressed: ShellState.toggle("notificationcenter")

                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes
                }
                // La date et l'heure sont séparées par un blanc plus large qu'une
                // espace (« Tue Apr 1  9:41 AM » sur la capture Apple)
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    BarText {
                        text: Qt.locale("fr_FR").toString(clock.date, "ddd d MMM")
                        color: bar.fgRight
                    }
                    BarText {
                        text: Qt.locale("fr_FR").toString(clock.date, "HH:mm")
                        color: bar.fgRight
                    }
                }
            }
        }
    }

    // Révélation en plein écran : pointeur contre le bord haut
    HoverHandler {
        id: edgeHover
        enabled: bar.fullscreen && !bar.revealed
        onHoveredChanged: if (hovered) revealTimer.restart(); else revealTimer.stop()
    }
    Timer {
        id: revealTimer
        interval: 250
        onTriggered: bar.revealed = true
    }
    Timer {
        id: hideTimer
        interval: 450
        onTriggered: if (!bar.menuHere && !barHover.hovered) bar.revealed = false
    }
    onFullscreenChanged: revealed = false
}
