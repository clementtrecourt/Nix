import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.common
import qs.services

// Galerie de widgets de macOS Tahoe (« Edit Widgets » du Centre de notifications).
// Mesures relevées sur l'image Apple « Add and customize widgets on Mac »
// (macOS 26, 0,778 px/pt) :
//  - plaque de verre de ~1000 × 538 pt centrée, collée au bas de l'écran, coins
//    du haut arrondis (~13 pt) ;
//  - barre latérale de 234 pt : champ « Search Widgets » (195 × 28 pt), puis
//    « All Widgets » et une ligne par app (icône 26 pt, pas de 39 pt, sélection
//    gris translucide arrondie de 206 × 38 pt) ;
//  - à droite, le nom de la catégorie (petit, gris, demi-gras) puis les widgets
//    en aperçu réduit (~61 %) sur 3 colonnes de 249 pt, nom + description centrés ;
//  - en bas : « Drag a widget to place it on the desktop… » et le bouton bleu « Done ».
// Clic sur un widget (ou sur son bouton + vert au survol) = ajout au Centre ;
// glisser le widget hors de la galerie = ajout aussi.
PanelWindow {
    id: gal

    readonly property bool open: WidgetStore.editing
    readonly property real previewScale: 0.61
    property string category: ""         // "" = All Widgets, sinon nom de l'app

    property real progress: open && backdrop.pass ? 1 : 0
    Behavior on progress {
        NumberAnimation {
            duration: gal.open ? 420 : 260
            easing.type: Easing.BezierSpline
            easing.bezierCurve: gal.open ? [0.16, 1.0, 0.3, 1.0, 1, 1] : [0.4, 0.0, 0.9, 0.6, 1, 1]
        }
    }
    onOpenChanged: if (open) { category = ""; search.text = ""; }

    screen: {
        const name = ShellState.panelScreen || Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }
    property Item glassBackdrop: backdrop
    GlassBackdrop {
        id: backdrop
        mode: "snapshot"
        screen: gal.screen
        want: gal.open || gal.progress > 0
    }
    visible: backdrop.pass
    Component.onCompleted: WidgetStore.galleryWindow = gal

    WlrLayershell.namespace: "macos-lg-widget-gallery"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    // Seule la plaque capte la souris (un glissement en cours garde la souris)
    mask: Region { item: panel }

    // Widgets affichés : recherche, sinon catégorie choisie ; groupés par app
    readonly property var sections: {
        const q = search.text.trim().toLowerCase();
        const out = [];
        for (const a of WidgetStore.apps) {
            if (!q && category && a.app !== category) continue;
            const items = WidgetStore.catalog.filter(c => c.app === a.app && (!q
                || (c.name + " " + c.app + " " + c.desc).toLowerCase().includes(q)));
            if (items.length) out.push({ app: a.app, items: items });
        }
        return out;
    }

    Item {
        id: panel
        width: 1000
        height: 538
        x: Math.round((gal.width - width) / 2)
        y: Math.round(gal.height - height + (1 - gal.progress) * (height + 24))
        focus: gal.open
        Keys.onEscapePressed: WidgetStore.editing = false

        // Verre : déborde sous le bas de l'écran (seuls les coins du haut sont arrondis)
        NotifGlass {
            width: parent.width
            height: parent.height + 40
            radius: 13
            tint: Theme.dark ? Qt.rgba(0.12, 0.12, 0.13, 0.60) : Qt.rgba(0.97, 0.98, 1.0, 0.52)
            shadowOffset: 0
            shadowBlur: 1.0
        }

        // ---- Barre latérale ----
        Item {
            id: sidebar
            width: 234
            height: 477

            // Champ de recherche
            Rectangle {
                x: 20
                y: 19
                width: 195
                height: 28
                radius: 14
                color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.92)
                Symbol {
                    x: 9
                    anchors.verticalCenter: parent.verticalCenter
                    name: "magnifyingglass"
                    size: 13
                    color: Theme.labelSecondary
                }
                TextInput {
                    id: search
                    x: 27
                    width: parent.width - x - 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.label
                    selectionColor: Theme.accent
                    selectedTextColor: "white"
                    font.family: Theme.font
                    font.pixelSize: 13
                    clip: true
                    Keys.onEscapePressed: {
                        if (text) text = "";
                        else WidgetStore.editing = false;
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: "Search Widgets"
                        color: Theme.labelSecondary
                        font: search.font
                    }
                }
            }

            // Catégories
            Column {
                x: 14
                y: 67
                width: 206
                spacing: 1
                CategoryRow { key: ""; label: "All Widgets"; symbol: "widget.gallery" }
                Repeater {
                    model: WidgetStore.apps
                    CategoryRow {
                        required property var modelData
                        key: modelData.app
                        label: modelData.app
                        icon: Apps.icon(modelData.appId)
                    }
                }
            }
        }
        // Séparateur vertical barre latérale | widgets
        Rectangle {
            x: sidebar.width
            width: 1
            height: sidebar.height
            color: Theme.separator
        }

        // ---- Widgets ----
        Flickable {
            id: flick
            x: sidebar.width + 1
            width: panel.width - x
            height: sidebar.height
            clip: true
            contentHeight: sectionCol.implicitHeight + 10
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: sectionCol
                width: flick.width
                Repeater {
                    model: gal.sections
                    Item {
                        id: section
                        required property var modelData
                        width: sectionCol.width
                        height: 51 + grid.height
                        Text {
                            x: 27
                            y: 11
                            text: section.modelData.app
                            color: Theme.labelSecondary
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        Grid {
                            id: grid
                            x: Math.round((section.width - 3 * 249) / 2)
                            y: 51
                            columns: 3
                            Repeater {
                                model: section.modelData.items
                                GalleryItem {
                                    required property var modelData
                                    info: modelData
                                }
                            }
                        }
                    }
                }
            }
            Text {
                visible: gal.sections.length === 0
                anchors.centerIn: parent
                text: "No Results"
                color: Theme.labelSecondary
                font.family: Theme.font
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
        }

        // ---- Barre du bas ----
        Rectangle {
            y: sidebar.height
            width: panel.width
            height: 1
            color: Theme.separator
        }
        Text {
            x: 19
            anchors.verticalCenter: doneBtn.verticalCenter
            text: "Drag a widget to place it on the desktop…"
            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.78)
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
        Rectangle {
            id: doneBtn
            x: panel.width - width - 19
            y: 495
            width: 82
            height: 26
            radius: 13
            color: doneMouse.pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent
            Text {
                anchors.centerIn: parent
                text: "Done"
                color: "white"
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            MouseArea {
                id: doneMouse
                anchors.fill: parent
                onClicked: WidgetStore.editing = false
            }
        }
    }

    // Widget en cours de glissement (taille réelle, suit le pointeur)
    Item {
        id: ghost
        property var info: null
        visible: info !== null
        z: 100
        opacity: 0.92
        width: info ? info.w : 0
        height: info ? info.h : 0
        Loader {
            active: ghost.info !== null
            sourceComponent: ghost.info ? gal.widgetComponent(ghost.info.id) : null
        }
    }

    IpcHandler {
        target: "widget-gallery-debug"
        function category(name: string): void { gal.category = name; }
        function search(text: string): void { search.text = text; }
        function hoverFirst(on: bool): void { gal.debugHover = on; }
    }
    property bool debugHover: false

    // ---- Composants ----
    Component { id: upNextComp; WidgetUpNext {} }
    Component { id: calendarComp; WidgetCalendar {} }
    Component { id: clockComp; WidgetClock { running: gal.visible } }
    function widgetComponent(id) {
        return id === "upnext" ? upNextComp : id === "calendar" ? calendarComp : clockComp;
    }

    component CategoryRow: Item {
        id: row
        property string key
        property string label
        property string symbol: ""
        property string icon: ""
        readonly property bool selected: gal.category === key && !search.text
        width: 206
        height: 38
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: row.selected ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.12))
                 : rowMouse.pressed ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06))
                 : "transparent"
        }
        Symbol {
            visible: row.symbol !== ""
            x: 7
            anchors.verticalCenter: parent.verticalCenter
            name: row.symbol
            size: 24
            color: Theme.labelSecondary
        }
        Image {
            visible: row.icon !== ""
            x: 7
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            source: row.icon
            sourceSize: Qt.size(52, 52)
            smooth: true
            mipmap: true
        }
        Text {
            x: 39
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: Theme.label
            font.family: Theme.font
            font.pixelSize: 13
        }
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            onClicked: { search.text = ""; gal.category = row.key; flick.contentY = 0; }
        }
    }

    // Widget de la galerie : aperçu réduit, nom, description ; + vert au survol
    component GalleryItem: Item {
        id: item
        property var info: ({})
        width: 249
        height: 236
        Item {
            id: prev
            width: Math.round(item.info.w * gal.previewScale)
            height: Math.round(item.info.h * gal.previewScale)
            x: Math.round((item.width - width) / 2)
            opacity: drag.active ? 0.4 : 1
            // Widget réel rendu en texture (marge pour son ombre) puis réduit
            // (mipmap : reste net à l'échelle 1)
            Item {
                x: -40 * gal.previewScale
                y: -40 * gal.previewScale
                width: item.info.w + 80
                height: item.info.h + 80
                scale: gal.previewScale
                transformOrigin: Item.TopLeft
                layer.enabled: true
                layer.smooth: true
                layer.mipmap: true
                layer.textureSize: Qt.size(width * 2, height * 2)
                Loader {
                    x: 40
                    y: 40
                    sourceComponent: gal.widgetComponent(item.info.id)
                }
            }
            HoverHandler { id: hover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: WidgetStore.add(item.info.id)
            }
            DragHandler {
                id: drag
                target: null
                onActiveChanged: {
                    if (active) {
                        ghost.info = item.info;
                        return;
                    }
                    // Lâché hors de la galerie : ajouté au Centre de notifications
                    if (ghost.y + ghost.height / 2 < panel.y) WidgetStore.add(item.info.id);
                    ghost.info = null;
                }
                onCentroidChanged: {
                    if (!active) return;
                    const p = prev.mapToItem(null, centroid.position.x, centroid.position.y);
                    ghost.x = Math.round(p.x - ghost.width / 2);
                    ghost.y = Math.round(p.y - ghost.height / 2);
                }
            }
            // Bouton Add (+ vert), à cheval sur le coin haut-gauche
            Rectangle {
                x: -7
                y: -7
                width: 20
                height: 20
                radius: 10
                color: Theme.green
                visible: (hover.hovered || (gal.debugHover && item.info.id === "upnext")) && !drag.active
                Symbol {
                    anchors.centerIn: parent
                    name: "plus"
                    size: 14
                    color: "white"
                }
            }
        }
        Text {
            id: nameLabel
            width: item.width - 20
            x: 10
            y: prev.height + 22
            horizontalAlignment: Text.AlignHCenter
            text: item.info.name
            color: Theme.label
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
        Text {
            x: Math.round((item.width - width) / 2)
            y: nameLabel.y + nameLabel.height
            width: 150
            horizontalAlignment: Text.AlignHCenter
            text: item.info.desc
            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.72) : Qt.rgba(0.10, 0.16, 0.30, 0.82)
            font.family: Theme.font
            font.pixelSize: 11
            lineHeight: 1.1
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }
    }
}
