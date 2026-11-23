import QtQuick
import qs.common

// Menu contextuel façon macOS Tahoe : plaque de verre aux coins arrondis,
// lignes de 24 px avec pictogramme (Tahoe en met devant presque chaque
// commande), surbrillance accent arrondie, séparateurs fins, coche, chevron de
// sous-menu. Au clic, la ligne clignote une fois avant l'action (détail AppKit).
//
// Clavier (comme AppKit) : Haut / Bas (en sautant séparateurs et lignes
// grisées), Entrée / Espace, Droite ouvre le sous-menu, Gauche le referme
// (signal `back`), une lettre saute à la commande suivante qui commence par
// elle. Le survol et le clavier partagent la même ligne courante.
//
// items : [{ text, icon?, enabled?, separator?, checked?, submenu?: [items], action? }]
Item {
    id: root

    property var items: []
    property int minWidth: 220
    // Ligne courante (surbrillance), -1 = aucune
    property int current: -1
    signal triggered(var item)
    // Une ligne à sous-menu est devenue courante (rowY : haut de la ligne,
    // repère du menu) ; item null = plus de sous-menu à montrer.
    signal submenuRequested(var item, real rowY)
    // Gauche / Échap dans un sous-menu
    signal back()

    readonly property bool hasIcons: items.some(i => !!i.icon)
    readonly property bool hasChecks: items.some(i => i.checked !== undefined)
    readonly property int padding: 5
    readonly property int rowHeight: 24
    readonly property int textX: (hasIcons || hasChecks) ? 34 : 12

    implicitWidth: Math.max(minWidth, measure.maxWidth + textX + 34)
    implicitHeight: col.implicitHeight + padding * 2

    function selectable(i) {
        const it = items[i];
        return !!it && !it.separator && it.enabled !== false;
    }
    function move(dir) {
        const n = items.length;
        let i = current;
        for (let k = 0; k < n; ++k) {
            i = i < 0 ? (dir > 0 ? 0 : n - 1) : (i + dir + n) % n;
            if (selectable(i)) { setCurrent(i); return; }
        }
    }
    function setCurrent(i) {
        current = i;
        const it = items[i];
        const row = rep.itemAt(i);
        root.submenuRequested(it && it.submenu ? it : null, row ? row.y + root.padding : 0);
    }
    function activate(i) {
        if (!selectable(i)) return;
        const it = items[i];
        if (it.submenu) { setCurrent(i); return; }
        rep.itemAt(i)?.flash();
    }
    // Saisie d'une lettre : prochaine commande qui commence par elle
    function jump(ch) {
        const c = ch.toLocaleLowerCase();
        const n = items.length;
        for (let k = 1; k <= n; ++k) {
            const i = ((current < 0 ? -1 : current) + k + n) % n;
            if (selectable(i) && (items[i].text ?? "").toLocaleLowerCase().startsWith(c)) {
                setCurrent(i);
                return;
            }
        }
    }

    Keys.onUpPressed: move(-1)
    Keys.onDownPressed: move(1)
    Keys.onReturnPressed: activate(current)
    Keys.onEnterPressed: activate(current)
    Keys.onSpacePressed: activate(current)
    Keys.onLeftPressed: root.back()
    Keys.onPressed: event => {
        if (event.text.length === 1 && /\S/.test(event.text) && !(event.modifiers & (Qt.ControlModifier | Qt.MetaModifier))) {
            root.jump(event.text);
            event.accepted = true;
        }
    }

    // Largeur du libellé le plus long
    Item {
        id: measure
        visible: false
        property real maxWidth: {
            let m = 0;
            for (let i = 0; i < rep.count; ++i) {
                const it = rep.itemAt(i);
                if (it && it.textWidth > m) m = it.textWidth;
            }
            return m;
        }
    }

    SessionGlass {
        anchors.fill: parent
        radius: Theme.radiusMenu
        // Clair : blanc laiteux comme les menus Tahoe ; sombre : jeton du thème
        tint: Theme.dark ? Theme.menuBackground : Qt.rgba(0.97, 0.97, 0.98, 0.80)
        shadowBlur: 0.9
        shadowOffset: 6
    }

    Column {
        id: col
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2

        Repeater {
            id: rep
            model: root.items

            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool sep: !!modelData.separator
                readonly property bool on: modelData.enabled !== false && !sep
                readonly property real textWidth: label.implicitWidth
                readonly property bool lit: on && (root.current === index || flashing) && !blink.blinkOff
                property bool flashing: false
                width: col.width
                height: sep ? 11 : root.rowHeight

                function flash() {
                    flashing = true;
                    blink.restart();
                }

                // Séparateur
                Rectangle {
                    visible: row.sep
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    width: parent.width - 20
                    height: 1
                    color: Theme.separator
                }

                // Surbrillance
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMenuItem
                    color: Theme.menuHighlight
                    visible: row.lit
                }

                Symbol {
                    visible: !row.sep && !!row.modelData.icon && !row.modelData.checked
                    name: row.modelData.icon ?? ""
                    size: 15
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: row.lit ? Theme.menuHighlightText : (row.on ? Theme.label : Theme.labelTertiary)
                }
                // Coche (remplace le pictogramme quand la commande est cochée)
                Symbol {
                    visible: !row.sep && row.modelData.checked === true
                    name: "checkmark"
                    size: 12
                    x: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: row.lit ? Theme.menuHighlightText : (row.on ? Theme.label : Theme.labelTertiary)
                }

                Text {
                    id: label
                    visible: !row.sep
                    text: row.modelData.text ?? ""
                    x: root.textX
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    color: row.lit ? Theme.menuHighlightText : (row.on ? Theme.label : Theme.labelTertiary)
                }

                Symbol {
                    visible: !row.sep && !!row.modelData.submenu
                    name: "chevron.right"
                    size: 11
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    color: label.color
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: row.on
                    onEntered: root.setCurrent(row.index)
                    // On ne perd la ligne qu'en sortant vers une autre ligne ou
                    // hors du menu (pas en entrant dans son sous-menu)
                    onExited: if (root.current === row.index && !row.modelData.submenu) root.current = -1
                    onClicked: root.activate(row.index)
                }

                // Clignotement de validation (éteint 70 ms puis rallumé 70 ms)
                SequentialAnimation {
                    id: blink
                    property bool blinkOff: false
                    PropertyAction { target: blink; property: "blinkOff"; value: true }
                    PauseAnimation { duration: 70 }
                    PropertyAction { target: blink; property: "blinkOff"; value: false }
                    PauseAnimation { duration: 70 }
                    ScriptAction {
                        script: {
                            row.flashing = false;
                            root.triggered(row.modelData);
                        }
                    }
                }
            }
        }
    }
}
