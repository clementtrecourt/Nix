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

    // ---- Widgets (ordre macOS : le moyen en haut, les petits en dessous) ----
    readonly property var widgetIds: ["upnext", "calendar", "clock"]
    property var hiddenWidgets: []
    readonly property var shownWidgets: widgetIds.filter(w => !hiddenWidgets.includes(w))
    readonly property var availableWidgets: widgetIds.filter(w => hiddenWidgets.includes(w))
    // Mode « Modifier les widgets » : pastille − pour retirer, + pour remettre
    property bool editing: false
    onOpenChanged: if (!open) editing = false

    function setHidden(id, hide) {
        const l = hiddenWidgets.filter(w => w !== id);
        if (hide) l.push(id);
        hiddenWidgets = l;
        widgetCfg.setText(JSON.stringify({ hidden: l }));
    }
    FileView {
        id: widgetCfg
        path: Quickshell.statePath("widgets.json")
        printErrors: false
        blockLoading: true
        atomicWrites: true
    }
    Component.onCompleted: {
        try { hiddenWidgets = JSON.parse(widgetCfg.text() || "{}").hidden ?? []; } catch (e) {}
    }

    // Progression d'ouverture 0 → 1 (pilote le glissement depuis la droite)
    property real progress: open ? 1 : 0
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
    visible: open || progress > 0

    WlrLayershell.namespace: "macos-notificationcenter"
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
    }
    Item {
        id: maskItem
        x: column.x
        width: win.width
        height: Math.min(win.height, flick.contentHeight + win.topGap + 12)
    }

    // Clic en dehors = fermeture. Léger délai : si le clic tombe sur l'horloge,
    // c'est la barre des menus qui referme via toggle (sinon on rouvrirait).
    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: outsideTimer.restart()
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
        Keys.onEscapePressed: ShellState.close()

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
                    visible: win.shownWidgets.length > 0
                    Repeater {
                        model: win.shownWidgets
                        WidgetSlot {
                            required property string modelData
                            wid: modelData
                            editing: win.editing
                            onToggled: win.setHidden(modelData, true)
                        }
                    }
                }

                // Capsule « Modifier les widgets » (« Terminé » en mode édition)
                Item {
                    width: win.cardWidth
                    height: 22
                    Item {
                        id: editBtn
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: editLabel.implicitWidth + 24
                        height: 22
                        NotifGlass {
                            anchors.fill: parent
                            radius: height / 2
                            tint: editMouse.pressed ? (Theme.dark ? Qt.rgba(0.30, 0.30, 0.32, 0.55) : Qt.rgba(1, 1, 1, 0.55))
                                : Theme.dark ? Qt.rgba(0.22, 0.22, 0.24, 0.42) : Qt.rgba(1, 1, 1, 0.34)
                            shadowOffset: 2
                            shadowBlur: 0.4
                        }
                        Text {
                            id: editLabel
                            anchors.centerIn: parent
                            text: win.editing ? "Terminé" : "Modifier les widgets"
                            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.78) : Qt.rgba(0, 0, 0, 0.58)
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.weight: win.editing ? Font.DemiBold : Font.Medium
                        }
                        MouseArea {
                            id: editMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.editing = !win.editing
                        }
                    }
                }

                // Mode édition : widgets retirés, à remettre avec +
                Column {
                    width: win.cardWidth
                    spacing: 10
                    visible: win.editing && win.availableWidgets.length > 0
                    Text {
                        x: 4
                        text: "Widgets disponibles"
                        color: Theme.labelSecondary
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    Flow {
                        width: win.cardWidth
                        spacing: win.gap
                        Repeater {
                            model: win.editing ? win.availableWidgets : []
                            WidgetSlot {
                                required property string modelData
                                wid: modelData
                                editing: true
                                available: true
                                onToggled: win.setHidden(modelData, false)
                            }
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

    // Emplacement de widget : le widget + la pastille −/+ du mode édition
    component WidgetSlot: Item {
        id: slot
        property string wid
        property bool editing: false
        property bool available: false
        signal toggled()
        width: loader.width
        height: loader.height
        Loader {
            id: loader
            sourceComponent: slot.wid === "upnext" ? upNextComp : slot.wid === "calendar" ? calendarComp : clockComp
            opacity: slot.available ? 0.55 : 1
        }
        // Pastille ronde à cheval sur le coin haut-gauche (comme le × des notifications)
        Item {
            x: -7
            y: -7
            width: 22
            height: 22
            opacity: slot.editing ? 1 : 0
            scale: slot.editing ? 1 : 0.6
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            Behavior on scale { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
            NotifGlass {
                anchors.fill: parent
                radius: 11
                tint: Theme.dark ? Qt.rgba(0.20, 0.20, 0.21, 0.85) : Qt.rgba(0.97, 0.97, 0.98, 0.90)
                shadowEnabled: false
            }
            Rectangle {
                anchors.centerIn: parent
                width: 9
                height: 1.8
                radius: 1
                color: Theme.label
            }
            Rectangle {
                visible: slot.available
                anchors.centerIn: parent
                width: 1.8
                height: 9
                radius: 1
                color: Theme.label
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -3
                enabled: slot.editing
                onClicked: slot.toggled()
            }
        }
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
