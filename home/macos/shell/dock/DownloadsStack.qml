import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import qs.common

// Pile « Downloads » ouverte depuis le Dock, dans la présentation choisie par
// « View content as » (menu de la tuile ; page Apple « Use folders in the Dock
// on Mac ») :
//  - Fan (éventail) : les éléments montent de l'icône du Dock en arc vers la
//    droite, le plus récent en bas, nom dans une pastille à gauche de l'icône ;
//    en haut « Open in Finder » (ou « N More in Finder » s'ils ne tiennent pas).
//    Un dossier s'ouvre dans le Finder.
//  - Grid (grille), relevée sur une capture 9to5Mac de macOS 26 (pile
//    « Applications » en grille, 2x) : grande plaque Liquid Glass claire, rayon
//    ~18 pt, petite pointe centrée sur l'icône, titre centré et filet, grandes
//    icônes (≈ 1,86 x le squircle du Dock) et nom élidé au milieu, filet puis
//    « Open in Finder ». Un sous-dossier s'ouvre sur place, avec un bouton retour.
//  - List (liste) : plaque façon menu, petite icône et nom sur chaque ligne,
//    chevron pour les dossiers (ouverts sur place, avec retour).
//  - Automatic : éventail si les éléments tiennent dans l'arc, sinon grille.
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
    readonly property var fs: dock.downloads

    // ---- Navigation (sous-dossiers ouverts sur place : grille, liste) ----
    property string path: folder
    property var history: []
    property var subItems: []
    readonly property bool atRoot: path === folder
    readonly property var items: atRoot ? fs.sorted : subItems
    readonly property int fileCount: items.length
    readonly property string title: atRoot ? "Downloads" : path.replace(/\/$/, "").split("/").pop()

    function navigate(p) {
        history = history.concat([path]);
        path = p;
        loadSub();
        grid.positionViewAtBeginning();
        list.positionViewAtBeginning();
    }
    function back() {
        if (history.length === 0) return;
        const h = history.slice();
        path = h.pop();
        history = h;
        if (!atRoot) loadSub();
    }
    function loadSub() {
        const p = path;
        subItems = [];
        fs.list(p, (l) => { if (root.path === p) root.subItems = root.fs.sortEntries(l, root.dock.stackSort); });
    }

    // ---- Présentation ----
    // Éventail : icônes de la taille du Dock, pas vertical d'une icône + 10 pt
    readonly property int fanIcon: Math.round(dock.canvas)
    readonly property int fanStep: fanIcon + 10
    readonly property int fanButtonH: 40
    // Hauteur disponible entre la barre des menus et le Dock
    readonly property real availH: screenH - Theme.menuBarHeight - dockWindow.height + dock.platterTop - 20
    readonly property int fanCapacity: Math.max(1, Math.min(15, Math.floor((availH - fanButtonH - 30) / fanStep)))
    readonly property string autoMode: dock.stackView === "auto" ? (fs.count <= fanCapacity ? "fan" : "grid") : dock.stackView
    // Figée à l'ouverture (la navigation ne change pas de présentation)
    property string mode: "grid"

    function toggleFor(t) {
        if (open) { close(); return; }
        anchorX = t.x + t.width / 2;
        path = folder;
        history = [];
        subItems = [];
        fs.refresh();
        mode = autoMode;
        grid.positionViewAtBeginning();
        list.positionViewAtBeginning();
        fanIn.restart();
        popup.anchor.updateAnchor();
        open = true;
    }
    function close() { open = false; grab = true; }
    function debugInfo() { return fileCount + " mode=" + mode + " path=" + path + " cols=" + cols + " fanCapacity=" + fanCapacity; }
    function debugNavigate(i) { const e = items[i]; if (e && e.isDir) navigate(e.path); }
    function activate(e) {
        if (e.isDir && mode !== "fan") { navigate(e.path); return; }
        close();
        // Dossier : Finder ; fichier : app par défaut
        if (e.isDir) dock.model.openPath(e.path);
        else dock.model.openFile(e.path);
    }

    // Aperçu d'un élément : miniature du cache, image elle-même, sinon icône du type
    function sourcesFor(e, big) {
        const l = [];
        const th = e.isDir ? "" : fs.thumbFor(e.path, big);
        if (th) l.push(th);
        if (!e.isDir && fs.isImage(e.name)) l.push("file://" + e.path);
        l.push(fs.iconFor(e.name, e.isDir));
        return l;
    }

    // ---- Géométrie de la grille et de la liste (pt) ----
    // Cellule et icône proportionnelles à la toile du Dock (48 pt -> 114 / 88)
    readonly property int cellW: Math.round(dock.canvas * 2.38)
    readonly property int cellH: Math.round(dock.canvas * 2.38)
    readonly property int iconBox: Math.round(dock.canvas * 1.84)
    readonly property int headerH: 30
    readonly property int footerH: 34
    readonly property int sidePad: 14
    readonly property int radius: mode === "list" ? 14 : 18
    readonly property int tailW: 18
    readonly property int tailH: 9
    // Colonnes : grille presque carrée, 3 à 7 colonnes, dans la largeur de l'écran
    readonly property int cols: Math.max(1, Math.min(Math.floor((screenW - 80) / cellW),
                                                     Math.min(7, Math.max(3, Math.ceil(Math.sqrt(fileCount * 1.3))))))
    readonly property int maxRows: Math.max(1, Math.floor((availH - 40 - headerH - footerH - tailH) / cellH))
    readonly property int rows: Math.max(1, Math.min(maxRows, Math.ceil(fileCount / cols)))
    // Liste : lignes de 24 pt (comme les menus), largeur du nom le plus long
    readonly property int rowH: 24
    readonly property int listMaxRows: Math.max(1, Math.floor((availH - 40 - headerH - footerH - tailH - 10) / rowH))
    readonly property int listRows: Math.max(1, Math.min(listMaxRows, fileCount))
    FontMetrics { id: fm; font.family: Theme.font; font.pixelSize: Theme.fontSize }
    readonly property int listW: {
        let w = 0;
        for (let i = 0; i < Math.min(items.length, 200); i++) w = Math.max(w, fm.advanceWidth(items[i].name));
        return Math.round(Math.max(220, Math.min(360, w + 16 + 26 + 36)));
    }

    // ---- Éventail ----
    // Arc : décalage horizontal ∝ hauteur² (≈ 60 pt pour 10 éléments), chaque
    // ligne inclinée selon la tangente
    readonly property int fanCount: Math.min(fileCount, fanCapacity)
    readonly property real fanCurve: 0.00018
    readonly property int fanLabelMax: 240
    readonly property real fanTopH: fanCount * fanStep + fanButtonH + 12
    readonly property real fanMaxDx: fanCurve * fanTopH * fanTopH
    function fanDx(h) { return fanCurve * h * h; }
    function fanAngle(h) { return Math.atan(2 * fanCurve * h) * 180 / Math.PI; }
    property real fanProgress: 1
    NumberAnimation {
        id: fanIn
        target: root
        property: "fanProgress"
        from: 0; to: 1
        duration: 260
        easing.type: Easing.OutCubic
    }

    // ---- Taille de la plaque selon la présentation ----
    readonly property real plateW: mode === "list" ? listW : mode === "fan"
                                   ? fanLabelMax + 12 + fanIcon / 2 + fanMaxDx + 110
                                   : cols * cellW + 2 * sidePad
    readonly property real plateH: mode === "list" ? headerH + listRows * rowH + 10 + footerH
                                   : mode === "fan" ? fanTopH
                                   : headerH + rows * cellH + footerH
    readonly property int margin: 24

    // ---- Position sur l'écran (repère de la capture du verre) ----
    readonly property real popupW: plateW + 2 * margin
    readonly property real popupH: plateH + tailH + 2 * margin
    readonly property real dockY: screenH - dockWindow.height
    // Éventail : colonne d'icônes au-dessus de l'icône du Dock (noms à gauche) ;
    // grille et liste : centrées sur l'icône
    readonly property real fanIconX: fanLabelMax + 12 + margin     // centre de la colonne, dans la fenêtre
    readonly property real popupX: Math.max(0, Math.min(screenW - popupW,
        Math.round(mode === "fan" ? anchorX - fanIconX - fanIcon / 2 : anchorX + 0.5 - popupW / 2)))
    readonly property real popupY: dockY + popup.anchor.rect.y - popupH
    // Abscisse de la pointe dans la plaque (suit l'icône si la plaque a glissé)
    readonly property real tailX: Math.max(radius + tailW / 2, Math.min(plateW - radius - tailW / 2, anchorX - popupX - margin))

    PopupWindow {
        id: popup
        // Visible dès que la capture du fond est arrivée (~50 ms)
        visible: stackBackdrop.pass
        color: "transparent"
        grabFocus: root.grab
        anchor.window: root.dockWindow
        // Coin bas-gauche de la fenêtre : la pointe à 10 pt au-dessus de la plaque du Dock
        anchor.rect.x: root.popupX
        anchor.rect.y: root.dock.platterTop - 10 + root.margin
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Top | Edges.Right
        anchor.adjustment: PopupAdjustment.None
        implicitWidth: root.popupW
        implicitHeight: root.popupH
        mask: Region { item: root.mode === "fan" ? fanArea : plate }
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

        // Échap : ferme ; Retour arrière / Cmd+[ : dossier parent
        Item {
            focus: true
            Keys.onEscapePressed: root.close()
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Backspace || (e.key === Qt.Key_BracketLeft && (e.modifiers & Qt.ControlModifier))) root.back();
            }
        }

        // ================= Éventail =================
        Item {
            id: fanArea
            visible: root.mode === "fan"
            x: root.margin
            y: root.margin
            width: root.plateW
            height: root.plateH + root.tailH

            Repeater {
                model: root.mode === "fan" ? root.items.slice(0, root.fanCount) : []
                Item {
                    id: fanRow
                    required property var modelData
                    required property int index
                    // Hauteur du centre de l'icône au-dessus du bas de l'éventail
                    readonly property real h: (index + 0.5) * root.fanStep + 4
                    readonly property real p: root.fanProgress
                    width: fanArea.width
                    height: root.fanIcon
                    // Centre de l'icône : sur la colonne, décalé selon l'arc ; part de l'icône du Dock
                    readonly property real cx: root.fanIconX - root.margin + root.fanIcon / 2 + root.fanDx(h) * p
                    y: Math.round(fanArea.height - h * p - height / 2)
                    opacity: Math.min(1, p * 1.5)
                    transform: Rotation {
                        origin.x: fanRow.cx
                        origin.y: fanRow.height / 2
                        angle: root.fanAngle(fanRow.h) * fanRow.p
                    }

                    StackPreview {
                        id: fanThumb
                        x: Math.round(fanRow.cx - width / 2)
                        width: root.fanIcon
                        height: root.fanIcon
                        sources: root.sourcesFor(fanRow.modelData, false)
                        pixel: root.fanIcon
                        hovered: fanMouse.containsMouse
                    }
                    // Nom dans une pastille, à gauche de l'icône
                    Rectangle {
                        id: pill
                        readonly property bool lit: fanMouse.containsMouse
                        height: 22
                        width: Math.min(root.fanLabelMax, Math.ceil(fanName.implicitWidth) + 20)
                        x: Math.round(fanThumb.x - 8 - width)
                        anchors.verticalCenter: parent.verticalCenter
                        radius: height / 2
                        color: lit ? Theme.accent : (Theme.dark ? Qt.rgba(0.12, 0.12, 0.13, 0.82) : Qt.rgba(0.97, 0.97, 0.98, 0.88))
                        border.width: 1
                        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)
                        Text {
                            id: fanName
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, root.fanLabelMax - 20)
                            text: fanRow.modelData.name
                            elide: Text.ElideMiddle
                            textFormat: Text.PlainText
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            color: pill.lit ? "white" : Theme.label
                        }
                    }
                    MouseArea {
                        id: fanMouse
                        x: pill.x
                        width: fanThumb.x + fanThumb.width - pill.x
                        height: parent.height
                        hoverEnabled: true
                        onClicked: root.activate(fanRow.modelData)
                    }
                }
            }
            // Bouton du haut : « Open in Finder » / « N More in Finder »
            Rectangle {
                id: fanButton
                readonly property real h: root.fanCount * root.fanStep + root.fanButtonH / 2 + 10
                readonly property int more: root.fileCount - root.fanCount
                height: 24
                width: Math.ceil(fanButtonText.implicitWidth) + 44
                x: Math.round(root.fanIconX - root.margin + root.fanIcon / 2 + root.fanDx(h) - width / 2)
                y: Math.round(fanArea.height - h * root.fanProgress - height / 2)
                opacity: root.fanProgress
                radius: height / 2
                color: fanBtnMouse.containsMouse ? Theme.accent : (Theme.dark ? Qt.rgba(0.12, 0.12, 0.13, 0.82) : Qt.rgba(0.97, 0.97, 0.98, 0.88))
                border.width: 1
                border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)
                Symbol {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: "arrow.up.forward.app"
                    size: 14
                    color: fanBtnMouse.containsMouse ? "white" : Theme.label
                }
                Text {
                    id: fanButtonText
                    x: 32
                    anchors.verticalCenter: parent.verticalCenter
                    text: fanButton.more > 0 ? fanButton.more + " More in Finder" : "Open in Finder"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    color: fanBtnMouse.containsMouse ? "white" : Theme.label
                }
                MouseArea {
                    id: fanBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { root.close(); root.dock.model.openPath(root.folder); }
                }
            }
        }

        // ================= Grille / liste : plaque Liquid Glass =================
        Item {
            id: plate
            visible: root.mode !== "fan"
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
                overlay: refracting ? (root.mode === "list" ? Theme.menuBackground : popup.veil) : "transparent"
                rimColor: popup.rim
                shadowBlur: 0.9
                shadowOffset: 6
            }

            // ---- Pointe : triangle arrondi sous la plaque, liseré sur ses flancs.
            // Elle n'est pas réfractante (9 pt de haut) : voile du verre posé
            // directement sur le fond, un peu plus dense pour rejoindre la plaque.
            Shape {
                x: root.tailX - root.tailW / 2
                y: root.plateH - 2
                width: root.tailW
                height: root.tailH + 2
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    readonly property color v: root.mode === "list" ? Theme.menuBackground : popup.veil
                    fillColor: glass.refracting ? Qt.rgba(v.r, v.g, v.b, Math.min(1, v.a + 0.12)) : Theme.menuBackground
                    strokeColor: "transparent"
                    startX: 0; startY: 2
                    PathLine { x: root.tailW; y: 2 }
                    PathQuad { x: root.tailW / 2 + 1.6; y: root.tailH + 1.2; controlX: root.tailW / 2 + 3; controlY: 4.5 }
                    PathQuad { x: root.tailW / 2 - 1.6; y: root.tailH + 1.2; controlX: root.tailW / 2; controlY: root.tailH + 2.6 }
                    PathQuad { x: 0; y: 2; controlX: root.tailW / 2 - 3; controlY: 4.5 }
                }
            }
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

            // ---- En-tête : retour (sous-dossier), nom du dossier, filet ----
            Text {
                id: header
                x: 36
                width: parent.width - 72
                height: root.headerH
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.title
                elide: Text.ElideMiddle
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.label
            }
            Item {
                visible: root.history.length > 0
                x: 8
                width: 26
                height: root.headerH
                Rectangle {
                    anchors.centerIn: parent
                    width: 22; height: 22; radius: 6
                    color: Theme.fill
                    visible: backMouse.containsMouse
                }
                Symbol {
                    anchors.centerIn: parent
                    name: "chevron.left"
                    size: 12
                    color: Theme.label
                }
                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.back()
                }
            }
            Rectangle {
                y: root.headerH - 1
                x: 1
                width: parent.width - 2
                height: 1
                color: Theme.separator
            }

            // ---- Grille ----
            GridView {
                id: grid
                visible: root.mode === "grid"
                x: root.sidePad
                y: root.headerH
                width: root.cols * root.cellW
                height: root.rows * root.cellH
                cellWidth: root.cellW
                cellHeight: root.cellH
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.mode === "grid" ? root.items : []

                delegate: Item {
                    id: cellItem
                    required property var modelData
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
                    StackPreview {
                        id: thumb
                        width: root.iconBox
                        height: root.iconBox
                        x: Math.round((parent.width - width) / 2)
                        y: 6
                        sources: root.sourcesFor(cellItem.modelData, true)
                        pixel: root.iconBox
                    }
                    Text {
                        anchors.top: thumb.bottom
                        anchors.topMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.cellW - 8
                        horizontalAlignment: Text.AlignHCenter
                        text: cellItem.modelData.name
                        textFormat: Text.PlainText
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
                        onClicked: root.activate(cellItem.modelData)
                    }
                }
            }

            // ---- Liste ----
            ListView {
                id: list
                visible: root.mode === "list"
                x: 0
                y: root.headerH + 5
                width: parent.width
                height: root.listRows * root.rowH
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.mode === "list" ? root.items : []
                delegate: Item {
                    id: lrow
                    required property var modelData
                    width: list.width
                    height: root.rowH
                    readonly property bool lit: lmouse.containsMouse
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 5
                        anchors.rightMargin: 5
                        radius: Theme.radiusMenuItem
                        color: Theme.menuHighlight
                        visible: lrow.lit
                    }
                    StackPreview {
                        x: 14
                        y: Math.round((parent.height - height) / 2)
                        width: 16
                        height: 16
                        sources: root.sourcesFor(lrow.modelData, false)
                        pixel: 16
                    }
                    Text {
                        x: 38
                        width: parent.width - x - (lrow.modelData.isDir ? 30 : 16)
                        anchors.verticalCenter: parent.verticalCenter
                        text: lrow.modelData.name
                        textFormat: Text.PlainText
                        elide: Text.ElideMiddle
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        color: lrow.lit ? Theme.menuHighlightText : Theme.label
                    }
                    Symbol {
                        visible: lrow.modelData.isDir
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron.right"
                        size: 10
                        color: lrow.lit ? Theme.menuHighlightText : Theme.label
                    }
                    MouseArea {
                        id: lmouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.activate(lrow.modelData)
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
                y: Math.round(root.plateH - root.footerH + (root.footerH - height) / 2)
                text: "Open in Finder"
                font.family: Theme.font
                font.pixelSize: 13
                color: openHov.containsMouse ? Theme.accent : Theme.label
                MouseArea {
                    id: openHov
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    onClicked: { root.close(); root.dock.model.openPath(root.path); }
                }
            }
        }
    }
}
