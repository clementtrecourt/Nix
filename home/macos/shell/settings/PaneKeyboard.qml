import QtQuick
import qs.common

// Keyboard (Tahoe 26, Apple kbdm162) : vitesse de répétition et délai avant
// répétition (crans Off/Slow…Fast et Long…Short -> input:repeat_rate /
// input:repeat_delay de Hyprland), sources de saisie (input:kb_layout,
// feuille Edit…). Appliqué à chaud et persisté (Prefs.setHypr).
PaneBase {
    id: root

    readonly property var rates: [0, 2, 6, 12, 20, 30, 45, 60]
    readonly property var delays: [2000, 1500, 1000, 600, 400, 250]
    function nearest(list, v) {
        let bi = 0;
        for (let i = 0; i < list.length; ++i) if (Math.abs(list[i] - v) < Math.abs(list[bi] - v)) bi = i;
        return bi;
    }
    readonly property var layouts: [
        ["us", "U.S."], ["gb", "British"], ["fr", "French"], ["fr(mac)", "French – Numerical"], ["de", "German"], ["es", "Spanish"],
        ["it", "Italian"], ["ch", "Swiss German"], ["ch(fr)", "Swiss French"], ["be", "Belgian"], ["ca", "Canadian French – CSA"],
        ["us(intl)", "U.S. International – PC"], ["us(dvorak)", "Dvorak"], ["us(colemak)", "Colemak"], ["pt", "Portuguese"],
        ["br", "Brazilian"], ["nl", "Dutch"], ["se", "Swedish"], ["no", "Norwegian"], ["dk", "Danish"], ["fi", "Finnish"],
        ["pl", "Polish"], ["ru", "Russian"], ["jp", "Japanese"]
    ]
    // « fr,us » + variantes « ,mac » -> ["fr(mac)", "us"]
    readonly property var current: {
        const l = String(Prefs.hypr("input:kb_layout", "us") || "us").split(",");
        const v = String(Prefs.hypr("input:kb_variant", "") || "").split(",");
        return l.map((x, i) => v[i] ? x + "(" + v[i] + ")" : x).filter(x => x);
    }
    function layoutName(code) {
        const k = layouts.find(l => l[0] === code);
        if (k) return k[1];
        const base = layouts.find(l => l[0] === code.split(/[_(]/)[0]);
        const v = (code.match(/\((.*)\)$/) ?? ["", ""])[1].toUpperCase();
        return base ? base[1] + (v ? " – " + v : "") : code;
    }
    function setLayouts(list) {
        const ls = list.map(c => c.replace(/\(.*\)$/, "")), vs = list.map(c => (c.match(/\((.*)\)$/) ?? ["", ""])[1]);
        Prefs.setHypr("input:kb_layout", ls.join(","));
        Prefs.setHypr("input:kb_variant", vs.join(","));
    }

    SGroup {
        SRow {
            title: "Key repeat rate"
            minHeight: 54
            SSlider {
                width: 230
                ticks: 8
                minLabel: "Off"; maxLabel: "Fast"
                value: root.nearest(root.rates, Prefs.hypr("input:repeat_rate", 25)) / 7
                onReleased: (v) => Prefs.setHypr("input:repeat_rate", root.rates[Math.round(v * 7)])
            }
        }
        SRow {
            title: "Delay until repeat"
            minHeight: 54
            SSlider {
                width: 230
                ticks: 6
                minLabel: "Long"; maxLabel: "Short"
                value: root.nearest(root.delays, Prefs.hypr("input:repeat_delay", 600)) / 5
                onReleased: (v) => Prefs.setHypr("input:repeat_delay", root.delays[Math.round(v * 5)])
            }
        }
    }
    SGroup {
        SRow {
            title: "Press 🌐︎ key to"
            dimmed: true
            SPopUp { options: [{ text: "Change Input Source", value: "input" }, { text: "Show Emoji & Symbols", value: "emoji" }, { text: "Start Dictation", value: "dictation" }, { text: "Do Nothing", value: "none" }]; value: "emoji"; enabledPopUp: false }
        }
        SRow {
            title: "Keyboard navigation"
            subtitle: "Use keyboard navigation to move focus between controls. Press the Tab key to move focus forward and Shift Tab to move focus backward."
            SSwitch { checked: !!Prefs.v.keyboardNavigation; onToggled: (on) => Prefs.set("keyboardNavigation", on) }
        }
    }
    Item {
        width: parent.width
        height: 28
        Row {
            anchors.right: parent.right
            y: 4
            spacing: 10
            SButton { text: "Keyboard Shortcuts…"; enabledButton: false }
        }
    }
    SSection { text: "Text Input" }
    SGroup {
        SRow {
            title: "Input Sources"
            subtitle: root.current.map(c => root.layoutName(c)).join(", ")
            SButton { text: "Edit…"; onClicked: { sheet.sel = root.current.slice(); sheet.shown = true; } }
        }
        SRow {
            title: "Text Replacements…"
            dimmed: true
            SButton { text: "Text Replacements…"; enabledButton: false }
        }
    }
    SSection { text: "Dictation" }
    SGroup {
        SRow {
            title: "Dictation"
            subtitle: "Use Dictation wherever you can type text. To start dictating, use the shortcut or select Start Dictation from the Edit menu."
            dimmed: true
            SSwitch { checked: false; enabledSwitch: false }
        }
    }
    Item {
        width: parent.width
        height: 28
        HelpButton { anchors.right: parent.right; y: 4; url: "https://support.apple.com/guide/mac-help/kbdm162/mac" }
    }

    SSheet {
        id: sheet
        sheetWidth: 440
        cancelText: "Cancel"
        doneEnabled: sel.length > 0
        property var sel: []
        onDone: root.setLayouts(sel)
        body: Component {
            Column {
                width: parent ? parent.width : 0
                spacing: SStyle.groupSpacing
                Text { text: "Input Sources"; font.family: Theme.font; font.pixelSize: SStyle.body; font.weight: Font.Bold; color: SStyle.label }
                SGroup {
                    Repeater {
                        model: root.layouts
                        SRow {
                            required property var modelData
                            title: modelData[1]
                            symbol: "keyboard"
                            SCheckBox {
                                checked: sheet.sel.includes(modelData[0])
                                onToggled: (on) => {
                                    const l = sheet.sel.filter(x => x !== modelData[0]);
                                    if (on) l.push(modelData[0]);
                                    sheet.sel = l;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
