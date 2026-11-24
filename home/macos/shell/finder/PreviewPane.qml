import QtQuick
import qs.common

// Volet d'aperçu du Finder (colonne d'aperçu de la présentation Colonnes,
// volet d'informations de la Galerie) : aperçu, nom, « PNG image - 46 KB »,
// section Information (Created, Modified, Last opened, Dimensions) avec
// « Show More / Show Less », Tags (« Add Tags… »), boutons d'actions rapides.
// Captures : MacStories (volet d'aperçu), Apple mchldaafb302 (Galerie).
Item {
    id: root

    property var entry: null
    // Vrai : grand aperçu en haut (colonnes) ; faux : vignette + nom (galerie)
    property bool compact: false
    // Repliée par défaut (« Show More »), comme Tahoe
    property bool more: false

    // Dimensions d'une image (taille naturelle après chargement)
    Image {
        id: probe
        visible: false
        asynchronous: true
        source: root.entry && Fs.isImage(root.entry) && Fs.ext(root.entry.name) !== "svg" ? Fs.fileUrl(root.entry.path) : ""
        sourceSize: undefined
        cache: false
    }
    readonly property string dims: probe.status === Image.Ready ? probe.implicitWidth + " × " + probe.implicitHeight : ""

    readonly property var info: {
        const e = entry;
        if (!e) return [];
        const l = [];
        l.push(["Created", Fs.formatDatePane(e.btime || e.mtime)]);
        l.push(["Modified", Fs.formatDatePane(e.mtime)]);
        l.push(["Last opened", Fs.formatDatePane(e.atime || e.mtime)]);
        if (dims) { l.push(["Dimensions", dims]); l.push(["Resolution", "72×72"]); }
        if (more && dims) l.push(["Color space", "RGB"]);
        return l;
    }

    Flickable {
        anchors.fill: parent
        anchors.bottomMargin: 60
        contentHeight: col.implicitHeight + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            x: 16
            width: parent.width - 32
            spacing: 0

            // Grand aperçu (colonnes)
            Item {
                visible: root.compact
                width: col.width
                height: visible ? Math.min(col.width, 260) + 14 : 0
                FileIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: Math.min(col.width, 260)
                    entry: root.entry
                }
            }
            // Vignette + nom (galerie)
            Row {
                visible: !root.compact
                spacing: 10
                height: visible ? 56 : 0
                FileIcon { size: 48; entry: root.entry; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: col.width - 58
                    Text {
                        width: parent.width
                        text: root.entry?.name ?? ""
                        elide: Text.ElideMiddle
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: Theme.label
                    }
                    Text {
                        text: root.entry ? Fs.kindOf(root.entry) + (root.entry.isDir ? "" : " - " + Fs.formatSize(root.entry.size)) : ""
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: FStyle.secondaryText
                    }
                }
            }
            Text {
                visible: root.compact
                width: col.width
                text: root.entry?.name ?? ""
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: Theme.label
            }
            Text {
                visible: root.compact
                text: root.entry ? Fs.kindOf(root.entry) + (root.entry.isDir ? "" : " - " + Fs.formatSize(root.entry.size)) : ""
                font.family: Theme.font
                font.pixelSize: 13
                color: FStyle.secondaryText
            }
            Item { width: 1; height: 16 }
            Item {
                width: col.width
                height: 22
                Text {
                    text: "Information"
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.label
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.more ? "Show Less" : "Show More"
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.accent
                    MouseArea { anchors.fill: parent; onClicked: root.more = !root.more }
                }
            }
            Repeater {
                model: root.info
                Item {
                    required property var modelData
                    required property int index
                    width: col.width
                    height: 25
                    Rectangle {
                        visible: parent.index > 0
                        width: parent.width
                        height: 1
                        color: FStyle.gridLine
                    }
                    Text {
                        id: lab
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData[0]
                        font.family: Theme.font
                        font.pixelSize: 11
                        color: FStyle.secondaryText
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - lab.implicitWidth - 10
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: parent.modelData[1]
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Theme.label
                    }
                }
            }
            Item { width: 1; height: 18 }
            Text {
                text: "Tags"
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.label
            }
            Item { width: 1; height: 6 }
            Rectangle {
                width: col.width
                height: 40
                radius: 4
                color: Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.025)
                Row {
                    x: 6
                    y: 6
                    spacing: 4
                    Repeater {
                        model: root.entry ? Fs.tagsOf(root.entry.path) : []
                        Rectangle {
                            required property string modelData
                            height: 18
                            width: tt.implicitWidth + 22
                            radius: 9
                            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
                            Rectangle { x: 5; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: Fs.tagColor(parent.modelData) }
                            Text { id: tt; x: 16; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData; font.family: Theme.font; font.pixelSize: 11; color: Theme.label }
                        }
                    }
                }
                Text {
                    visible: !root.entry || Fs.tagsOf(root.entry.path).length === 0
                    x: 6
                    y: 4
                    text: "Add Tags…"
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.labelTertiary
                }
            }
        }
    }

    // Actions rapides (bas du volet), sous un filet pleine largeur
    Rectangle {
        visible: !!root.entry && !root.compact
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 58
        width: parent.width
        height: 1
        color: FStyle.gridLine
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        spacing: 26
        visible: !!root.entry
        Repeater {
            model: root.entry && Fs.isImage(root.entry) ? [["rotate.left", "Rotate Left"], ["pencil.tip.crop.circle", "Markup"], ["ellipsis.circle", "More…"]]
                                                        : [["ellipsis.circle", "More…"]]
            Column {
                required property var modelData
                spacing: 3
                Symbol { anchors.horizontalCenter: parent.horizontalCenter; name: parent.modelData[0]; size: 18; color: FStyle.secondaryText }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData[1]; font.family: Theme.font; font.pixelSize: 11; color: FStyle.secondaryText }
            }
        }
    }
}
