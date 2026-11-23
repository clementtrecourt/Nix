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
    id: layer

    property var controller

    visible: controller.screenName === screen?.name && (controller.isOpen || controller.closing)
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "macos-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    // Respecte la zone exclusive de la barre : la couche commence sous elle, la
    // barre reste survolable (bascule d'un menu à l'autre).
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Clic hors du menu : fermeture
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: layer.controller.close(true)
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
            case Qt.Key_Escape:
                if (p.parentPanel) p.parentPanel.closeSub();
                else layer.controller.close(true);
                break;
            case Qt.Key_Down: p.move(1); break;
            case Qt.Key_Up: p.move(-1); break;
            case Qt.Key_Right: p.keyRight(); break;
            case Qt.Key_Left: p.keyLeft(); break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space: p.keyEnter(); break;
            default:
                if (event.text && event.text.trim() !== "" && !(event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)))
                    layer.typeahead(event.text);
                else return;
            }
            event.accepted = true;
        }
    }

    // Menu racine (recréé à chaque ouverture pour repartir d'un état propre)
    Loader {
        id: loader
        active: false

        // Apparition : fondu + très léger zoom depuis le haut (≈ 100 ms) ;
        // pas d'animation quand on glisse d'un titre à l'autre.
        property bool animateIn: true
        opacity: 1
        transformOrigin: Item.Top

        sourceComponent: MenuPanel {
            controller: layer.controller
            items: layer.controller.items
            handle: layer.controller.handle
            areaWidth: layer.width
            areaHeight: layer.height
            originX: loader.x
            originY: loader.y
            Component.onCompleted: if (layer.controller.keyboardOpened) selectFirst()
        }

        x: Math.max(6, Math.min(layer.controller.anchorX, layer.width - (item?.width ?? 0) - 6))
        y: 3

        NumberAnimation {
            id: fadeIn
            target: loader
            properties: "opacity"
            from: 0
            to: 1
            duration: 110
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: scaleIn
            target: loader
            properties: "scale"
            from: 0.97
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: fadeOut
            target: loader
            properties: "opacity"
            to: 0
            duration: 160
            easing.type: Easing.InOutQuad
            onFinished: {
                loader.active = false;
                layer.controller.finish();
            }
        }
    }

    Connections {
        target: layer.controller

        function onGenerationChanged() {
            const wasShown = loader.active && !fadeOut.running && layer.controller.screenName === layer.screen?.name;
            fadeOut.stop();
            loader.active = false;
            if (layer.controller.screenName !== layer.screen?.name) return;
            loader.opacity = 1;
            loader.scale = 1;
            // Focus clavier avant création : le champ du menu Aide le reprend
            keys.forceActiveFocus();
            loader.active = true;
            if (!wasShown) {
                fadeIn.restart();
                scaleIn.restart();
            }
        }

        function onClosingChanged() {
            if (layer.controller.closing && loader.active) fadeOut.restart();
        }

        function onOpenIdChanged() {
            // Fermeture immédiate (sans fondu)
            if (!layer.controller.isOpen && !layer.controller.closing) {
                fadeOut.stop();
                loader.active = false;
            }
        }
    }
}
