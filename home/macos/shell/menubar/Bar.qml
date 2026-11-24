import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Services.Mpris
import qs.common
import qs.services
import qs.notifications
import qs.controlcenter as CC

// Barre de menus Tahoe d'un écran : transparente, libellés blancs (ou noirs sur
// fond clair) avec un léger halo. À gauche : logo, app en gras, menus ; à
// droite : barre d'état, batterie, Wi-Fi, Spotlight, Control Center, horloge.
//
// Réglages de System Settings > Menu Bar (services/SystemPrefs.qml, en direct) :
//  - « Automatically hide and show the menu bar » : Always / On Desktop Only /
//    In Full Screen Only (défaut) / Never ; masquée, la barre réapparaît au
//    survol du bord haut, par-dessus les fenêtres, avec un fond opaque ;
//  - « Show menu bar background » : fond translucide flouté ;
//  - Menu Bar Controls : chaque contrôle « Always Show in Menu Bar », « Show
//    When Active » (Bluetooth connecté, Focus actif, HUD volume / luminosité,
//    lecture en cours, recopie d'écran) ou masqué ;
//  - Date & Time > « 24-hour time » : horloge « 21:41 ».
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
    // Masquage automatique (System Settings > Menu Bar), selon l'espace affiché
    readonly property string autohideMode: SystemPrefs.menuBarAutohide
    readonly property bool autoHide: autohideMode === "always"
        || (autohideMode === "desktop" && !fullscreen)
        || (autohideMode === "fullscreen" && fullscreen)
    // La barre passe au-dessus des fenêtres (masquage automatique, ou plein
    // écran avec « Never ») : fond opaque, texte aux couleurs de l'apparence
    readonly property bool overApp: autoHide || fullscreen
    // « Show menu bar background » : fond translucide (hors barre au-dessus des fenêtres)
    readonly property bool tinted: SystemPrefs.menuBarBackground && !overApp
    property bool revealed: false
    readonly property bool shown: !autoHide || revealed || menuHere

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

    // Fond réfracté par les pastilles de verre : derrière la barre, il n'y a
    // que le fond d'écran (zone exclusive), sauf en plein écran (fond opaque)
    property Item glassBackdrop: backdrop
    GlassBackdrop {
        id: backdrop
        mode: "wallpaper"
        screen: bar.screen
        want: true
    }

    color: "transparent"
    implicitHeight: Theme.menuBarHeight
    anchors {
        top: true
        left: true
        right: true
    }
    exclusionMode: autoHide || fullscreen ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: autoHide || fullscreen ? 0 : Theme.menuBarHeight
    WlrLayershell.layer: overApp ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "macos-lg-menubar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Masquée, seule une bande de 2 px reçoit la souris
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
        active: !!bar.hmon && !(bar.hmon.lastIpcObject?.disabled ?? false) && !bar.overApp && !bar.tinted
        stripHeight: Theme.menuBarHeight
        // Zones mesurées séparément : fin des menus, début des icônes d'état
        leftEnd: left.x + left.width + 12
        rightStart: right.x - 12
    }
    // Apparence changée : le fond d'écran change aussi (variantes claire /
    // sombre) ; on remesure sans attendre l'échantillonnage périodique
    Connections {
        target: Theme
        function onDarkChanged() { toneKick.restart(); }
    }
    Timer {
        id: toneKick
        interval: 400
        onTriggered: tone.sample()
    }
    readonly property real backdropLuminance: tone.luminance
    readonly property real backdropLuminanceLeft: tone.luminanceLeft
    readonly property real backdropLuminanceRight: tone.luminanceRight
    property bool forceLight: false
    property bool forceDark: false
    // En plein écran, la barre révélée a un fond opaque aux couleurs de
    // l'apparence (clair ou sombre) : texte noir en mode clair, blanc en sombre.
    // Idem avec le fond translucide de « Show menu bar background ».
    function toneFor(measured) {
        if (bar.overApp || bar.tinted) return !Theme.dark;
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

    // ---- Menu Bar Controls (System Settings > Menu Bar) ----
    // "show" : toujours ; "active" : seulement si `isActive` ; "hide" : jamais
    function ctlShown(id, isActive) {
        const st = SystemPrefs.control(id);
        return st === "show" || (st === "active" && !!isActive);
    }
    readonly property bool btActive: (CC.Bt.adapter?.enabled ?? false)
        && (CC.Bt.adapter?.devices?.values ?? []).some(d => d.connected)
    readonly property bool mirroringActive: DisplayState.mirroring || DisplayState.sharing
    readonly property bool playingActive: Mpris.players.values.some(p => p.isPlaying)
    // Contrôles des modules, de gauche à droite (puis Wi-Fi et batterie)
    readonly property var moduleControls: ["nowPlaying", "screenMirroring", "display", "sound", "focus", "bluetooth"]
    function ctlSymbol(id) {
        return { nowPlaying: "play.fill", screenMirroring: "cc.screenmirroring", display: "display",
                 sound: "speaker.wave.2.fill", focus: Focus.modeSymbol, bluetooth: "bluetooth" }[id] ?? "";
    }
    // HUD associé (controlcenter/Osd.qml) : volume pour Sound, luminosité pour Display
    function ctlOsd(id) { return id === "sound" ? "volume" : id === "display" ? "brightness" : ""; }
    function ctlActive(id) {
        switch (id) {
        case "nowPlaying": return playingActive;
        case "screenMirroring": return mirroringActive;
        case "display":
        case "sound": return ShellState.osdKind === ctlOsd(id);
        case "focus": return Focus.doNotDisturb;
        case "bluetooth": return btActive;
        }
        return false;
    }

    // Menu Fast User Switching
    function openUserMenu(btn) {
        if (controller.openId === "userSwitch" && menuHere) { controller.close(false); return; }
        const p = btn.mapToItem(content, 0, 0);
        const items = [
            { text: menus.userName, enabled: false, checked: true },
            { separator: true },
            { text: "Login Window…", enabled: true, action: () => ShellState.open("lock") }
        ];
        controller.open("userSwitch", screenName, p.x - btn.pillExtra, btn.width, items, false);
    }

    // ---- Géométrie de la barre (px = pt à l'échelle 1) ----
    // Titres : 22 pt entre deux libellés (encre à encre), pastille débordant de
    // 16 pt de part et d'autre de l'encre (512pixels, macOS 26.0 : Finder 55-95,
    // pastille 39-110,5). Valeurs entières : rien ne tombe entre deux pixels.
    readonly property int logoPadding: 9
    readonly property int titlePadding: 10
    readonly property int titlePillExtra: 5
    // Haut du logo Apple (15 px) : centré sur les capitales du texte
    readonly property int logoY: 7

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
        // Le menu s'aligne sur le bord gauche de la pastille du titre
        controller.open(id, screenName, p.x - btn.pillExtra, btn.width, menus.build(id), viaKeyboard);
    }

    function openTray(item, btn) {
        const p = btn.mapToItem(content, 0, 0);
        controller.open("tray:" + item.id, screenName, p.x - btn.pillExtra, btn.width, { handle: item.menu }, false);
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
        controller.open(id, screenName, p.x - btn.pillExtra, btn.width, items, false);
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

    // Glisser bouton enfoncé depuis un titre (p : repère de la barre). Dans la
    // barre, le titre survolé ouvre son menu ; plus bas, la couche de menu
    // suit le pointeur et choisit l'élément au relâchement.
    function dragAt(p, release) {
        if (!menuHere) return;
        const layer = controller.layers[screenName];
        const top = layer ? layer.top : Theme.menuBarHeight;
        if (p.y < top) {
            if (release) return;   // relâché sur la barre : le menu reste ouvert
            for (const id of order) {
                const b = buttonFor(id);
                if (!b) continue;
                const q = b.mapFromItem(null, p.x, p.y);
                if (q.x >= 0 && q.x < b.width) { hoverTitle(id, b); return; }
            }
            return;
        }
        if (layer) layer.dragAt(p.x, p.y - top, release);
    }

    // ---- Contenu ----
    Item {
        id: content
        width: parent.width
        height: Theme.menuBarHeight
        y: bar.shown ? 0 : -height
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        // « Show menu bar background » : fond d'écran flouté sous un voile aux
        // couleurs de l'apparence (barre translucide d'avant Tahoe)
        Item {
            anchors.fill: parent
            visible: bar.tinted
            ShaderEffectSource {
                id: barUnder
                anchors.fill: parent
                sourceItem: bar.tinted ? backdrop : null
                sourceRect: Qt.rect(0, 0, width, height)
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: barUnder
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 40
                saturation: 0.3
            }
            Rectangle {
                anchors.fill: parent
                color: Theme.dark ? Qt.rgba(0.12, 0.12, 0.13, 0.55) : Qt.rgba(0.97, 0.97, 0.98, 0.62)
            }
        }

        // Fond (barre au-dessus des fenêtres : plein écran, ou masquage
        // automatique, quand la barre est révélée) : opaque, comme la barre que
        // macOS fait descendre au-dessus d'une app plein écran
        Rectangle {
            anchors.fill: parent
            visible: bar.overApp
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
                if (!bar.autoHide) return;
                if (hovered) hideTimer.stop();
                else hideTimer.restart();
            }
        }

        // ---- Gauche ----
        // Mesures Tahoe (capture Ars Technica 2x) : logo Apple de 12,5 x 15 pt
        // à 21 pt du bord, 22 pt entre deux libellés (logo -> nom de l'app
        // compris), pastille débordant de 16 pt de part et d'autre du texte.
        Row {
            id: left
            x: 11
            height: parent.height

            BarButton {
                id: logoBtn
                readonly property string menuId: "logo"
                padding: bar.logoPadding
                pillExtra: bar.titlePillExtra
                fg: bar.fgLeft
                lightBackdrop: bar.lightLeft
                halo: !bar.overApp && !bar.tinted
                glassPill: !bar.overApp
                active: bar.menuHere && bar.controller.openId === "logo"
                onPressed: bar.press("logo", logoBtn)
                onEntered: bar.hoverTitle("logo", logoBtn)
                onDragged: p => bar.dragAt(p, false)
                onReleased: p => bar.dragAt(p, true)

                // Logo Apple (menu Apple) : SVG rastérisé à 15 px exactement, sur
                // pixels entiers (logo de 12,2 x 15 px, Tahoe : 12,5 x 15 pt,
                // centré sur les capitales du texte, About-This-Mac.png de 512pixels)
                Glyph {
                    y: bar.logoY
                    name: "apple.logo"
                    size: 15
                    tint: bar.fgLeft
                }
            }

            BarButton {
                id: appBtn
                readonly property string menuId: "app"
                padding: bar.titlePadding
                pillExtra: bar.titlePillExtra
                fg: bar.fgLeft
                lightBackdrop: bar.lightLeft
                halo: !bar.overApp && !bar.tinted
                glassPill: !bar.overApp
                active: bar.menuHere && bar.controller.openId === "app"
                onPressed: bar.press("app", appBtn)
                onEntered: bar.hoverTitle("app", appBtn)
                onDragged: p => bar.dragAt(p, false)
                onReleased: p => bar.dragAt(p, true)

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
                    padding: bar.titlePadding
                    pillExtra: bar.titlePillExtra
                    fg: bar.fgLeft
                    lightBackdrop: bar.lightLeft
                    halo: !bar.overApp && !bar.tinted
                    glassPill: !bar.overApp
                    active: bar.menuHere && bar.controller.openId === menuId
                    onPressed: bar.press(menuId, tb)
                    onEntered: bar.hoverTitle(menuId, tb)
                    onDragged: p => bar.dragAt(p, false)
                    onReleased: p => bar.dragAt(p, true)

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
            // (l'horloge se termine à ~18,5 pt du bord droit)
            anchors.rightMargin: 8
            height: parent.height

            // Enregistrement d'écran en cours (⇧⌘5) : bouton « Stop Recording » de
            // macOS, à gauche des icônes d'état ; la pastille flottante de
            // notifications/ se masque quand la barre l'affiche.
            Component.onCompleted: Shots.menuBarStopButton = true
            BarButton {
                id: stopRecBtn
                visible: Shots.recording
                slotWidth: 37
                pillExtra: 4
                fg: bar.fgRight
                lightBackdrop: bar.lightRight
                halo: !bar.overApp && !bar.tinted
                glassPill: !bar.overApp
                onPressed: Shots.stopRecording()

                Glyph {
                    y: 7
                    name: "stop.circle"
                    size: 16
                    tint: bar.fgRight
                }
            }

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
                    halo: !bar.overApp && !bar.tinted
                    glassPill: !bar.overApp
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
                    onDragged: p => bar.dragAt(p, false)
                    onReleased: p => bar.dragAt(p, true)

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

            // Contrôles des modules du Control Center (Menu Bar Controls) :
            // toujours affichés, ou seulement quand ils sont actifs ; un clic
            // ouvre le Control Center
            Repeater {
                model: bar.moduleControls
                delegate: BarButton {
                    id: mc
                    required property string modelData
                    readonly property string osd: bar.ctlOsd(modelData)
                    visible: bar.ctlShown(modelData, bar.ctlActive(modelData))
                    slotWidth: 37
                    pillExtra: 4
                    fg: bar.fgRight
                    lightBackdrop: bar.lightRight
                    halo: !bar.overApp && !bar.tinted
                    glassPill: !bar.overApp
                    // Comme Tahoe : l'élément est en surbrillance tant que son HUD est affiché
                    active: mc.osd !== "" && ShellState.osdKind === mc.osd
                    onPressed: ShellState.toggle("controlcenter")

                    // Le HUD volume / luminosité se centre sous son élément
                    readonly property real centerX: (parent ? parent.x : 0) + x + width / 2
                    readonly property bool anchorsOsd: visible && osd !== "" && ShellState.osdKind === osd
                    function publish() { if (anchorsOsd && bar.focusedScreen) ShellState.osdAnchorX = centerX; }
                    onAnchorsOsdChanged: {
                        if (anchorsOsd) publish();
                        else if (bar.focusedScreen && ShellState.osdKind === "") ShellState.osdAnchorX = -1;
                    }
                    onCenterXChanged: publish()

                    Glyph {
                        y: 7
                        name: bar.ctlSymbol(mc.modelData)
                        size: 16
                        tint: bar.fgRight
                    }
                }
            }

            // Wi-Fi (Tahoe : à gauche de la batterie, guide macOS 26 « The menu bar »)
            BarButton {
                id: wifiBtn
                readonly property var device: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
                readonly property var network: device ? (device.networks.values.find(n => n.connected) ?? null) : null
                visible: bar.ctlShown("wifi", true) && (bar.demo || device !== null)
                // Tahoe (512pixels, 26.0) : centres des pictos espacés de 39,75
                // (Wi-Fi -> batterie), 37 (batterie -> Spotlight) et 37,25 pt
                // (Spotlight -> Control Center) : emplacements de largeur fixe
                slotWidth: 42
                pillExtra: 4
                fg: bar.fgRight
                lightBackdrop: bar.lightRight
                halo: !bar.overApp && !bar.tinted
                glassPill: !bar.overApp
                active: bar.menuHere && bar.controller.openId === "wifi"
                onPressed: bar.openStatus("wifi", wifiBtn)
                onEntered: bar.hoverStatus("wifi", wifiBtn)
                onDragged: p => bar.dragAt(p, false)
                onReleased: p => bar.dragAt(p, true)

                WifiGlyph {
                    y: 9
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

            // Batterie
            BarButton {
                id: batteryBtn
                readonly property var dev: UPower.displayDevice
                visible: bar.ctlShown("battery", true) && (bar.demo || (dev && dev.isLaptopBattery && dev.isPresent))
                // (avec le pourcentage, l'emplacement s'élargit au contenu)
                slotWidth: bar.showBatteryPercent ? 0 : 37
                padding: 9
                pillExtra: 4
                fg: bar.fgRight
                lightBackdrop: bar.lightRight
                halo: !bar.overApp && !bar.tinted
                glassPill: !bar.overApp
                active: bar.menuHere && bar.controller.openId === "battery"
                onPressed: bar.openStatus("battery", batteryBtn)
                onEntered: bar.hoverStatus("battery", batteryBtn)
                onDragged: p => bar.dragAt(p, false)
                onReleased: p => bar.dragAt(p, true)

                Row {
                    height: parent.height
                    spacing: 5
                    // « 82% » sans espace, même corps que l'horloge (macOS US,
                    // ars-tahoe-light.jpg)
                    BarText {
                        visible: bar.showBatteryPercent
                        text: (bar.demo ? 82 : Math.round((batteryBtn.dev?.percentage ?? 0) * 100)) + "%"
                        color: bar.fgRight
                    }
                    BatteryGlyph {
                        y: 9
                        color: bar.fgRight
                        level: bar.demo ? 0.82 : (batteryBtn.dev?.percentage ?? 1)
                        charging: batteryBtn.dev?.state === UPowerDeviceState.Charging || batteryBtn.dev?.state === UPowerDeviceState.PendingCharge
                        pluggedFull: !UPower.onBattery && batteryBtn.dev?.state === UPowerDeviceState.FullyCharged
                        lowPower: PowerProfiles.profile === PowerProfile.PowerSaver
                    }
                }
            }

            // Spotlight
            // Fast User Switching (Menu Bar Controls) : icône, nom complet ou
            // nom du compte ; menu : utilisateur courant, Login Window…
            BarButton {
                id: userBtn
                visible: SystemPrefs.control("userSwitch") !== "hide"
                readonly property string style: SystemPrefs.userSwitchStyle
                slotWidth: style === "icon" ? 37 : 0
                padding: 9
                pillExtra: 4
                fg: bar.fgRight
                lightBackdrop: bar.lightRight
                halo: !bar.overApp && !bar.tinted
                glassPill: !bar.overApp
                active: bar.menuHere && bar.controller.openId === "userSwitch"
                onPressed: bar.openUserMenu(userBtn)
                onEntered: if (bar.menuHere && bar.controller.openId !== "userSwitch") bar.openUserMenu(userBtn)
                onDragged: p => bar.dragAt(p, false)
                onReleased: p => bar.dragAt(p, true)

                Glyph {
                    visible: userBtn.style === "icon"
                    y: 7
                    name: "person.crop.circle"
                    size: 16
                    tint: bar.fgRight
                }
                BarText {
                    visible: userBtn.style !== "icon"
                    text: userBtn.style === "name" ? bar.menus.userName : (Quickshell.env("USER") ?? "")
                    color: bar.fgRight
                }
            }

            BarButton {
                id: spotBtn
                visible: bar.ctlShown("spotlight", true)
                slotWidth: 37
                pillExtra: 4
                fg: bar.fgRight
                lightBackdrop: bar.lightRight
                halo: !bar.overApp && !bar.tinted
                glassPill: !bar.overApp
                active: ShellState.openPanel === "spotlight"
                onPressed: ShellState.toggle("spotlight")

                Glyph {
                    y: 8
                    name: "magnifyingglass"
                    size: 15
                    tint: bar.fgRight
                }
            }

            // Control Center
            BarButton {
                id: ccBtn
                slotWidth: 37
                pillExtra: 4
                fg: bar.fgRight
                lightBackdrop: bar.lightRight
                halo: !bar.overApp && !bar.tinted
                glassPill: !bar.overApp
                active: ShellState.openPanel === "controlcenter"
                onPressed: ShellState.toggle("controlcenter")

                ControlCenterGlyph {
                    y: 8
                    color: bar.fgRight
                }

            }

            // Date et heure au format US de macOS ("Tue Nov 24  9:12 AM")
            BarButton {
                id: clockBtn
                // (fin de l'horloge à 19,5 pt du bord droit ; ~19 pt entre le
                // picto du Control Center et la date)
                paddingLeft: 7
                paddingRight: 10
                fg: bar.fgRight
                lightBackdrop: bar.lightRight
                halo: !bar.overApp && !bar.tinted
                glassPill: !bar.overApp
                active: ShellState.openPanel === "notificationcenter"
                onPressed: ShellState.toggle("notificationcenter")

                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes
                }
                // La date et l'heure sont séparées par un blanc plus large qu'une
                // espace (« Tue Apr 1  9:41 AM » sur la capture Apple)
                readonly property var usLocale: Qt.locale("en_US")
                Row {
                    height: parent.height
                    spacing: 7
                    BarText {
                        text: clockBtn.usLocale.toString(clock.date, "ddd MMM d")
                        color: bar.fgRight
                    }
                    BarText {
                        // Espace fine insécable (U+202F) avant AM/PM, comme macOS ;
                        // « 24-hour time » (Date & Time) : « 21:41 »
                        text: SystemPrefs.clock24 ? clockBtn.usLocale.toString(clock.date, "HH:mm")
                                                  : clockBtn.usLocale.toString(clock.date, "h:mm AP").replace(" ", "\u202F")
                        color: bar.fgRight
                    }
                }
            }
        }
    }

    // Révélation (barre masquée) : pointeur contre le bord haut
    HoverHandler {
        id: edgeHover
        enabled: bar.autoHide && !bar.revealed
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
    onAutoHideChanged: revealed = false
}
