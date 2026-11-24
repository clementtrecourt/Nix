import QtQuick
import Quickshell
import qs.common

// Menu déroulant Tahoe : plaque de verre (rayon 14), lignes de 24 pt, pictos à
// gauche, raccourcis alignés à droite, sous-menus en cascade (récursif).
// Contenu : `items` (tableau JS, voir Menus.qml) ou `handle` (menu DBus SNI).
Item {
    id: panel

    property var items: []
    property var handle: null
    property var controller
    // Menu parent (null pour le menu racine)
    property var parentPanel: null
    // Position absolue du menu dans la couche et taille de l'écran (pour que
    // les sous-menus s'ouvrent du bon côté et restent visibles)
    property real originX: 0
    property real originY: 0
    property real areaWidth: 1920
    property real areaHeight: 1080

    property int currentIndex: -1
    property bool flashing: false
    property bool flashOff: false
    // Index de l'élément dont le sous-menu est ouvert (-1 : aucun)
    property int subIndex: -1
    readonly property var childPanel: subLoader.item

    // Requête du champ de recherche (menu Aide)
    property string query: ""
    // Sections dépliables ouvertes (clé : texte de l'élément)
    property var expanded: ({})

    // ---- Modèle normalisé ----
    QsMenuOpener {
        id: opener
        menu: panel.handle
    }

    function stripMnemonic(t) { return (t ?? "").replace(/_(_?)/g, (m, u) => u ? "_" : ""); }

    function normalize(e) {
        if (!e) return { separator: true };
        // Entrée DBus (QsMenuEntry)
        if (e.isSeparator !== undefined) {
            if (e.isSeparator) return { separator: true };
            const checkable = e.buttonType !== QsMenuButtonType.None;
            const ent = e;
            return {
                text: stripMnemonic(e.text), enabled: e.enabled,
                iconSource: e.icon ?? "", checkable: checkable,
                checked: checkable && e.checkState === Qt.Checked,
                hasSubmenu: e.hasChildren, handle: e.hasChildren ? ent : null,
                action: () => ent.triggered()
            };
        }
        const n = Object.assign({}, e);
        if (e.shortcut) {
            n.mods = e.shortcut[0] ?? "";
            const k = e.shortcut[1] ?? "";
            n.globe = k.startsWith("🌐");
            n.key = n.globe ? k.slice(2) : k;
        }
        n.hasSubmenu = !!e.submenu;
        return n;
    }

    function toggleExpanded(key) {
        const x = Object.assign({}, expanded);
        x[key] = !x[key];
        expanded = x;
    }

    readonly property var model: {
        let src;
        if (handle) src = opener.children.values;
        else src = items ?? [];
        let out = [];
        for (const e of src) {
            const n = normalize(e);
            out.push(n);
            // Section dépliable ouverte : ses éléments suivent, en place
            if (n.disclosure) {
                n.expanded = !!expanded[n.text];
                if (n.expanded) for (const c of (n.children ?? [])) out.push(normalize(c));
            }
        }
        // Menu Aide : résultats de recherche parmi les menus de l'app
        if (out.length > 0 && out[0].search && query.trim() !== "") {
            // (insensible à la casse et aux accents, comme macOS)
            const fold = t => (t ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
            const q = fold(query.trim());
            const found = (out[0].provider ? out[0].provider() : [])
                .filter(e => fold(e.text).includes(q))
                .slice(0, 12)
                .map(e => normalize(Object.assign({}, e, { shortcut: null, pathText: e.path.join(" ▸ ") })));
            out = [out[0], { header: true, text: "Menu Items" }].concat(
                found.length ? found : [{ text: "No Results", enabled: false }]);
        }
        // Pas de séparateur en tête / en fin / en double
        const clean = [];
        for (const e of out) {
            if (e.separator && (clean.length === 0 || clean[clean.length - 1].separator)) continue;
            clean.push(e);
        }
        while (clean.length && clean[clean.length - 1].separator) clean.pop();
        // Tahoe : le retrait du texte se décide par SECTION (entre deux
        // séparateurs) : si un élément de la section a un picto, tous les
        // libellés de la section s'alignent après la colonne des pictos ; sinon
        // ils restent à gauche (menus Safari / Loopback de macOS 26)
        let start = 0;
        for (let i = 0; i <= clean.length; i++) {
            if (i < clean.length && !clean[i].separator) continue;
            const has = clean.slice(start, i).some(e => !!(e.icon || e.iconSource));
            for (let k = start; k < i; k++) clean[k].indent = has;
            start = i + 1;
        }
        return clean;
    }

    // ---- Géométrie des colonnes ----
    FontMetrics {
        id: fm
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }
    readonly property var metrics: {
        // 1er passage : colonnes communes (picto à gauche, raccourcis)
        let mw = 0, kw = 0, gutter = false, search = false;
        for (const e of model) {
            if (e.separator) continue;
            if (e.search) { search = true; continue; }
            if (e.mods || e.globe) {
                // Modificateurs espacés de 2 pt, globe de 12 pt (voir MenuRow)
                const chars = Array.from(e.mods ?? "");
                let m = chars.reduce((a, ch) => a + fm.advanceWidth(ch), 0) + (e.globe ? 12 : 0);
                m += 2 * Math.max(0, chars.length + (e.globe ? 1 : 0) - 1);
                mw = Math.max(mw, m);
            }
            if (e.key) kw = Math.max(kw, fm.advanceWidth(e.key));
            if (e.checked || e.checkable || e.minimized) gutter = true;
        }
        // Colonnes (pt, depuis le bord du menu), relevées sur les captures 2x
        // de Tahoe : texte seul à 16, picto centré à 24 et texte à 38 ; si le
        // menu a des coches, une gouttière (coche centrée à 13,5) décale tout :
        // picto à 31,5, texte après picto à 47 (Fenêtre du Finder).
        const cols = gutter ? { check: 13, plain: 25, icon: 31, iconText: 47 }
                            : { check: 13, plain: 16, icon: 24, iconText: 38 };
        const keys = kw > 0 ? 22 + Math.ceil(mw) + 3 + Math.ceil(kw) : 0;
        // 2e passage : largeur nécessaire par ligne. Marge droite : 14 pt +
        // respiration (macOS laisse au moins ~20 pt après le texte).
        let w = 0;
        for (const e of model) {
            if (e.separator || e.search) continue;
            let need = 1 + (e.header ? cols.plain : e.network ? 46 : e.indent ? cols.iconText : cols.plain)
                + fm.advanceWidth(e.text ?? "") * (e.header ? 0.9 : 1) + 24 + keys;
            if (e.pathText) need += fm.advanceWidth(e.pathText) * (e.info ? 1 : 0.85) + 12;
            if (e.hasSubmenu || e.disclosure) need += 16;
            if (e.toggle !== undefined && e.toggle !== null) need += 40;
            if (e.locked) need += 20;
            if (e.bold) need += 6;
            w = Math.max(w, need);
        }
        if (search) w = Math.max(w, 260);
        return { cols: cols, modsW: Math.ceil(mw) + 3, keyW: Math.ceil(kw), width: Math.ceil(Math.max(w, 140)) };
    }

    width: metrics.width
    height: column.implicitHeight + 10

    // ---- Rendu ----
    // Mesures Tahoe (captures 2x, menus Apple / Finder / Safari de macOS 26) :
    // rayon ~12,5-13 pt, ombre douce (~0 3 20 pt, 18 %), filet extérieur
    // sombre d'un demi-point sous le liseré clair du verre.
    readonly property real radius: 13

    // Matériau : le fond flouté (nettement plus que les autres verres) est
    // ramené vers une luminance cible en GARDANT sa couleur : relevé sur Tahoe
    // clair, #4170BA derrière -> #C9E8FF, blanc derrière -> #F8F8F8 ; sombre,
    // fond très sombre -> ~#1D1D1D, fond rouge vif -> rouge très sombre.
    readonly property color glassTint: Theme.dark ? Qt.rgba(0.18, 0.18, 0.19, 0.86)
                                                  : Qt.rgba(0.973, 0.973, 0.973, 0.76)

    // Repli sans réfraction (pas de capture) : teinte posée par un Rectangle
    // (la teinte du shader de Glass y serait prémultipliée deux fois)
    Rectangle {
        anchors.fill: parent
        radius: panel.radius
        color: Theme.menuBackground
        antialiasing: true
        visible: !menuGlass.refracting
    }
    Glass {
        id: menuGlass
        anchors.fill: parent
        radius: panel.radius
        tint: refracting ? panel.glassTint : "transparent"
        adaptive: 0
        blur: 12
        saturation: 1.2
        // (la lentille de bord reste discrète sur un menu : verre « dense »)
        refraction: bezel * 0.8
        shadowBlur: 0.72
        shadowOffset: 3
        shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.36 : 0.18)
        rimColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.85)
        glowColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.20)
        edgeDarken: 0.08
    }
    // Filet extérieur d'un demi-point (sombre), qui détache le menu du fond
    Rectangle {
        anchors.fill: parent
        anchors.margins: -0.5
        radius: panel.radius + 0.5
        color: "transparent"
        antialiasing: true
        border.width: 0.75
        border.color: Theme.dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.16)
    }

    Column {
        id: column
        y: 5
        width: parent.width

        Repeater {
            id: rep
            model: panel.model
            delegate: Loader {
                id: slot
                required property var modelData
                required property int index
                width: column.width
                sourceComponent: modelData.search ? searchComp : rowComp

                Component {
                    id: rowComp
                    MenuRow {
                        entry: slot.modelData
                        highlighted: panel.currentIndex === slot.index
                        muted: panel.subIndex === slot.index && !!panel.childPanel && panel.childPanel.currentIndex >= 0
                        flashOff: panel.flashOff
                        cols: panel.metrics.cols
                        expanded: !!slot.modelData.expanded
                        modsW: panel.metrics.modsW
                        keyW: panel.metrics.keyW
                        onHovered: panel.hover(slot.index)
                        onClicked: panel.activate(slot.index, false)
                    }
                }
                Component {
                    id: searchComp
                    MenuSearchField {
                        panel: panel
                    }
                }
            }
        }
    }

    // ---- Comportement ----
    function rowAt(i) { return rep.itemAt(i)?.item ?? null; }
    // Index de la ligne à l'ordonnée y (repère du menu), -1 si aucune
    function rowIndexAt(y) {
        for (let i = 0; i < rep.count; i++) {
            const r = rep.itemAt(i);
            if (r && y >= column.y + r.y && y < column.y + r.y + r.height) return i;
        }
        return -1;
    }
    function selectable(i) {
        const e = model[i];
        return !!e && !e.separator && !e.header && !e.info && !e.search && e.enabled !== false;
    }

    // Survol : surbrillance, ouverture différée du sous-menu
    function hover(i) {
        if (flashing) return;
        // (un élément grisé ne s'allume pas)
        currentIndex = selectable(i) ? i : -1;
        if (model[i]?.hasSubmenu && selectable(i)) {
            if (subIndex !== i) { subTimer.target = i; subTimer.restart(); }
        } else if (subIndex !== -1) {
            subTimer.target = -1;
            subTimer.restart();
        }
    }

    Timer {
        id: subTimer
        property int target: -1
        interval: 110
        onTriggered: {
            if (target === -1) panel.closeSub();
            else if (panel.currentIndex === target) panel.openSub(target, false);
        }
    }

    function openSub(i, viaKeyboard) {
        const e = model[i];
        if (!e || !e.hasSubmenu || !selectable(i)) return;
        if (subIndex === i && subLoader.item) {
            if (viaKeyboard) subLoader.item.selectFirst();
            return;
        }
        subLoader.active = false;
        subIndex = i;
        subLoader.viaKeyboard = viaKeyboard;
        subLoader.setSource(Qt.resolvedUrl("MenuPanel.qml"), {
            controller: panel.controller,
            parentPanel: panel,
            items: typeof e.submenu === "function" ? e.submenu() : (e.submenu ?? []),
            handle: e.handle ?? null,
            areaWidth: panel.areaWidth,
            areaHeight: panel.areaHeight
        });
        subLoader.active = true;
    }
    function closeSub() {
        subLoader.active = false;
        subIndex = -1;
    }

    // Clic / Entrée
    function activate(i, viaKeyboard) {
        if (flashing || !selectable(i)) return;
        const e = model[i];
        if (e.hasSubmenu) { openSub(i, viaKeyboard); return; }
        currentIndex = i;
        // Section dépliable : s'ouvre / se replie sur place
        if (e.disclosure) { toggleExpanded(e.text); return; }
        // Interrupteur : bascule sur place, le menu reste ouvert
        if (e.keepOpen) {
            const r = rowAt(i);
            if (r) r.toggleOn = !r.toggleOn;
            if (typeof e.action === "function") e.action();
            return;
        }
        flashing = true;
        flashStep.step = 0;
        flashStep.entry = e;
        flashStep.start();
    }

    // Clignotement de confirmation (éteint / rallumé) puis action + fondu
    Timer {
        id: flashStep
        property int step: 0
        property var entry: null
        interval: 65
        repeat: true
        onTriggered: {
            step++;
            if (step === 1) panel.flashOff = true;
            else if (step === 2) panel.flashOff = false;
            else {
                stop();
                panel.controller.trigger(entry);
            }
        }
    }

    // ---- Clavier ----
    // Menu qui reçoit le clavier : le plus profond qui a une sélection. Un
    // sous-menu ouvert au survol mais sans élément sélectionné laisse la main
    // au menu parent (→ y entre, ↑ ↓ le referment), comme sur macOS.
    function deepest() {
        return childPanel && childPanel.currentIndex >= 0 ? childPanel.deepest() : panel;
    }
    function move(d) {
        const n = model.length;
        if (n === 0) return;
        let i = currentIndex;
        for (let k = 0; k < n; k++) {
            i = i < 0 ? (d > 0 ? 0 : n - 1) : (i + d + n) % n;
            if (selectable(i)) {
                currentIndex = i;
                if (subIndex !== -1 && subIndex !== i) closeSub();
                return;
            }
        }
    }
    // Échap : referme le sous-menu ouvert, sinon remonte d'un niveau
    function keyEscape() {
        if (childPanel) closeSub();
        else if (parentPanel) parentPanel.closeSub();
        else panel.controller.close(false);   // Échap : fermeture immédiate
    }
    function selectFirst() { currentIndex = -1; move(1); }
    function keyRight() {
        const e = currentIndex >= 0 ? model[currentIndex] : null;
        if (e?.disclosure) { if (!e.expanded) toggleExpanded(e.text); }
        else if (e?.hasSubmenu) openSub(currentIndex, true);
        else panel.controller.step(1);
    }
    function keyLeft() {
        if (parentPanel) parentPanel.closeSub();
        else panel.controller.step(-1);
    }
    function keyEnter() { if (currentIndex >= 0) activate(currentIndex, true); }

    // ---- Sous-menu ----
    // Chargé par URL : un composant ne peut pas s'instancier lui-même
    // directement (récursion interdite), un Loader par chemin le peut.
    Loader {
        id: subLoader
        active: false
        property bool viaKeyboard: false

        readonly property real rowY: {
            const r = rep.count > 0 ? rep.itemAt(panel.subIndex) : null;
            return r ? column.y + r.y : 0;
        }

        onLoaded: {
            const c = item;
            // À droite du parent, ou à gauche s'il n'y a plus de place
            // (Tahoe : le sous-menu chevauche le parent de ~4 pt)
            c.x = Qt.binding(() => (panel.originX + panel.width + c.width + 6 > panel.areaWidth) ? -c.width + 4 : panel.width - 4);
            // Première ligne alignée sur la ligne parente, sans sortir de l'écran
            c.y = Qt.binding(() => Math.max(-panel.originY + 4, Math.min(subLoader.rowY - 5, panel.areaHeight - panel.originY - c.height - 6)));
            c.originX = Qt.binding(() => panel.originX + c.x);
            c.originY = Qt.binding(() => panel.originY + c.y);
            if (viaKeyboard) c.selectFirst();
        }
    }

    // La souris qui quitte le menu efface la surbrillance (sauf sous-menu ouvert)
    HoverHandler {
        onHoveredChanged: if (!hovered && panel.subIndex === -1 && !panel.flashing) panel.currentIndex = -1
    }
}
