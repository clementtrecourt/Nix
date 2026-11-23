import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common

// Couche plein écran (sous la barre) qui affiche le menu ouvert sur cet écran :
// elle capte le clavier (↑ ↓ ← → Entrée Échap, saisie rapide) et les clics
// hors du menu (qui ferment le menu sans atteindre l'app, comme sur macOS).
// Hyprland floute ce qui est derrière le verre du menu (namespace macos-menu,
// ignore_alpha : les zones transparentes ne sont pas floutées).
PanelWindow {
    id: menuLayer

    property var controller
    // Nom de l'écran (fixe : évite une boucle de liaison avec `screen`)
    property string screenName: ""

    visible: controller.screenName === screenName && (controller.isOpen || controller.closing)
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "macos-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    // Respecte la zone exclusive de la barre : la couche commence sous elle, la
    // barre reste survolable (bascule d'un menu à l'autre).
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    // En plein écran, la barre abandonne sa zone exclusive : on décale alors la
    // couche nous-mêmes sous la barre révélée (sinon le menu la recouvre et on
    // ne peut plus glisser d'un titre à l'autre).
    readonly property var bar: controller.bars[screenName] ?? null
    margins.top: bar && bar.fullscreen ? Theme.menuBarHeight : 0
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

        x: Math.max(6, Math.min(menuLayer.controller.anchorX, menuLayer.width - (item?.width ?? 0) - 6))
        y: 3

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
