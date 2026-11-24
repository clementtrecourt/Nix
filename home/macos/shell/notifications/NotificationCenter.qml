import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.common
import qs.services

// Centre de notifications macOS Tahoe : colonne de cartes de verre le long du
// bord droit (pas de panneau de fond), notifications groupées par app en haut,
// widgets en dessous. S'ouvre par un clic sur l'horloge de la barre des menus,
// le raccourci "notificationcenter" ou l'IPC (shell toggle notificationcenter).
PanelWindow {
    id: win

    readonly property bool open: ShellState.openPanel === "notificationcenter"
    readonly property int cardWidth: 344
    // Mesures des images Apple de macOS 26 (Centre de notifications) : bord droit
    // à ~16 pt de l'écran, premier élément ~33 pt sous le milieu du texte de la
    // barre des menus, même pas de 16 pt entre widgets dans les deux directions.
    readonly property int edgeMargin: 16
    readonly property int leftRoom: 24
    readonly property int topGap: 17
    readonly property int gap: 16

    // Widgets (liste et galerie : WidgetStore). Fermer le Centre ferme la galerie.
    onOpenChanged: if (!open) { WidgetStore.editing = false; widgetMenu.close(); }

    // Progression d'ouverture 0 → 1 (pilote le glissement depuis la droite)
    // (démarre quand la fenêtre est réellement visible, capture du fond prête)
    property real progress: open && backdrop.pass ? 1 : 0
    Behavior on progress {
        NumberAnimation {
            duration: (win.open ? 480 : 300) * NotifStore.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: win.open ? [0.16, 1.0, 0.3, 1.0, 1, 1] : [0.4, 0.0, 0.9, 0.6, 1, 1]
        }
    }

    screen: {
        const name = ShellState.panelScreen || Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }
    // Liquid Glass : capture de l'écran prise juste avant l'ouverture
    property Item glassBackdrop: backdrop
    GlassBackdrop {
        id: backdrop
        mode: "snapshot"
        screen: win.screen
        want: win.open || win.progress > 0
    }
    visible: backdrop.pass

    // "macos-lg-*" : pas de flou Hyprland (le verre floute et réfracte lui-même)
    WlrLayershell.namespace: "macos-lg-notificationcenter"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true; bottom: true }
    margins.top: Theme.menuBarHeight
    implicitWidth: cardWidth + edgeMargin + leftRoom
    color: "transparent"

    mask: Region {
        item: maskItem
        Region { item: actionMenu }
        Region { item: widgetMenu }
    }
    Item {
        id: maskItem
        x: column.x
        width: win.width
        height: Math.min(win.height, flick.contentHeight + win.topGap + 12)
    }

    // Clic en dehors = fermeture. Léger délai : si le clic tombe sur l'horloge,
    // c'est la barre des menus qui referme via toggle (sinon on rouvrirait).
    // La galerie de widgets fait partie de la saisie. Sa fermeture (fenêtre
    // démappée) annule la saisie Hyprland : on la reprend au lieu de fermer.
    HyprlandFocusGrab {
        id: grab
        property bool regrab: false
        property real galleryChange: 0
        windows: WidgetStore.galleryWindow ? [win, WidgetStore.galleryWindow] : [win]
        active: win.open && win.visible && !regrab
        onCleared: {
            if (WidgetStore.editing || Date.now() - galleryChange < 600) {
                regrab = true;
                Qt.callLater(() => grab.regrab = false);
            } else outsideTimer.restart();
        }
    }
    Connections {
        target: WidgetStore.galleryWindow
        function onVisibleChanged() { grab.galleryChange = Date.now(); }
    }
    Timer {
        id: outsideTimer
        interval: 250
        onTriggered: if (win.open) ShellState.close()
    }

    Item {
        id: column
        width: parent.width
        height: parent.height
        x: (1 - win.progress) * (win.cardWidth + win.edgeMargin + 30)
        opacity: Math.min(1, win.progress * 1.6)
        focus: win.open
        Keys.onEscapePressed: {
            if (widgetMenu.open) widgetMenu.close();
            else if (WidgetStore.editing) WidgetStore.editing = false;
            else ShellState.close();
        }

        Flickable {
            id: flick
            x: win.leftRoom
            y: win.topGap
            width: win.cardWidth + win.edgeMargin
            height: parent.height - y
            contentWidth: width
            contentHeight: content.implicitHeight + 20
            interactive: contentHeight > height
            boundsBehavior: Flickable.DragAndOvershootBounds
            clip: false

            Column {
                id: content
                width: win.cardWidth
                spacing: win.gap
                topPadding: 0

                // ---- Notifications, groupées par app ----
                ListView {
                    id: groups
                    width: win.cardWidth
                    height: contentHeight
                    interactive: false
                    spacing: 12
                    visible: count > 0
                    model: NotifStore.groupModel
                    delegate: NotifGroup {
                        cardWidth: win.cardWidth
                        menuHost: actionMenu
                    }
                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 240 }
                        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 320; easing.type: Easing.OutCubic }
                    }
                    remove: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "x"; to: win.cardWidth + 40; duration: 300; easing.type: Easing.InCubic }
                            NumberAnimation { property: "opacity"; to: 0; duration: 300 }
                        }
                    }
                    displaced: Transition {
                        NumberAnimation { properties: "x,y"; duration: 320; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "opacity"; to: 1; duration: 120 }
                        NumberAnimation { property: "scale"; to: 1; duration: 120 }
                    }
                    move: Transition {
                        NumberAnimation { properties: "y"; duration: 320; easing.type: Easing.OutCubic }
                    }
                }

                // ---- Widgets ----
                Flow {
                    width: win.cardWidth
                    spacing: win.gap
                    visible: WidgetStore.widgets.length > 0
                    Repeater {
                        model: WidgetStore.widgets
                        WidgetSlot {
                            required property string modelData
                            required property int index
                            wid: modelData
                            slotIndex: index
                        }
                    }
                }

                // Capsule « Edit Widgets » : ouvre la galerie de widgets (masquée
                // pendant l'édition, comme sur macOS : « Done » est dans la galerie)
                Item {
                    width: win.cardWidth
                    height: 22
                    Item {
                        id: editBtn
                        anchors.horizontalCenter: parent.horizontalCenter
                        // Image Apple (macOS 26) : ~85,5 × 22 pt, ~10 pt de marge
                        width: editLabel.implicitWidth + 20
                        height: 22
                        opacity: WidgetStore.editing ? 0 : 1
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                        NotifGlass {
                            anchors.fill: parent
                            radius: height / 2
                            tint: editMouse.pressed ? (Theme.dark ? Qt.rgba(0.30, 0.30, 0.32, 0.50) : Qt.rgba(1, 1, 1, 0.50))
                                : Theme.dark ? Qt.rgba(0.22, 0.22, 0.24, 0.34) : Qt.rgba(1, 1, 1, 0.30)
                            shadowOffset: 2
                            shadowBlur: 0.4
                        }
                        Text {
                            id: editLabel
                            anchors.centerIn: parent
                            text: "Edit Widgets"
                            // Texte clair légèrement teinté (vibrancy), plus pâle que le libellé
                            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(0.10, 0.14, 0.22, 0.52)
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: editMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { widgetMenu.close(); WidgetStore.editing = true; }
                        }
                    }
                }
            }
        }

        // Menu « Options » des notifications (au-dessus des cartes et widgets)
        ActionMenu { id: actionMenu }
    }

    // Widgets : composants par identifiant
    Component { id: upNextComp; WidgetUpNext {} }
    Component { id: calendarComp; WidgetCalendar { today: clockTick.now } }
    Component { id: clockComp; WidgetClock { running: win.visible } }

    // Emplacement de widget du Centre :
    //  - clic : ouvre l'app (Calendar, Clock…) et ferme le Centre ;
    //  - Ctrl-clic / clic droit : menu contextuel (« Edit Widgets… », « Remove Widget ») ;
    //  - bouton Remove (−) en haut à gauche pendant l'édition (galerie ouverte)
    //    ou au survol avec ⌥ enfoncée (aide Apple « Use Notification Center »).
    component WidgetSlot: Item {
        id: slot
        property string wid
        property int slotIndex: -1
        readonly property bool showRemove: WidgetStore.editing || optHover.hovered
        width: loader.width
        height: loader.height
        Loader {
            id: loader
            sourceComponent: slot.wid === "upnext" ? upNextComp : slot.wid === "calendar" ? calendarComp : clockComp
        }
        HoverHandler {
            id: optHover
            acceptedModifiers: Qt.AltModifier
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton || (mouse.modifiers & Qt.ControlModifier)) {
                    const p = mapToItem(column, mouse.x, mouse.y);
                    widgetMenu.openAt(slot.slotIndex, p.x, p.y);
                } else if (!WidgetStore.editing) {
                    WidgetStore.openApp(slot.wid);
                    ShellState.close();
                }
            }
        }
        // Bouton Remove : pastille ronde à cheval sur le coin haut-gauche (comme le ×)
        Item {
            x: -6
            y: -4
            width: 20
            height: 20
            opacity: slot.showRemove ? 1 : 0
            scale: slot.showRemove ? 1 : 0.6
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            Behavior on scale { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
            NotifGlass {
                anchors.fill: parent
                radius: 10
                tint: Theme.dark ? Qt.rgba(0.20, 0.20, 0.21, 0.85) : Qt.rgba(0.97, 0.97, 0.98, 0.90)
                shadowEnabled: false
            }
            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 1.6
                radius: 0.8
                color: Theme.dark ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(0, 0, 0, 0.62)
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -3
                enabled: slot.showRemove
                onClicked: WidgetStore.removeAt(slot.slotIndex)
            }
        }
    }

    // Clic ailleurs dans le Centre : ferme le menu contextuel
    MouseArea {
        parent: column
        anchors.fill: parent
        z: 199
        visible: widgetMenu.open
        acceptedButtons: Qt.AllButtons
        onPressed: widgetMenu.close()
    }
    // Menu contextuel d'un widget (Ctrl-clic)
    Item {
        id: widgetMenu
        property int target: -1
        readonly property bool open: target >= 0
        parent: column
        z: 200
        visible: open
        width: open ? Math.max(wmRemove.implicitWidth, wmEdit.implicitWidth) + 32 : 0
        height: open ? wmCol.implicitHeight + 10 : 0
        function openAt(i, px, py) {
            target = i;
            Qt.callLater(() => {
                x = Math.round(Math.min(px, column.width - width - 4));
                y = Math.round(py);
            });
        }
        function close() { target = -1; }
        NotifGlass {
            anchors.fill: parent
            radius: Theme.radiusMenu
            tint: Theme.dark ? Qt.rgba(0.17, 0.17, 0.18, 0.80) : Qt.rgba(0.97, 0.97, 0.98, 0.80)
            shadowOffset: 6
            shadowBlur: 0.8
        }
        Column {
            id: wmCol
            x: 5
            y: 5
            width: parent.width - 10
            WidgetMenuItem {
                id: wmEdit
                text: "Edit Widgets…"
                onTriggered: { widgetMenu.close(); WidgetStore.editing = true; }
            }
            Item {
                width: parent.width
                height: 11
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    height: 1
                    color: Theme.separator
                }
            }
            WidgetMenuItem {
                id: wmRemove
                text: "Remove Widget"
                onTriggered: { const i = widgetMenu.target; widgetMenu.close(); WidgetStore.removeAt(i); }
            }
        }
    }
    component WidgetMenuItem: Item {
        id: wmi
        property string text
        signal triggered()
        implicitWidth: wmiLabel.implicitWidth
        width: parent ? parent.width : 0
        height: 24
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMenuItem
            color: Theme.menuHighlight
            visible: wmiMouse.containsMouse
        }
        Text {
            id: wmiLabel
            x: 11
            anchors.verticalCenter: parent.verticalCenter
            text: wmi.text
            color: wmiMouse.containsMouse ? Theme.menuHighlightText : Theme.label
            font.family: Theme.font
            font.pixelSize: 13
        }
        MouseArea {
            id: wmiMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: wmi.triggered()
        }
    }

    // Débogage (pas de clic possible dans le banc de test)
    IpcHandler {
        target: "widgets-debug"
        function gallery(on: bool): void { WidgetStore.editing = on; }
        function menu(index: int): void { widgetMenu.openAt(index, 200, 120); }
        function closeMenu(): void { widgetMenu.close(); }
        function add(id: string): void { WidgetStore.add(id); }
        function remove(index: int): void { WidgetStore.removeAt(index); }
        function list(): string { return WidgetStore.widgets.join(","); }
    }

    // Date du jour (rafraîchie à minuit pour le calendrier)
    QtObject {
        id: clockTick
        property date now: new Date()
    }
    Timer {
        interval: 60000
        running: win.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: clockTick.now = new Date()
    }
}
