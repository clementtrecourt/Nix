import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.session as Session

// Wallpaper (Tahoe 26, Apple mchlp3013, 1,61 px/pt) : aperçu du fond courant
// (157 × 98 pt), groupe « Tahoe | Light ⌃⌄ » et « Show on all Spaces »,
// boutons Screen Saver… / Clock Appearance…, trait, puis Dynamic Wallpapers
// (fond procédural Tahoe en direct), Your Photos (images trouvées + Add
// Photo…), vignettes de 106 × 65 pt au pas de 115 pt, libellé dessous.
// Piloté par session/WallpaperService.
PaneBase {
    id: root

    readonly property string current: Session.WallpaperService.realPath
    Component.onCompleted: { Session.WallpaperService.scanImages(); sniff.run(); }
    // Images réellement décodables (signature JPEG / PNG) : un .jpg qui est en
    // fait du WebP / AVIF n'est pas proposé (pas d'erreur de décodage)
    property var photos: []
    readonly property var _all: Session.WallpaperService.images
    on_AllChanged: sniff.run()
    ProcessText {
        id: sniff
        function run() {
            if (!root._all.length) { root.photos = []; return; }
            command = ["sh", "-c", 'for f; do h=$(head -c 4 "$f" 2>/dev/null | od -An -tx1 | tr -d " \\n"); case "$h" in ffd8ff*|89504e47) printf "%s\\n" "$f";; esac; done', "sh"].concat(root._all);
            running = true;
        }
        onDone: (t) => root.photos = t.split("\n").filter(l => l.length > 0)
    }
    ProcessText {
        id: chooser
        onDone: (t) => { const p = t.trim(); if (p) Session.WallpaperService.set(p); Session.WallpaperService.scanImages(); }
    }
    function addPhoto() {
        chooser.command = ["sh", "-c", "command -v zenity >/dev/null || exit 3; zenity --file-selection --title='Choose a Photo' --file-filter='Images | *.jpg *.jpeg *.png *.webp *.JPG *.PNG'"];
        chooser.running = true;
    }

    component Thumb: Item {
        id: th
        property string label
        property bool selected
        default property alias art: artBox.data
        signal picked()
        width: 106
        height: 65 + 24
        Rectangle {
            x: -3; y: -3
            width: 112; height: 71
            radius: 9
            color: "transparent"
            border.width: 3
            border.color: SStyle.accent
            visible: th.selected
        }
        ClippingRectangle {
            id: artBox
            width: 106
            height: 65
            radius: 6
            color: SStyle.groupFill
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 71
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            text: th.label
            font.family: Theme.font
            font.pixelSize: SStyle.small
            color: SStyle.label
        }
        MouseArea { anchors.fill: parent; onClicked: th.picked() }
    }

    // ---- En-tête ----
    Item {
        width: parent.width
        height: 140
        ClippingRectangle {
            id: preview
            y: 6
            width: 157
            height: 98
            radius: 8
            color: "#000"
            Session.WallpaperView { anchors.fill: parent; decodeSize: Qt.size(320, 200) }
        }
        SGroup {
            id: hg
            x: preview.width + 12
            y: 0
            width: parent.width - x
            SRow {
                title: root.current ? root.current.split("/").pop().replace(/\.[^.]+$/, "") : "Tahoe"
                SPopUp {
                    visible: !root.current
                    options: [{ text: "Automatic", value: "auto" }, { text: "Light", value: "light" }, { text: "Dark", value: "dark" }]
                    value: "auto"
                    enabledPopUp: false
                }
                SPopUp {
                    visible: !!root.current
                    options: [{ text: "Fill Screen", value: "fill" }, { text: "Fit to Screen", value: "fit", enabled: false }, { text: "Stretch to Fill Screen", value: "stretch", enabled: false }, { text: "Center", value: "center", enabled: false }]
                    value: "fill"
                }
            }
            SRow {
                title: "Show on all Spaces"
                SSwitch { checked: true; enabledSwitch: false }
            }
        }
        Row {
            anchors.right: parent.right
            y: hg.height + 10
            spacing: 8
            SButton { text: "Screen Saver…"; onClicked: Nav.go("lockscreen") }
            SButton { text: "Clock Appearance…"; enabledButton: false }
        }
    }
    Rectangle { x: -SStyle.contentSide; width: parent.width + 2 * SStyle.contentSide; height: 1; color: SStyle.separator }

    SSection { text: "Dynamic Wallpapers"; detail: "Show All (1)" }
    Flow {
        width: parent.width
        spacing: 9
        Thumb {
            label: "Tahoe"
            selected: !root.current
            onPicked: Session.WallpaperService.set("")
            Session.TahoeWallpaper { anchors.fill: parent }
        }
    }

    SSection { text: "Your Photos"; detail: root.photos.length ? "Show All (" + root.photos.length + ")" : "" }
    Flow {
        width: parent.width
        spacing: 9
        Repeater {
            model: root.photos
            Thumb {
                required property string modelData
                label: modelData.split("/").pop().replace(/\.[^.]+$/, "")
                selected: root.current === modelData
                onPicked: Session.WallpaperService.set(modelData)
                Image {
                    anchors.fill: parent
                    source: "file://" + modelData
                    sourceSize: Qt.size(212, 130)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
        }
        Thumb {
            label: ""
            onPicked: root.addPhoto()
            Column {
                anchors.centerIn: parent
                spacing: 4
                Symbol { anchors.horizontalCenter: parent.horizontalCenter; name: "photo"; size: 22; color: SStyle.secondary }
                Text { text: "Add Photo…"; font.family: Theme.font; font.pixelSize: SStyle.small; color: SStyle.secondary }
            }
        }
    }

    SSection { text: "Colors" }
    Flow {
        width: parent.width
        spacing: 9
        Repeater {
            model: ["#1C2C5B", "#3A6EA5", "#5A9E6F", "#C2A04E", "#B5553C", "#7C4D8C", "#4A4A4C", "#D7D7DA"]
            Thumb {
                required property string modelData
                label: ""
                selected: root.current.endsWith("/color-" + modelData.slice(1) + ".ppm")
                onPicked: {
                    const dir = (Quickshell.env("HOME") ?? "") + "/.config/macos-shell/wallpapers";
                    const f = dir + "/color-" + modelData.slice(1) + ".ppm";
                    // Image unie au format PPM (aucun outil externe nécessaire)
                    const h = modelData.slice(1);
                    const px = "\\x" + h.slice(0, 2) + "\\x" + h.slice(2, 4) + "\\x" + h.slice(4, 6);
                    maker.command = ["bash", "-c", 'mkdir -p "$1" && { printf "P6\\n16 16\\n255\\n"; for i in $(seq 256); do printf "$3"; done; } > "$2"', "bash", dir, f, px];
                    maker.target = f;
                    maker.running = true;
                }
                Rectangle { anchors.fill: parent; color: modelData }
            }
        }
    }
    ProcessText {
        id: maker
        property string target
        onExited: (code) => { if (code === 0) Session.WallpaperService.set(target); }
    }
}
