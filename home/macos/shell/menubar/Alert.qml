import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.common

// Alerte de confirmation façon Tahoe (NSAlert) : icône de l'app, titre en gras,
// message en petit, deux boutons capsule côte à côte (le bouton par défaut en
// bleu). Utilisée par Finder > « Vider la corbeille… ». Entrée = confirmer,
// Échap = annuler.
Scope {
    id: root

    property bool open: false
    property string title: ""
    property string message: ""
    property string confirmText: "OK"
    property string iconSource: ""
    property var onConfirm: null

    function show(opts) {
        title = opts.title ?? "";
        message = opts.message ?? "";
        confirmText = opts.confirmText ?? "OK";
        iconSource = opts.iconSource ?? "";
        onConfirm = opts.onConfirm ?? null;
        open = true;
    }
    function cancel() { open = false; }
    function confirm() {
        open = false;
        if (typeof onConfirm === "function") onConfirm();
    }

    PanelWindow {
        id: win
        // Le verre réfracte une capture de l'écran prise juste avant l'ouverture
        property Item glassBackdrop: backdrop
        GlassBackdrop {
            id: backdrop
            mode: "snapshot"
            screen: win.screen
            want: root.open
        }
        visible: backdrop.pass
        color: "transparent"
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

        readonly property int pad: 40
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "macos-lg-alert"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        anchors.top: true
        margins.top: Math.round((screen?.height ?? 982) * 0.24 - pad)
        implicitWidth: card.width + 2 * pad
        implicitHeight: card.height + 2 * pad
        mask: Region { item: card }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) { root.cancel(); event.accepted = true; }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.confirm(); event.accepted = true; }
            }
        }

        Rectangle {
            anchors.fill: card
            radius: card.radius
            color: Theme.glassThick
            antialiasing: true
            visible: !card.refracting
        }
        Glass {
            id: card
            x: win.pad
            y: win.pad
            width: 260
            height: col.implicitHeight + 40
            radius: 24
            tint: "transparent"
            // Avec réfraction, le verre est opaque : la teinte devient son voile
            overlay: refracting ? Theme.glassThick : "transparent"

            MouseArea { anchors.fill: parent }

            Column {
                id: col
                x: 20
                y: 20
                width: parent.width - 40
                spacing: 10

                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.iconSource !== ""
                    implicitSize: 64
                    source: root.iconSource
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.title
                    font.family: Theme.font
                    renderType: Text.NativeRendering
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: Theme.label
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: text !== ""
                    text: root.message
                    font.family: Theme.font
                    renderType: Text.NativeRendering
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.label
                }
                Item { width: 1; height: 4 }
                // Boutons côte à côte s'ils tiennent, sinon empilés (bouton par
                // défaut en haut), comme les alertes de Tahoe
                Grid {
                    id: buttons
                    readonly property bool stacked: Math.max(cancelBtn.textWidth, okBtn.textWidth) + 24 > (col.width - 8) / 2
                    width: parent.width
                    columns: stacked ? 1 : 2
                    spacing: 8
                    layoutDirection: Qt.LeftToRight
                    AlertButton {
                        id: okBtn
                        visible: buttons.stacked
                        width: buttons.stacked ? col.width : (col.width - 8) / 2
                        text: root.confirmText; primary: true; onClicked: root.confirm()
                    }
                    AlertButton {
                        id: cancelBtn
                        width: buttons.stacked ? col.width : (col.width - 8) / 2
                        text: "Cancel"; onClicked: root.cancel()
                    }
                    AlertButton {
                        visible: !buttons.stacked
                        width: (col.width - 8) / 2
                        text: root.confirmText; primary: true; onClicked: root.confirm()
                    }
                }
            }
        }
    }

    component AlertButton: Rectangle {
        id: btn
        property string text
        property bool primary: false
        readonly property real textWidth: label.implicitWidth
        signal clicked()
        height: 28
        radius: height / 2
        color: primary ? Theme.accent : Theme.fillHover
        opacity: area.pressed ? 0.8 : 1
        Text {
            id: label
            anchors.centerIn: parent
            width: parent.width - 12
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: btn.text
            font.family: Theme.font
            renderType: Text.NativeRendering
            font.pixelSize: Theme.fontSize
            font.weight: btn.primary ? Font.Medium : Font.Normal
            color: btn.primary ? "white" : Theme.label
        }
        MouseArea {
            id: area
            anchors.fill: parent
            onClicked: btn.clicked()
        }
    }
}
