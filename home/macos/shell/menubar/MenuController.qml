import QtQuick
import qs.services

// État des menus déroulants de la barre (un seul ouvert à la fois, tous écrans
// confondus). Les barres (Bar.qml) ouvrent les menus ; la couche MenuLayer.qml
// de l'écran concerné les dessine et capte clavier / clics extérieurs.
QtObject {
    id: root

    // Identifiant du menu ouvert : "logo", "app", "file", "edit", "view",
    // "window", "help", "tray:<id>" ; "" = fermé.
    property string openId: ""
    // Écran (nom de sortie) où le menu est affiché
    property string screenName: ""
    // Abscisse (repère écran) du bord gauche de la pastille du titre
    property real anchorX: 0
    // Largeur de la pastille (pour aligner le menu à droite près du bord)
    property real anchorWidth: 0
    // Contenu : tableau d'éléments (voir Menus.qml) ou menu DBus (barre d'état)
    property var items: []
    property var handle: null
    // Vrai pendant le fondu de fermeture (la couche reste affichée)
    property bool closing: false
    // Ouvert au clavier : le premier élément est présélectionné
    property bool keyboardOpened: false
    // Incrémenté à chaque ouverture (relance l'animation d'apparition)
    property int generation: 0

    readonly property bool isOpen: openId !== ""
    // Menu racine affiché (MenuPanel), pour le pilotage de debug
    property var rootPanel: null

    // Barres enregistrées par écran (pour la navigation ← / → entre titres)
    property var bars: ({})

    signal closed()

    function registerBar(name, bar) {
        const b = Object.assign({}, bars);
        b[name] = bar;
        bars = b;
    }

    function open(id, screen, x, w, content, viaKeyboard) {
        closing = false;
        screenName = screen;
        anchorX = x;
        anchorWidth = w;
        if (content && content.handle !== undefined) {
            items = [];
            handle = content.handle;
        } else {
            handle = null;
            items = content ?? [];
        }
        keyboardOpened = !!viaKeyboard;
        openId = id;
        generation++;
        if (ShellState.openPanel !== "menubar") ShellState.open("menubar");
    }

    // Ferme le menu. `animated` : fondu de 150 ms (choix d'un élément, clic hors).
    function close(animated) {
        if (!isOpen && !closing) return;
        closing = !!animated;
        openId = "";
        keyboardOpened = false;
        if (ShellState.openPanel === "menubar") ShellState.close();
        if (!closing) finish();
        else safety.restart();
    }

    // Filet de sécurité : termine la fermeture si aucune couche n'a animé
    property Timer safety: Timer {
        interval: 400
        onTriggered: if (root.closing) root.finish()
    }

    // Un autre panneau (Control Center, Spotlight…) s'ouvre : le menu se ferme
    property Connections shellWatch: Connections {
        target: ShellState
        function onOpenPanelChanged() {
            if (ShellState.openPanel !== "menubar" && root.isOpen) root.close(false);
        }
    }

    function finish() {
        closing = false;
        items = [];
        handle = null;
        root.closed();
    }

    // Exécute l'action d'un élément après le clignotement de sélection : le menu
    // se ferme d'abord (fondu) puis l'action part, comme sur macOS.
    function trigger(item) {
        close(true);
        if (item && typeof item.action === "function") Qt.callLater(item.action);
    }

    // Navigation ← / → entre les titres de la barre (menus d'app uniquement)
    function step(delta) {
        const bar = bars[screenName];
        if (!bar || openId.startsWith("tray:")) return;
        bar.openSibling(openId, delta);
    }
}
