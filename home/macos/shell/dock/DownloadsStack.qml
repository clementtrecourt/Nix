import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets
import qs.common

// Pile « Téléchargements » affichée en grille (Tahoe : présentation Grille) :
// plaque de verre au-dessus de l'icône avec petite pointe, fichiers les plus
// récents d'abord (miniatures pour les images), bouton « Ouvrir dans le Finder ».
Scope {
    id: root

    required property var dockWindow
    required property var dock
    property string folder: ""
    property bool open: false
    property real anchorX: 0
    property bool grab: true

    function toggleFor(t) {
        if (open) { close(); return; }
        anchorX = t.x + t.width / 2;
        popup.anchor.updateAnchor();
        open = true;
    }
    function close() { open = false; grab = true; }

    readonly property int cols: Math.min(5, Math.max(3, Math.ceil(Math.sqrt(files.count))))
    readonly property int cell: 88
    readonly property int maxRows: 4

    FolderListModel {
        id: files
        folder: root.folder ? "file://" + root.folder : ""
        showDirs: true
        showDirsFirst: false
        showHidden: false
        sortField: FolderListModel.Time
        sortReversed: false
        nameFilters: ["*"]
    }

    // Icône du thème d'après l'extension (pas de base MIME côté QML)
    function iconFor(name, isDir) {
        if (isDir) return Quickshell.iconPath("folder", "folder");
        const ext = (name.split(".").pop() || "").toLowerCase();
        const map = {
            pdf: "application-pdf", zip: "application-zip", gz: "application-x-compressed-tar",
            xz: "application-x-compressed-tar", tar: "application-x-tar", "7z": "application-x-7z-compressed",
            json: "application-json", txt: "text-plain", md: "text-markdown", html: "text-html",
            wav: "audio-x-wav", mp3: "audio-mpeg", flac: "audio-flac", ogg: "audio-x-vorbis+ogg",
            mp4: "video-mp4", mkv: "video-x-matroska", webm: "video-webm", mov: "video-quicktime",
            iso: "application-x-cd-image", deb: "application-x-deb", rpm: "application-x-rpm",
            doc: "x-office-document", docx: "x-office-document", odt: "x-office-document",
            xls: "x-office-spreadsheet", xlsx: "x-office-spreadsheet", ods: "x-office-spreadsheet",
            ppt: "x-office-presentation", pptx: "x-office-presentation", odp: "x-office-presentation",
            py: "text-x-python", js: "text-x-javascript", sh: "application-x-shellscript",
            nix: "text-x-nix", safetensors: "application-octet-stream"
        };
        return Quickshell.iconPath(map[ext] ?? "text-x-generic", "text-x-generic");
    }
    function isImage(name) {
        return /\.(png|jpe?g|gif|webp|bmp|svg|avif)$/i.test(name);
    }

    PopupWindow {
        id: popup
        visible: root.open
        color: "transparent"
        grabFocus: root.grab
        anchor.window: root.dockWindow
        anchor.rect.x: root.anchorX
        anchor.rect.y: root.dock.platterTop - 4 + body.margin
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        implicitWidth: body.width
        implicitHeight: body.height
        mask: Region { item: plate }
        onVisibleChanged: if (!visible && root.open) root.close()

        Item {
            id: body
            readonly property int margin: 24
            readonly property int tail: 9
            width: plate.width + 2 * margin
            height: plate.height + tail + 2 * margin

            Item {
                id: plate
                x: body.margin
                y: body.margin
                width: root.cols * root.cell + 24
                height: header.height + grid.height + footer.height + 8

                Glass {
                    anchors.fill: parent
                    radius: 22
                    tint: Theme.menuBackground
                    shadowBlur: 0.9
                    shadowOffset: 8
                }

                Text {
                    id: header
                    width: parent.width
                    height: 36
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "Téléchargements"
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.label
                }

                GridView {
                    id: grid
                    x: 12
                    y: header.height
                    width: root.cols * root.cell
                    height: Math.max(1, Math.min(root.maxRows, Math.ceil(files.count / root.cols))) * (root.cell + 8)
                    cellWidth: root.cell
                    cellHeight: root.cell + 8
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: files

                    delegate: Item {
                        id: cellItem
                        required property string fileName
                        required property string filePath
                        required property bool fileIsDir
                        width: root.cell
                        height: root.cell + 8

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 10
                            color: Theme.fillHover
                            visible: hov.containsMouse
                        }
                        Item {
                            id: thumb
                            width: 52
                            height: 52
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 6
                            Image {
                                anchors.fill: parent
                                visible: root.isImage(cellItem.fileName)
                                source: visible ? "file://" + cellItem.filePath : ""
                                sourceSize: Qt.size(104, 104)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                            IconImage {
                                anchors.fill: parent
                                visible: !root.isImage(cellItem.fileName)
                                source: root.iconFor(cellItem.fileName, cellItem.fileIsDir)
                            }
                        }
                        Text {
                            anchors.top: thumb.bottom
                            anchors.topMargin: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.cell - 8
                            horizontalAlignment: Text.AlignHCenter
                            text: cellItem.fileName
                            elide: Text.ElideMiddle
                            maximumLineCount: 2
                            wrapMode: Text.WrapAnywhere
                            font.family: Theme.font
                            font.pixelSize: 11
                            color: Theme.label
                        }
                        MouseArea {
                            id: hov
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.close();
                                Quickshell.execDetached(["xdg-open", cellItem.filePath]);
                            }
                        }
                    }
                }

                Item {
                    id: footer
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 40
                    Rectangle {
                        anchors.top: parent.top
                        x: 12
                        width: parent.width - 24
                        height: 1
                        color: Theme.separator
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: openLabel.implicitWidth + 24
                        height: 24
                        radius: 12
                        color: openHov.containsMouse ? Theme.fillHover : Theme.fill
                        Text {
                            id: openLabel
                            anchors.centerIn: parent
                            text: "Ouvrir dans le Finder"
                            font.family: Theme.font
                            font.pixelSize: 12
                            color: Theme.label
                        }
                        MouseArea {
                            id: openHov
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { root.close(); Quickshell.execDetached(["xdg-open", root.folder]); }
                        }
                    }
                }
            }

            // Pointe vers l'icône du Dock
            Canvas {
                id: tailShape
                width: 22
                height: body.tail + 1
                x: body.width / 2 - width / 2
                y: plate.y + plate.height - 1
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    c.fillStyle = Theme.menuBackground;
                    c.beginPath();
                    c.moveTo(0, 0);
                    c.quadraticCurveTo(width / 2 - 3, 1, width / 2, height - 1);
                    c.quadraticCurveTo(width / 2 + 3, 1, width, 0);
                    c.closePath();
                    c.fill();
                }
            }
        }
    }
}
