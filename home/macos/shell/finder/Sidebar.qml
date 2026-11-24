import QtQuick
import Quickshell
import qs.common

// Barre latérale du Finder de Tahoe : plaque de Liquid Glass flottante, inset
// de 8 pt dans la fenêtre, coins de 18 pt, feux tricolores en haut à gauche.
// Sections Favorites / Locations / Tags repliables (chevron au survol de
// l'en-tête). Pictogrammes monochromes ; l'élément choisi passe en bleu sur
// une pastille grise (captures Apple mchl83c9e8b8 / Daring Fireball, 26.2).
Item {
    id: root

    required property var fw
    property Item backdropItem: null

    property var collapsed: ({})

    // Éléments : { kind: "header"|"item", section, label, symbol, path, enabled, tag, volume }
    readonly property var model: {
        const l = [];
        const add = (section, label, symbol, path, extra) => l.push(Object.assign({ kind: "item", section: section, label: label, symbol: symbol, path: path, enabled: true }, extra ?? {}));
        add("", "Recents", "clock", "recents://");
        l.push({ kind: "header", section: "Favorites", label: "Favorites" });
        add("Favorites", "Applications", "appstore", "applications://");
        add("Favorites", "Desktop", "menubar.dock.rectangle", Fs.xdg.DESKTOP);
        add("Favorites", "Documents", "doc", Fs.xdg.DOCUMENTS);
        add("Favorites", "Downloads", "arrow.down.circle", Fs.xdg.DOWNLOAD);
        add("Favorites", Fs.user, "house", Fs.home);
        l.push({ kind: "header", section: "Locations", label: "Locations" });
        add("Locations", Fs.rootVolumeName, "internaldrive", "/");
        for (const v of Fs.volumes) add("Locations", v.name, "internaldrive", v.path, { volume: v.removable });
        add("Locations", "AirDrop", "airdrop", "airdrop://", { enabled: false });
        add("Locations", "Network", "network", "network://");
        add("Locations", "Trash", "trash", "trash://");
        l.push({ kind: "header", section: "Tags", label: "Tags" });
        for (const t of Fs.tagList) add("Tags", t.name, "", "tag://" + t.name, { tag: t.name });
        return l;
    }

    FinderGlass {
        anchors.fill: parent
        radius: FStyle.sidebarRadius
        backdropItem: root.backdropItem
        tint: FStyle.sidebarTint
        veil: 0.6
        veilColor: Theme.dark ? Qt.rgba(0.19, 0.19, 0.20, 1) : Qt.rgba(0.965, 0.965, 0.97, 1)
        shadowBlur: 0.55
        shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.30 : 0.07)
        rimColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.95)
        rimBase: 0.35
        edgeDarken: Theme.dark ? 0.20 : 0.05
        glowColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.5)
        shadeColor: Theme.dark ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(0, 0, 0, 0.02)
    }

    // Glisser la fenêtre par le haut de la barre latérale
    MouseArea {
        width: parent.width
        height: 44
        onPressed: root.fw.startSystemMove()
        onDoubleClicked: root.fw.zoomWindow(false)
    }

    TrafficLights {
        x: FStyle.lightX - FStyle.sidebarInset
        y: FStyle.lightY - FStyle.sidebarInset
        active: root.fw.active
        onCloseClicked: root.fw.closeWindow()
        onMinimizeClicked: root.fw.minimizeWindow()
        onZoomClicked: root.fw.zoomWindow(true)
    }

    Flickable {
        id: flick
        x: 0
        y: 44
        width: parent.width
        height: parent.height - y - 6
        clip: true
        contentHeight: col.implicitHeight + 8
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: flick.width

            Repeater {
                model: root.model

                Item {
                    id: row
                    required property var modelData
                    readonly property bool header: modelData.kind === "header"
                    readonly property bool hiddenBySection: !header && !!modelData.section && !!root.collapsed[modelData.section]
                    readonly property bool current: !header && root.fw.path === modelData.path
                    width: col.width
                    height: hiddenBySection ? 0 : FStyle.sidebarRow
                    visible: !hiddenBySection
                    clip: true

                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    // ---- En-tête de section ----
                    Item {
                        visible: row.header
                        anchors.fill: parent
                        Text {
                            x: 15.5
                            anchors.verticalCenter: parent.top
                            anchors.verticalCenterOffset: 23.5
                            text: row.modelData.label ?? ""
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: FStyle.sidebarHeader
                        }
                        Symbol {
                            visible: hh.containsMouse
                            name: root.collapsed[row.modelData.section] ? "chevron.right" : "chevron.down"
                            size: 10
                            color: FStyle.sidebarHeader
                            x: parent.width - 26
                            anchors.verticalCenter: parent.top
                            anchors.verticalCenterOffset: 23.5
                        }
                        MouseArea {
                            id: hh
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                const c = Object.assign({}, root.collapsed);
                                c[row.modelData.section] = !c[row.modelData.section];
                                root.collapsed = c;
                            }
                        }
                    }

                    // ---- Élément ----
                    Item {
                        visible: !row.header
                        anchors.fill: parent
                        opacity: row.modelData.enabled === false ? 0.38 : 1

                        Rectangle {
                            x: 10.5
                            width: parent.width - 21
                            height: FStyle.sidebarPillHeight
                            anchors.verticalCenter: parent.verticalCenter
                            radius: FStyle.sidebarPillRadius
                            color: drop.containsDrag ? Qt.rgba(FStyle.sidebarAccent.r, FStyle.sidebarAccent.g, FStyle.sidebarAccent.b, 0.22)
                                   : FStyle.sidebarSelection
                            visible: row.current || drop.containsDrag
                        }
                        // Pastille de couleur des tags
                        Rectangle {
                            visible: !!row.modelData.tag
                            x: FStyle.sidebarIconX + 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12
                            height: 12
                            radius: 6
                            color: Fs.tagColor(row.modelData.tag ?? "")
                        }
                        Symbol {
                            visible: !row.modelData.tag
                            x: FStyle.sidebarIconX
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.modelData.symbol ?? ""
                            size: 21
                            color: row.current ? FStyle.sidebarAccent : (Theme.dark ? Qt.rgba(1, 1, 1, 0.86) : Qt.rgba(0, 0, 0, 0.84))
                        }
                        Text {
                            x: FStyle.sidebarTextX
                            width: parent.width - x - (row.modelData.volume ? 34 : 12)
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.label ?? ""
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: 13
                            color: row.current ? FStyle.sidebarAccent : (Theme.dark ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(0, 0, 0, 0.86))
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: row.modelData.enabled !== false
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (m) => {
                                if (m.button === Qt.RightButton) {
                                    root.fw.finder.sidebarMenu(root.fw, row.modelData, mapToItem(null, m.x, m.y));
                                    return;
                                }
                                root.fw.navigate(row.modelData.path);
                            }
                        }
                        // Éjecter (volumes amovibles)
                        Symbol {
                            visible: !!row.modelData.volume
                            name: "eject.fill"
                            size: 12
                            color: FStyle.secondaryText
                            x: parent.width - 30
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                onClicked: Fs.eject(row.modelData.path)
                            }
                        }
                        DropArea {
                            id: drop
                            anchors.fill: parent
                            enabled: row.modelData.enabled !== false && row.modelData.path !== "recents://"
                                     && row.modelData.path !== "applications://" && row.modelData.path !== "network://"
                            keys: ["text/uri-list"]
                            onDropped: (d) => {
                                const ps = root.fw.dropPaths(d);
                                if (ps.length) root.fw.dropInto(row.modelData.path, ps, d.proposedAction === Qt.CopyAction);
                                d.acceptProposedAction();
                            }
                        }
                    }
                }
            }
        }
    }
}
