import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Coup d'œil (Quick Look, barre d'espace) : fenêtre d'aperçu de Tahoe. Barre
// de titre grise avec boutons ronds Fermer / Plein écran, nom du fichier en
// gras, boutons d'outils et capsule « Open with <App> » (capture Apple
// mh14119). Aperçus : images, texte / code, PDF (pdftoppm), vidéos (vignette
// ffmpegthumbnailer), sinon grande icône + nom + type + taille + date.
// Espace / Échap ferment ; ←/→ (ou ↑/↓) passent à l'élément voisin dans le
// Finder.
Scope {
    id: root

    property var finder
    property bool shown: false
    property var source: null          // fenêtre du Finder d'origine
    property var entries: []
    property int index: 0
    readonly property var entry: entries.length ? entries[Math.min(index, entries.length - 1)] : null
    readonly property string cat: entry ? Fs.category(entry) : ""

    function show(w, sel) {
        source = w;
        entries = sel;
        index = 0;
        sized = !(cat === "image" || cat === "pdf" || cat === "movie");
        shown = true;
        sizeTimer.restart();
    }
    // La fenêtre n'apparaît qu'une fois sa taille connue (proportions de
    // l'image) : Hyprland ne suit pas un changement de taille après coup
    property bool sized: false
    Timer { id: sizeTimer; interval: 700; onTriggered: root.sized = true }
    Connections {
        target: natural
        function onStatusChanged() { if (natural.status === Image.Ready || natural.status === Image.Error) root.sized = true; }
    }
    function close() {
        shown = false;
        if (source) source.focusStage();
    }
    onEntriesChanged: if (index >= entries.length) index = 0

    // ---- Texte ----
    FileView {
        id: textFile
        path: root.shown && root.entry && Fs.isText(root.entry) ? root.entry.path : ""
        printErrors: false
    }
    // ---- PDF / vidéo : rendu grand format via pdftoppm / ffmpegthumbnailer ----
    property string bigThumb: ""
    property string _bigKey: ""
    Process {
        id: render
        property string out: ""
        onExited: (code) => root.bigThumb = code === 0 ? "file://" + out + "?" + Date.now() : ""
    }
    function _renderBig() {
        bigThumb = "";
        if (!shown || !entry || (cat !== "pdf" && cat !== "movie")) return;
        const k = Qt.md5(entry.path + ":" + entry.mtime + ":ql");
        render.running = false;
        render.out = Fs.cacheDir + "/" + k + ".png";
        render.command = ["sh", "-c", `
            mkdir -p "$(dirname "$2")"
            [ -s "$2" ] && exit 0
            case "$3" in
              pdf) pdftoppm -png -singlefile -f 1 -l 1 -scale-to 1400 "$1" "\${2%.png}" ;;
              movie) if command -v ffmpegthumbnailer >/dev/null; then ffmpegthumbnailer -i "$1" -o "$2" -s 1280 -c png -q 9 >/dev/null 2>&1
                     else ffmpeg -loglevel quiet -y -ss 1 -i "$1" -frames:v 1 "$2"; fi ;;
            esac
            [ -s "$2" ]`, "sh", entry.path, render.out, cat];
        render.running = true;
    }
    onShownChanged: if (shown) { _renderBig(); _queryDefault(); }

    // Taille de la fenêtre : celle de l'image (bornée), sinon 760 x 560
    Image {
        id: natural
        visible: false
        asynchronous: true
        source: root.shown && root.entry && Fs.isImage(root.entry) ? Fs.fileUrl(root.entry.path) : (root.bigThumb || "")
        sourceSize: Qt.size(1600, 1600)
    }

    FloatingWindow {
        id: win
        visible: root.shown && root.sized
        title: root.entry ? root.entry.name : "Quick Look"
        color: Theme.dark ? "#1E1E1E" : "#FFFFFF"
        readonly property real maxW: 1100
        readonly property real maxH: 760
        readonly property bool fitsImage: natural.status === Image.Ready && (root.cat === "image" || root.bigThumb !== "")
        readonly property real ratio: fitsImage ? natural.implicitWidth / Math.max(1, natural.implicitHeight) : 1.35
        implicitWidth: fitsImage ? Math.round(Math.max(420, Math.min(maxW, (maxH - 44) * ratio, natural.implicitWidth))) : 760
        implicitHeight: fitsImage ? Math.round(Math.max(300, Math.min(maxH, implicitWidth / ratio + 44))) : 560
        minimumSize: Qt.size(320, 240)
        onVisibleChanged: if (!visible && root.shown) root.shown = false

        Item {
            id: body
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                const k = e.key;
                if (k === Qt.Key_Space || k === Qt.Key_Escape || ((e.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) && (k === Qt.Key_Y || k === Qt.Key_W))) {
                    root.close();
                    e.accepted = true;
                } else if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_Down) {
                    if (root.entries.length > 1) {
                        root.index = (root.index + (k === Qt.Key_Left || k === Qt.Key_Up ? -1 : 1) + root.entries.length) % root.entries.length;
                    } else if (root.source && root.source.viewItem()) {
                        root.source.viewItem().navigate(k, false);
                        const s = root.source.selection;
                        if (s.length) root.entries = [s[s.length - 1]];
                    }
                    e.accepted = true;
                }
            }
            Component.onCompleted: forceActiveFocus()

            // ---- Contenu ----
            Item {
                id: content
                x: 0
                y: 44
                width: parent.width
                height: parent.height - 44

                // Image (ou rendu PDF / vidéo)
                Image {
                    anchors.fill: parent
                    visible: root.cat === "image" || root.bigThumb !== ""
                    source: root.cat === "image" && root.entry ? Fs.fileUrl(root.entry.path) : root.bigThumb
                    sourceSize: Qt.size(2000, 2000)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
                // Bouton lecture sur la vignette d'une vidéo
                Rectangle {
                    visible: root.cat === "movie" && root.bigThumb !== ""
                    anchors.centerIn: parent
                    width: 64
                    height: 64
                    radius: 32
                    color: Qt.rgba(0, 0, 0, 0.45)
                    Symbol { anchors.centerIn: parent; anchors.horizontalCenterOffset: 3; name: "play.fill"; size: 28; color: "white" }
                    MouseArea { anchors.fill: parent; onClicked: Fs.open(root.entry.path) }
                }
                // Texte
                Flickable {
                    anchors.fill: parent
                    visible: root.entry && Fs.isText(root.entry) && root.cat !== "image"
                    contentHeight: txt.implicitHeight + 40
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Text {
                        id: txt
                        x: 20
                        y: 18
                        width: parent.width - 40
                        text: textFile.loaded ? textFile.text().slice(0, 200000) : ""
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        font.family: Fs.category(root.entry ?? { name: "" }) === "code" ? Theme.fontMono : Theme.font
                        font.pixelSize: 13
                        color: Theme.label
                    }
                }
                // Générique : grande icône + infos
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    visible: !!root.entry && root.cat !== "image" && root.bigThumb === "" && !Fs.isText(root.entry)
                    FileIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 256
                        entry: root.entry
                        thumbnails: false
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.entry?.name ?? ""
                        font.family: Theme.font
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        color: Theme.label
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.entry ? Fs.kindOf(root.entry) + (root.entry.isDir ? "" : " - " + Fs.formatSize(root.entry.size)) : ""
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: FStyle.secondaryText
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.entry && root.entry.mtime ? "Modified: " + Fs.formatDateMedium(root.entry.mtime) : ""
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: FStyle.secondaryText
                    }
                }
            }

            // ---- Barre de titre (verre gris) ----
            Rectangle {
                width: parent.width
                height: 44
                color: Theme.dark ? "#2C2C2E" : "#ECECEC"
                Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: FStyle.gridLine }
                MouseArea {
                    anchors.fill: parent
                    onPressed: win.startSystemMove()
                }
                Row {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Repeater {
                        model: [["xmark", () => root.close()], ["arrow.up.left.and.arrow.down.right", () => Quickshell.execDetached(["hyprctl", "dispatch", "fullscreen", "0"])]]
                        Rectangle {
                            required property var modelData
                            width: 16
                            height: 16
                            radius: 8
                            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.55)
                            Symbol { anchors.centerIn: parent; name: parent.modelData[0]; size: 8; color: Theme.dark ? "#2C2C2E" : "#ECECEC" }
                            MouseArea { anchors.fill: parent; anchors.margins: -3; onClicked: parent.modelData[1]() }
                        }
                    }
                    Item { width: 6; height: 1 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(40, win.width - 380)
                        text: root.entry ? root.entry.name : ""
                        elide: Text.ElideMiddle
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.80)
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 18
                    Text {
                        visible: root.entries.length > 1
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.index + 1) + " of " + root.entries.length
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: FStyle.secondaryText
                    }
                    Symbol { anchors.verticalCenter: parent.verticalCenter; name: "info.circle"; size: 17; color: FStyle.toolIconColor }
                    Symbol { visible: root.cat === "image" || root.cat === "pdf"; anchors.verticalCenter: parent.verticalCenter; name: "pencil"; size: 17; color: FStyle.toolIconColor }
                    Symbol { anchors.verticalCenter: parent.verticalCenter; name: "square.and.arrow.up"; size: 17; color: FStyle.toolIconColor }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26
                        width: openText.implicitWidth + 26
                        radius: 13
                        color: om.pressed ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.14)) : (Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.07))
                        Text {
                            id: openText
                            anchors.centerIn: parent
                            text: root.defaultApp ? "Open with " + root.defaultApp : "Open"
                            font.family: Theme.font
                            font.pixelSize: 13
                            color: Theme.label
                        }
                        MouseArea { id: om; anchors.fill: parent; onClicked: { if (root.entry) root.source.openEntry(root.entry); root.close(); } }
                    }
                }
            }
        }
    }

    // Nom de l'application par défaut du type (« Open with Preview »)
    property string defaultApp: ""
    ProcessCollector {
        id: defProc
        onDone: (t) => {
            const id = t.trim().replace(/\.desktop$/, "");
            const de = id ? DesktopEntries.byId(id) : null;
            root.defaultApp = de ? de.name : "";
        }
    }
    onEntryChanged: { _renderBig(); _queryDefault(); }
    function _queryDefault() {
        defaultApp = "";
        if (!entry || entry.isDir) return;
        defProc.running = false;
        defProc.command = ["xdg-mime", "query", "default", Fs.mimeOf(entry)];
        defProc.running = true;
    }
}
