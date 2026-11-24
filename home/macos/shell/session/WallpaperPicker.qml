import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.services

// Sélecteur de fond d'écran (menu du bureau « Change Wallpaper… » ou
// ShellState "wallpaper") : aperçu courant en haut, puis vignettes arrondies
// par section comme Réglages > Fond d'écran. Sélection = anneau accent.
Scope {
    id: root

    property bool shown: false

    Connections {
        target: ShellState
        function onOpenPanelChanged() {
            if (ShellState.openPanel === "wallpaper") {
                ShellState.close();
                WallpaperService.scanImages();
                root.shown = true;
            }
        }
    }

    function baseName(p) {
        const n = (p ?? "").split("/").pop();
        const i = n.lastIndexOf(".");
        return i > 0 ? n.slice(0, i) : n;
    }

    TahoeWindow {
        id: win
        shown: root.shown
        title: "Wallpaper"
        cardWidth: 660
        cardHeight: 520
        minimizeEnabled: true
        onCloseRequested: root.shown = false
        onMinimizeRequested: root.shown = false

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.shown = false

            // ---- Aperçu courant ----
            Rectangle {
                id: header
                x: 20
                y: 4
                width: parent.width - 40
                height: 112
                radius: 12
                color: Theme.fill

                ClippingRectangle {
                    id: preview
                    x: 10
                    y: 10
                    width: 148
                    height: 92
                    radius: 7
                    color: "black"
                    WallpaperView {
                        anchors.fill: parent
                        decodeSize: Qt.size(320, 200)
                    }
                }
                Column {
                    anchors.left: preview.right
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        text: WallpaperService.source === "" ? "Tahoe" : root.baseName(WallpaperService.realPath)
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.label
                    }
                    Text {
                        text: WallpaperService.source === ""
                            ? "Dynamic Wallpaper · light or dark with your appearance"
                            : WallpaperService.realPath
                        width: header.width - preview.width - 52
                        elide: Text.ElideMiddle
                        font.family: Theme.font
                        font.pixelSize: 11
                        color: Theme.labelSecondary
                    }
                }
            }

            Flickable {
                id: flick
                anchors.top: header.bottom
                anchors.topMargin: 14
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                contentHeight: sections.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: sections
                    x: 20
                    width: flick.width - 40
                    spacing: 8

                    Text {
                        text: "Dynamic Wallpapers"
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Theme.label
                    }
                    Flow {
                        width: parent.width
                        spacing: 12
                        Thumb {
                            label: "Tahoe"
                            selected: WallpaperService.source === ""
                            onPicked: WallpaperService.set("")
                            TahoeWallpaper { anchors.fill: parent }
                        }
                    }

                    Item { width: 1; height: 6 }
                    Text {
                        text: "Your Photos"
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Theme.label
                    }
                    Text {
                        visible: WallpaperService.images.length === 0
                        text: "Add images to ~/Pictures/Wallpapers or ~/.config/macos-shell/wallpapers to see them here."
                        font.family: Theme.font
                        font.pixelSize: 11
                        color: Theme.labelSecondary
                    }
                    Flow {
                        width: parent.width
                        spacing: 12
                        Repeater {
                            model: WallpaperService.images
                            Thumb {
                                id: photo
                                required property string modelData
                                label: root.baseName(modelData)
                                selected: WallpaperService.realPath === modelData
                                onPicked: WallpaperService.set(modelData)
                                Image {
                                    anchors.fill: parent
                                    source: "file://" + photo.modelData
                                    sourceSize: Qt.size(240, 150)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Vignette 112x70 aux coins de 8 px, anneau accent si sélectionnée
    component Thumb: Item {
        id: thumb
        property string label
        property bool selected
        default property alias art: clip.data
        signal picked()
        width: 112
        height: 70 + 20

        Rectangle {
            x: -3
            y: -3
            width: 118
            height: 76
            radius: 11
            color: "transparent"
            border.width: 3
            border.color: Theme.accent
            visible: thumb.selected
        }
        ClippingRectangle {
            id: clip
            width: 112
            height: 70
            radius: 8
            color: Theme.fill
        }
        Text {
            y: 74
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: thumb.label
            font.family: Theme.font
            font.pixelSize: 11
            color: Theme.labelSecondary
        }
        MouseArea {
            anchors.fill: parent
            onClicked: thumb.picked()
        }
    }
}
