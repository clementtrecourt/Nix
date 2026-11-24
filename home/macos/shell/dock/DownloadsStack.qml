import QtQuick
import QtQuick.Shapes
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets
import qs.common

// Pile « Downloads » en grille (Tahoe), relevée sur une capture 9to5Mac de
// macOS 26 (pile « Applications » en grille, 2x) :
//  - grande plaque Liquid Glass claire (le fond reste bien visible), rayon
//    ~18 pt, petite pointe arrondie centrée sur l'icône du Dock, à ~10 pt
//    au-dessus de la plaque du Dock ;
//  - titre centré en haut (13 pt, normal), filet pleine largeur dessous ;
//  - grandes icônes (squircle ≈ 1,86 x celui du Dock) et nom sur une ligne,
//    élidé au milieu (« OldTweet…kChrome ») ; plus récents d'abord ;
//  - filet au-dessus du pied, puis « Open in Finder ».
// Pendant que la pile est ouverte, sa tuile du Dock devient un carré de verre
// avec un chevron (voir DockTile).
Scope {
    id: root

    required property var dockWindow
    required property var dock
    property string folder: ""
    property bool open: false
    property real anchorX: 0
    property bool grab: true

    readonly property var screen: dockWindow.screen
    readonly property real screenW: screen?.width ?? 0
    readonly property real screenH: screen?.height ?? 0

    function toggleFor(t) {
        if (open) { close(); return; }
        anchorX = t.x + t.width / 2;
        refreshCount();
        grid.positionViewAtBeginning();
        popup.anchor.updateAnchor();
        open = true;
    }
    function close() { open = false; grab = true; }
    function debugInfo() { return files.count + " status=" + files.status + " folder=" + files.folder + " cols=" + cols; }

    // FolderListModel ne notifie pas toujours `count` (chargement par lots dans un
    // fil séparé) : nombre de fichiers relu sur les signaux du modèle et à l'ouverture.
    property int fileCount: 0
    function refreshCount() { fileCount = files.count; }
    Connections {
        target: files
        function onRowsInserted() { root.refreshCount(); }
        function onRowsRemoved() { root.refreshCount(); }
        function onModelReset() { root.refreshCount(); }
        function onStatusChanged() { root.refreshCount(); }
    }

    // ---- Géométrie (pt) ----
    // Cellule et icône proportionnelles à la toile du Dock (48 pt -> 114 / 88)
    readonly property int cellW: Math.round(dock.canvas * 2.38)
    readonly property int cellH: Math.round(dock.canvas * 2.38)
    readonly property int iconBox: Math.round(dock.canvas * 1.84)
    readonly property int headerH: 30
    readonly property int footerH: 34
    readonly property int sidePad: 14
    readonly property int radius: 18
    readonly property int tailW: 18
    readonly property int tailH: 9
    // Colonnes : grille presque carrée, 3 à 7 colonnes, dans la largeur de l'écran
    readonly property int cols: Math.max(1, Math.min(Math.floor((screenW - 80) / cellW),
                                                     Math.min(7, Math.max(3, Math.ceil(Math.sqrt(fileCount * 1.3))))))
    // Lignes visibles : au plus ce qui tient entre la barre de menus et le Dock
    readonly property int maxRows: Math.max(1, Math.floor((screenH - Theme.menuBarHeight - dockWindow.height + dock.platterTop - 10 - 40 - headerH - footerH - tailH) / cellH))
    readonly property int rows: Math.max(1, Math.min(maxRows, Math.ceil(fileCount / cols)))

    readonly property real plateW: cols * cellW + 2 * sidePad
    readonly property real plateH: headerH + rows * cellH + footerH
    readonly property int margin: 24

    // ---- Position sur l'écran (repère de la capture du verre) ----
    readonly property real popupW: plateW + 2 * margin
    readonly property real popupH: plateH + tailH + 2 * margin
    readonly property real dockY: screenH - dockWindow.height
    readonly property real popupX: Math.max(0, Math.min(screenW - popupW, Math.round(anchorX + 0.5 - popupW / 2)))
    readonly property real popupY: dockY + popup.anchor.rect.y - popupH
    // Abscisse de la pointe dans la plaque (suit l'icône si la plaque a glissé)
    readonly property real tailX: Math.max(radius + tailW / 2, Math.min(plateW - radius - tailW / 2, anchorX - popupX - margin))

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
            dmg: "application-x-apple-diskimage",
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
        // Visible dès que la capture du fond est arrivée (~50 ms)
        visible: stackBackdrop.pass
        color: "transparent"
        grabFocus: root.grab
        anchor.window: root.dockWindow
        anchor.rect.x: root.anchorX
        // Pointe à 10 pt au-dessus de la plaque du Dock
        anchor.rect.y: root.dock.platterTop - 10 + root.margin
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.adjustment: PopupAdjustment.Slide
        implicitWidth: root.popupW
        implicitHeight: root.popupH
        mask: Region { item: plate }
        // Fermée par le compositeur (clic hors de la pile)
        onVisibleChanged: if (!visible && root.open) root.close()

        property Item glassBackdrop: stackBackdrop
        GlassBackdrop {
            id: stackBackdrop
            mode: "snapshot"
            screen: root.screen
            want: root.open
            origin: Qt.point(root.popupX, root.popupY)
        }

        // Voile du verre : clair et transparent (le fond reste lisible)
        readonly property color veil: Theme.dark ? Qt.rgba(0.13, 0.13, 0.14, 0.50) : Qt.rgba(1, 1, 1, 0.36)
        readonly property color rim: Theme.dark ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.75)

        Item {
            id: plate
            x: root.margin
            y: root.margin
            width: root.plateW
            height: root.plateH

            // Repli sans réfraction : voile simple (flou Hyprland)
            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: Theme.menuBackground
                visible: !glass.refracting
            }
            Glass {
                id: glass
                anchors.fill: parent
                radius: root.radius
                tint: "transparent"
                overlay: refracting ? popup.veil : "transparent"
                rimColor: popup.rim
                shadowBlur: 0.9
                shadowOffset: 6
            }

            // ---- Pointe : triangle arrondi sous la plaque, liseré sur ses flancs.
            // Elle n'est pas réfractante (9 pt de haut) : voile du verre posé
            // directement sur le fond (la surface n'est pas floutée par Hyprland),
            // un peu plus dense pour rejoindre la teinte de la plaque.
            Shape {
                x: root.tailX - root.tailW / 2
                y: root.plateH - 2
                width: root.tailW
                height: root.tailH + 2
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: glass.refracting ? Qt.rgba(popup.veil.r, popup.veil.g, popup.veil.b, Math.min(1, popup.veil.a + 0.12))
                                                : Theme.menuBackground
                    strokeColor: "transparent"
                    startX: 0; startY: 2
                    PathLine { x: root.tailW; y: 2 }
                    PathQuad { x: root.tailW / 2 + 1.6; y: root.tailH + 1.2; controlX: root.tailW / 2 + 3; controlY: 4.5 }
                    PathQuad { x: root.tailW / 2 - 1.6; y: root.tailH + 1.2; controlX: root.tailW / 2; controlY: root.tailH + 2.6 }
                    PathQuad { x: 0; y: 2; controlX: root.tailW / 2 - 3; controlY: 4.5 }
                }
            }
            // Liseré des flancs de la pointe
            Shape {
                x: root.tailX - root.tailW / 2
                y: root.plateH - 2
                width: root.tailW
                height: root.tailH + 2
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: popup.rim
                    strokeWidth: 1
                    capStyle: ShapePath.RoundCap
                    startX: -1.5; startY: 2
                    PathQuad { x: root.tailW / 2 - 1.6; y: root.tailH + 1.2; controlX: root.tailW / 2 - 3; controlY: 4.5 }
                    PathQuad { x: root.tailW / 2 + 1.6; y: root.tailH + 1.2; controlX: root.tailW / 2; controlY: root.tailH + 2.6 }
                    PathQuad { x: root.tailW + 1.5; y: 2; controlX: root.tailW / 2 + 3; controlY: 4.5 }
                }
            }

            // ---- En-tête : nom du dossier, filet ----
            Text {
                id: header
                width: parent.width
                height: root.headerH
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "Downloads"
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.label
            }
            Rectangle {
                y: root.headerH - 1
                x: 1
                width: parent.width - 2
                height: 1
                color: Theme.separator
            }

            GridView {
                id: grid
                x: root.sidePad
                y: root.headerH
                width: root.cols * root.cellW
                height: root.rows * root.cellH
                cellWidth: root.cellW
                cellHeight: root.cellH
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: files

                delegate: Item {
                    id: cellItem
                    required property string fileName
                    required property string filePath
                    required property bool fileIsDir
                    width: root.cellW
                    height: root.cellH

                    // Survol : pastille discrète derrière l'icône
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: thumb.y - 4
                        width: root.iconBox + 8
                        height: root.iconBox + 8
                        radius: 12
                        color: Theme.fill
                        visible: hov.containsMouse
                    }
                    Item {
                        id: thumb
                        width: root.iconBox
                        height: root.iconBox
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 6
                        // Image : miniature ; autre fichier : icône du thème
                        Image {
                            anchors.centerIn: parent
                            width: parent.width * 0.82
                            height: width
                            visible: root.isImage(cellItem.fileName)
                            source: visible ? "file://" + cellItem.filePath : ""
                            sourceSize: Qt.size(root.iconBox * 2, root.iconBox * 2)
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
                        anchors.topMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.cellW - 8
                        horizontalAlignment: Text.AlignHCenter
                        text: cellItem.fileName
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: Theme.label
                    }
                    MouseArea {
                        id: hov
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.close();
                            // Dossier : Finder ; fichier : app par défaut
                            if (cellItem.fileIsDir) root.dock.model.openPath(cellItem.filePath);
                            else root.dock.model.openFile(cellItem.filePath);
                        }
                    }
                }
            }

            // ---- Pied : filet, « Open in Finder » ----
            Rectangle {
                y: root.plateH - root.footerH
                x: 1
                width: parent.width - 2
                height: 1
                color: Theme.separator
            }
            Text {
                id: openLabel
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.plateH - root.footerH + (root.footerH - height) / 2
                text: "Open in Finder"
                font.family: Theme.font
                font.pixelSize: 13
                color: openHov.containsMouse ? Theme.accent : Theme.label
                MouseArea {
                    id: openHov
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    onClicked: { root.close(); root.dock.model.openPath(root.folder); }
                }
            }
        }
    }
}
