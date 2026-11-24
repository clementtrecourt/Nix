import QtQuick
import Quickshell
import qs.common
import qs.finder as Finder

// Fenêtre de Réglages Système (macOS Tahoe 26) : fenêtre normale gérée par
// Hyprland (classe org.quickshell, sans barre du compositeur, coins de 26 pt
// par la windowrule commune), largeur fixe de 715 pt.
//
// Couches : stage (fond + panneau défilant, réfracté par les verres) ->
// fondu de bord sous la barre de titre -> barre latérale de verre ->
// capsule ‹ › + titre -> feuilles et menus.
FloatingWindow {
    id: win

    title: "System Settings"
    color: SStyle.contentBg
    implicitWidth: SStyle.windowWidth
    implicitHeight: SStyle.windowHeight
    minimumSize: Qt.size(SStyle.windowWidth, SStyle.minHeight)
    maximumSize: Qt.size(SStyle.windowWidth, 4000)

    readonly property bool active: stage.Window.active
    readonly property real contentX: SStyle.sidebarInset + SStyle.sidebarWidth
    readonly property alias paneItem: paneLoader.item
    readonly property alias flick: flick

    function closeWindow() { Nav.close(); }
    function minimizeWindow() {
        Quickshell.execDetached(["sh", "-c", "macos-wm minimize 2>/dev/null || hyprctl dispatch movetoworkspacesilent special:minimized"]);
    }
    function zoomWindow(full) {
        Quickshell.execDetached(["sh", "-c", full ? "macos-wm fullscreen 2>/dev/null || hyprctl dispatch fullscreen 0" : "hyprctl dispatch fullscreen 1"]);
    }
    function focusContent() { stage.forceActiveFocus(); }
    onVisibleChanged: if (!visible) Nav.close()

    // ---- Menus (pop-up buttons, ellipses) ----
    Finder.FinderMenu { id: menu }
    function showMenu(pos, items, noGrab) { menu.show(win, pos, items, noGrab); }
    function closeMenu() { menu.close(); }

    // Remonte la fenêtre (déjà ouverte) au premier plan
    Connections {
        target: Nav
        function onRaiseRequested() {
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "title:^(System Settings)$"]);
        }
        function onPaneChanged() { flick.contentY = 0; }
    }

    // ------------------------------------------------------------ contenu
    Item {
        id: stage
        anchors.fill: parent
        focus: true
        property bool ready: true

        Keys.onPressed: (e) => {
            const cmd = e.modifiers & (Qt.ControlModifier | Qt.MetaModifier);
            if (cmd && e.key === Qt.Key_F) { sidebar.focusSearch(); e.accepted = true; }
            else if (cmd && (e.key === Qt.Key_W || e.key === Qt.Key_Q)) { Nav.close(); e.accepted = true; }
            else if (cmd && e.key === Qt.Key_BracketLeft || (e.modifiers & Qt.AltModifier) && e.key === Qt.Key_Left) { Nav.back(); e.accepted = true; }
            else if (cmd && e.key === Qt.Key_BracketRight || (e.modifiers & Qt.AltModifier) && e.key === Qt.Key_Right) { Nav.forward(); e.accepted = true; }
        }

        Rectangle { anchors.fill: parent; color: SStyle.contentBg }

        Flickable {
            id: flick
            x: win.contentX
            width: parent.width - x
            height: parent.height
            contentHeight: paneLoader.y + (paneLoader.item ? paneLoader.item.implicitHeight : 0) + 24
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Loader {
                id: paneLoader
                x: SStyle.contentSide
                y: SStyle.contentTop
                width: flick.width - 2 * SStyle.contentSide
                readonly property var spec: Nav.info(Nav.pane)
                source: spec ? Qt.resolvedUrl("Pane" + spec.file + ".qml") : ""
                onLoaded: {
                    if (item.sw !== undefined) item.sw = win;
                    if (item.paneId !== undefined) item.paneId = Nav.pane;
                    item.width = Qt.binding(() => paneLoader.width);
                }
            }
        }
        Finder.OverlayScrollbar {
            flick: flick
            anchors.right: parent.right
            y: 52
            height: parent.height - 56
        }
    }

    // Fondu de bord sous la barre de titre (le contenu s'estompe en défilant)
    Rectangle {
        x: win.contentX
        width: parent.width - x
        height: 56
        opacity: Math.min(1, flick.contentY / 24)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(SStyle.contentBg.r, SStyle.contentBg.g, SStyle.contentBg.b, 0.95) }
            GradientStop { position: 0.6; color: Qt.rgba(SStyle.contentBg.r, SStyle.contentBg.g, SStyle.contentBg.b, 0.7) }
            GradientStop { position: 1.0; color: Qt.rgba(SStyle.contentBg.r, SStyle.contentBg.g, SStyle.contentBg.b, 0) }
        }
    }

    // Glisser la fenêtre par la barre de titre ; double-clic = Zoom
    MouseArea {
        x: win.contentX
        width: parent.width - x
        height: 50
        onPressed: win.startSystemMove()
        onDoubleClicked: win.zoomWindow(false)
    }

    Sidebar {
        id: sidebar
        sw: win
        x: SStyle.sidebarInset
        y: SStyle.sidebarInset
        width: SStyle.sidebarWidth
        height: parent.height - 2 * SStyle.sidebarInset
        backdropItem: stage
    }

    // ---- Barre de titre : ‹ › et titre du panneau ----
    Finder.ToolCapsule {
        id: nav
        x: win.contentX + SStyle.capsuleGap
        y: SStyle.titleCenterY - height / 2 + 1
        backdropItem: stage
        Finder.ToolButton {
            symbol: "chevron.left"
            symbolSize: 15
            buttonWidth: 32
            enabledButton: Nav.backStack.length > 0
            onClicked: Nav.back()
        }
        Rectangle {
            width: 1
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            color: SStyle.separator
        }
        Finder.ToolButton {
            symbol: "chevron.right"
            symbolSize: 15
            buttonWidth: 32
            enabledButton: Nav.fwdStack.length > 0
            onClicked: Nav.forward()
        }
    }
    Text {
        x: nav.x + nav.width + 12
        width: parent.width - x - 20
        y: Math.round(nav.y + nav.height / 2 - height / 2)
        text: Nav.title(Nav.pane)
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: SStyle.titleSize
        font.weight: Font.Bold
        color: win.active ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.86) : Qt.rgba(0, 0, 0, 0.78))
                          : (Theme.dark ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(0, 0, 0, 0.35))
    }

    // Couche des feuilles modales (SSheet), au-dessus de tout le reste
    readonly property Item overlay: overlayItem
    Item {
        id: overlayItem
        anchors.fill: parent
        z: 100
    }

    Component.onCompleted: { Nav.window = win; stage.forceActiveFocus(); }
    Component.onDestruction: if (Nav.window === win) Nav.window = null
}
