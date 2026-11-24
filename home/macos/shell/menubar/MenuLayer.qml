import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common

// Couche plein écran (sous la barre) qui affiche le menu ouvert sur cet écran :
// elle capte le clavier (↑ ↓ ← → Entrée Échap, saisie rapide) et les clics
// hors du menu (qui ferment le menu sans atteindre l'app, comme sur macOS).
// Le verre des menus (Liquid Glass) réfracte une capture de l'écran prise
// juste avant l'ouverture (GlassBackdrop "snapshot") ; Hyprland ne floute donc
// pas cette surface (namespace macos-lg-*).
PanelWindow {
    id: menuLayer

    property var controller
    // Nom de l'écran (fixe : évite une boucle de liaison avec `screen`)
    property string screenName: ""

    // Fond réfracté par tous les verres de la couche (menu et sous-menus)
    property Item glassBackdrop: backdrop
    GlassBackdrop {
        id: backdrop
        mode: "snapshot"
        screen: menuLayer.screen
        want: menuLayer.controller.screenName === menuLayer.screenName
              && (menuLayer.controller.isOpen || menuLayer.controller.closing)
        // Position de la couche sur l'écran (ancrée en haut, margins.top)
        origin: Qt.point(0, menuLayer.top)
    }
    // Délai d'ouverture dû à la capture (debug : menubar-debug state)
    property real snapshotLatency: 0
    property double _t0: 0
    Connections {
        target: backdrop
        function onWantChanged() { if (backdrop.want) menuLayer._t0 = Date.now(); }
        function onPassChanged() { if (backdrop.pass) menuLayer.snapshotLatency = Date.now() - menuLayer._t0; }
    }
    // Visible dès que la capture du fond est arrivée (~50 ms)
    visible: backdrop.pass
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "macos-lg-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    // La couche commence juste sous la pastille du titre (Tahoe : le menu est
    // collé à la pastille, ~1 pt plus bas) ; au-dessus, la barre reste
    // survolable (bascule d'un menu à l'autre). Positionnée depuis le haut de
    // l'écran (zones exclusives ignorées : un menu peut passer sur le Dock),
    // à la même place en plein écran.
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    // (512pixels, macOS 26.0 : barre de 30 pt, menu à y=31 pt)
    readonly property int top: Theme.menuBarHeight + 1
    margins.top: top
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Clic hors du menu : fermeture immédiate (AppKit ne fait un fondu qu'après
    // le choix d'un élément)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: menuLayer.controller.close(false)
    }

    Component.onCompleted: controller.registerLayer(screenName, menuLayer)

    // Glisser-relâcher depuis un titre de la barre (le pointeur appartient
    // encore à la barre) : (x, y) dans le repère de cette couche. Survole la
    // ligne sous le pointeur ; au relâchement, la choisit ou ferme le menu.
    function dragAt(x, y, release) {
        const root = loader.item;
        if (!root) return;
        const chain = [];
        for (let p = root; p; p = p.childPanel) chain.push(p);
        for (let k = chain.length - 1; k >= 0; k--) {
            const p = chain[k];
            const pt = p.mapFromItem(keys, x, y);
            if (pt.x < 0 || pt.y < 0 || pt.x >= p.width || pt.y >= p.height) continue;
            const i = p.rowIndexAt(pt.y);
            if (release) {
                if (i >= 0 && p.selectable(i) && !p.model[i].hasSubmenu) p.activate(i, false);
                else if (i < 0 || !p.selectable(i)) controller.close(false);
            } else if (i >= 0 && p.currentIndex !== i) {
                p.hover(i);
            }
            return;
        }
        // Hors des menus : plus de surbrillance ; relâché là, le menu se ferme
        if (release) controller.close(false);
        else if (chain[chain.length - 1].subIndex === -1) chain[chain.length - 1].currentIndex = -1;
    }

    // Saisie rapide : sélectionne l'élément suivant qui commence par la lettre
    function typeahead(ch) {
        const p = loader.item?.deepest();
        if (!p) return;
        const n = p.model.length;
        const norm = s => (s ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
        const c = norm(ch);
        for (let k = 1; k <= n; k++) {
            const i = (p.currentIndex + k + n) % n;
            if (p.selectable(i) && norm(p.model[i].text).startsWith(c)) {
                p.currentIndex = i;
                return;
            }
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const p = loader.item?.deepest();
            if (!p) return;
            switch (event.key) {
            case Qt.Key_Alt: menuLayer.controller.optionDown = true; break;
            case Qt.Key_Escape: p.keyEscape(); break;
            case Qt.Key_Down: p.move(1); break;
            case Qt.Key_Up: p.move(-1); break;
            case Qt.Key_Right: p.keyRight(); break;
            case Qt.Key_Left: p.keyLeft(); break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space: p.keyEnter(); break;
            default:
                if (event.text && event.text.trim() !== "" && !(event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)))
                    menuLayer.typeahead(event.text);
                else return;
            }
            event.accepted = true;
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt) {
                menuLayer.controller.optionDown = false;
                event.accepted = true;
            }
        }
    }

    // Menu racine (recréé à chaque ouverture pour repartir d'un état propre)
    Loader {
        id: loader
        active: false
        onLoaded: menuLayer.controller.rootPanel = item

        // Apparition instantanée, comme les menus AppKit (pas de fondu ni de
        // zoom) ; seule la fermeture après le choix d'un élément est animée.
        opacity: 1

        sourceComponent: MenuPanel {
            controller: menuLayer.controller
            items: menuLayer.controller.items
            handle: menuLayer.controller.handle
            areaWidth: menuLayer.width
            areaHeight: menuLayer.height
            originX: loader.x
            originY: loader.y
            Component.onCompleted: if (menuLayer.controller.keyboardOpened) selectFirst()
        }

        // (abscisse entière : texte et liseré nets)
        x: Math.round(Math.max(6, Math.min(menuLayer.controller.anchorX, menuLayer.width - (item?.width ?? 0) - 6)))
        y: 0

        NumberAnimation {
            id: fadeOut
            target: loader
            properties: "opacity"
            to: 0
            duration: 160
            easing.type: Easing.InOutQuad
            onFinished: {
                loader.active = false;
                menuLayer.controller.finish();
            }
        }
    }

    Connections {
        target: menuLayer.controller

        function onGenerationChanged() {
            fadeOut.stop();
            loader.active = false;
            if (menuLayer.controller.screenName !== menuLayer.screenName) return;
            loader.opacity = 1;
            // Focus clavier avant création : le champ du menu Aide le reprend
            keys.forceActiveFocus();
            loader.active = true;
        }

        function onClosingChanged() {
            if (menuLayer.controller.closing && loader.active) fadeOut.restart();
        }

        function onOpenIdChanged() {
            // Fermeture immédiate (sans fondu)
            if (!menuLayer.controller.isOpen && !menuLayer.controller.closing) {
                fadeOut.stop();
                loader.active = false;
            }
        }
    }
}
