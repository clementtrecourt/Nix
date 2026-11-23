import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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
    readonly property int edgeMargin: 10
    readonly property int leftRoom: 24
    readonly property int topGap: 8

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

    mask: Region { item: maskItem }
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
                spacing: 12
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
                Row {
                    spacing: 16
                    WidgetCalendar { today: clockTick.now }
                    WidgetClock { running: win.visible }
                }
                WidgetUpNext {}
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
