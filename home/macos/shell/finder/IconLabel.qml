import QtQuick
import qs.common

// Nom d'un élément en présentation Icônes, comme le Finder de Tahoe : retour
// à la ligne aux mots (au caractère seulement si le premier mot ne tient pas),
// deux lignes au plus ; si le nom ne tient pas, la 2e ligne est tronquée AU
// MILIEU et garde la fin du nom (« Furniture / Collecti…posal.pdf »,
// capture Apple mchlp1745). Qt ignore ElideMiddle en multiligne : les deux
// lignes sont donc calculées ici (FontMetrics) et affichées sans retour auto.
// Pastille d'accent derrière le nom quand l'élément est choisi.
Rectangle {
    id: root

    property string name: ""
    property real maxWidth: FStyle.iconTextW
    property int fontSize: FStyle.iconText
    property bool selected: false
    property bool active: true

    // Calculé une fois le composant complet (FontMetrics prêt) : sinon une
    // cellule recyclée de la grille peut garder le nom sur une seule ligne
    property bool _ready: false
    Component.onCompleted: _ready = true
    readonly property var lines: _ready ? _layout(name, maxWidth, fm.font) : [""]
    readonly property alias textItem: label

    width: label.implicitWidth + 8
    height: label.implicitHeight + 2
    radius: 4
    color: selected ? (active ? FStyle.selection : FStyle.selectionInactive) : "transparent"

    FontMetrics {
        id: fm
        font.family: Theme.font
        font.pixelSize: root.fontSize
    }

    function _w(s) { return fm.advanceWidth(s); }
    // Découpe en jetons : on peut couper après une espace ou un trait d'union
    function _tokens(s) {
        const out = [];
        let cur = "";
        for (let i = 0; i < s.length; ++i) {
            const ch = s[i];
            cur += ch;
            const next = s[i + 1];
            if ((ch === " " || ch === "-" || ch === " " || ch === "_") && next !== " ") { out.push(cur); cur = ""; }
        }
        if (cur) out.push(cur);
        return out;
    }
    function _layout(s, maxW, _font) {
        if (!s) return [""];
        if (_w(s) <= maxW) return [s];
        const toks = _tokens(s);
        let l1 = "";
        for (const t of toks) {
            if (_w((l1 + t).replace(/\s+$/, "")) <= maxW) l1 += t;
            else break;
        }
        if (!l1) {
            // Premier mot trop long : coupe au caractère
            let k = 1;
            while (k < s.length && _w(s.slice(0, k + 1)) <= maxW) ++k;
            l1 = s.slice(0, k);
        }
        let rest = s.slice(l1.length).replace(/^\s+/, "");
        l1 = l1.replace(/\s+$/, "");
        if (!rest) return [l1];
        if (_w(rest) > maxW) rest = fm.elidedText(rest, Qt.ElideMiddle, maxW);
        return [l1, rest];
    }

    Text {
        id: label
        x: 4
        y: 1
        text: root.lines.join("\n")
        font: fm.font
        color: root.selected && root.active ? "white" : Theme.label
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.NoWrap
        textFormat: Text.PlainText
    }
}
