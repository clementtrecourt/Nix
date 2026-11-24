import QtQuick
import Quickshell
import qs.common
import qs.controlcenter as CC
import qs.session as Session

// Displays (Tahoe 26, Apple mh40768) : vignettes des écrans (choix de l'écran
// réglé, Arrange… quand il y en a plusieurs), Use as (écran principal, étendu,
// recopie), résolution façon macOS (« Larger Text … Default » = échelles
// HiDPI de Hyprland ; « Show all resolutions » = modes de l'écran), fréquence,
// rotation, Night Shift… — appliqué par `hyprctl keyword monitor` et persisté
// (Prefs -> ~/.config/hypr/macos-settings.conf).
PaneBase {
    id: root

    property var monitors: []
    property string selected: ""
    readonly property var mon: monitors.find(m => m.name === selected) ?? monitors[0] ?? null
    readonly property var others: monitors.filter(m => m.name !== (mon?.name ?? ""))
    property bool showAll: false

    function refresh() { probe.running = true; }
    Component.onCompleted: refresh()
    ProcessText {
        id: probe
        command: ["hyprctl", "monitors", "all", "-j"]
        onDone: (t) => {
            try {
                root.monitors = JSON.parse(t).filter(m => !m.disabled || m.mirrorOf !== "none");
                if (!root.monitors.some(m => m.name === root.selected)) root.selected = root.monitors.find(m => m.focused)?.name ?? root.monitors[0]?.name ?? "";
            } catch (e) {}
        }
    }
    Timer { id: later; interval: 600; onTriggered: root.refresh() }

    function nameOf(m) {
        if (!m) return "";
        const d = (m.model || m.description || m.name).replace(/\s+0x[0-9A-F]+$/i, "");
        return d || m.name;
    }
    function modes(m) {
        const out = [];
        for (const s of m?.availableModes ?? []) {
            const r = s.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
            if (r) out.push({ w: Number(r[1]), h: Number(r[2]), r: Number(r[3]) });
        }
        if (!out.length && m) out.push({ w: m.width, h: m.height, r: m.refreshRate });
        return out;
    }
    readonly property var resolutions: {
        const seen = {}, l = [];
        for (const x of modes(mon)) { const k = x.w + "x" + x.h; if (!seen[k]) { seen[k] = true; l.push(x); } }
        return l.sort((a, b) => b.w * b.h - a.w * a.h);
    }
    readonly property var rates: {
        if (!mon) return [];
        const l = modes(mon).filter(x => x.w === mon.width && x.h === mon.height).map(x => x.r);
        return l.filter((v, i) => l.findIndex(y => Math.abs(y - v) < 0.05) === i).sort((a, b) => b - a);
    }
    // Configuration courante d'un écran, modifiée par `patch`, appliquée
    function apply(m, patch) {
        const c = Object.assign({ w: m.width, h: m.height, r: m.refreshRate, x: m.x, y: m.y, scale: m.scale, transform: m.transform,
                                  mirror: m.mirrorOf && m.mirrorOf !== "none" ? (monitors.find(o => String(o.id) === String(m.mirrorOf))?.name ?? m.mirrorOf) : "" },
                                 Prefs.v.monitors?.[m.name] ?? {}, patch);
        Prefs.setMonitor(m.name, c);
        later.restart();
    }

    // ---- Arrange : positions en cours de modification ----
    property var arrPos: ({})        // { name: { x, y } } en pixels logiques
    readonly property var arrBounds: {
        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (const m of monitors) {
            const p = arrPos[m.name] ?? { x: m.x, y: m.y };
            x0 = Math.min(x0, p.x); y0 = Math.min(y0, p.y);
            x1 = Math.max(x1, p.x + m.width / m.scale); y1 = Math.max(y1, p.y + m.height / m.scale);
        }
        return { x0: x0, y0: y0, w: Math.max(1, x1 - x0), h: Math.max(1, y1 - y0) };
    }
    function arrLoad() {
        const p = {};
        for (const m of monitors) p[m.name] = { x: m.x, y: m.y };
        arrPos = p;
    }
    // Accroche l'écran déplacé au bord le plus proche d'un autre écran
    function arrSnap(name, x, y) {
        const m = monitors.find(o => o.name === name);
        const w = m.width / m.scale, h = m.height / m.scale;
        let best = null, bd = 1e18;
        for (const o of monitors) {
            if (o.name === name) continue;
            const q = arrPos[o.name] ?? { x: o.x, y: o.y };
            const ow = o.width / o.scale, oh = o.height / o.scale;
            const cands = [{ x: q.x - w, y: y }, { x: q.x + ow, y: y }, { x: x, y: q.y - h }, { x: x, y: q.y + oh }];
            for (const c of cands) {
                c.x = Math.max(q.x - w, Math.min(q.x + ow, c.x));
                c.y = Math.max(q.y - h, Math.min(q.y + oh, c.y));
                if (c.x === q.x - w || c.x === q.x + ow) { if (Math.abs(c.y - q.y) < 60) c.y = q.y; }
                else if (Math.abs(c.x - q.x) < 60) c.x = q.x;
                const d = (c.x - x) * (c.x - x) + (c.y - y) * (c.y - y);
                if (d < bd) { bd = d; best = c; }
            }
        }
        const p = Object.assign({}, arrPos);
        p[name] = best ? { x: Math.round(best.x), y: Math.round(best.y) } : { x: Math.round(x), y: Math.round(y) };
        arrPos = p;
    }
    function arrCommit() {
        const b = arrBounds;
        for (const m of monitors) {
            const p = arrPos[m.name] ?? { x: m.x, y: m.y };
            if (p.x - b.x0 !== m.x || p.y - b.y0 !== m.y) apply(m, { x: p.x - b.x0, y: p.y - b.y0 });
        }
    }

    // Débogage (settings-debug call debugApply '{"scale":1.5}')
    function debugApply(json) { if (mon) apply(mon, JSON.parse(json)); return mon ? mon.name : "none"; }
    function debugArrange() { arrLoad(); arrangeSheet.shown = true; return "ok"; }
    function debugMove(spec) { const [n, x, y] = spec.split(","); arrLoad(); arrSnap(n, Number(x), Number(y)); arrCommit(); return JSON.stringify(arrPos); }

    // « Looks like » : échelles HiDPI valables pour la définition native
    readonly property var scales: {
        if (!mon) return [];
        const l = [2, 1.6, 1.5, 1.25, 1].filter(s => Number.isInteger(mon.width / s) && Number.isInteger(mon.height / s));
        return l.length ? l : [1];
    }

    // ---- Vignettes des écrans ----
    Item {
        width: parent.width
        height: 132
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            spacing: 26
            Repeater {
                model: root.monitors
                Item {
                    id: thumb
                    required property var modelData
                    readonly property bool sel: modelData.name === root.mon?.name
                    readonly property real k: 72 / Math.max(modelData.height / modelData.scale, 1)
                    width: Math.max(90, modelData.width / modelData.scale * k)
                    height: 116
                    Rectangle {
                        id: scr
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: modelData.width / modelData.scale * thumb.k
                        height: 72
                        radius: 5
                        color: "#000"
                        border.width: thumb.sel ? 3 : 1
                        border.color: thumb.sel ? SStyle.accent : Qt.rgba(0.5, 0.5, 0.5, 0.5)
                        Image {
                            anchors.fill: parent
                            anchors.margins: thumb.sel ? 3 : 1.5
                            source: Session.WallpaperService.source
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(240, 140)
                            visible: source != ""
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: thumb.sel ? 3 : 1.5
                            visible: Session.WallpaperService.source == ""
                            gradient: Gradient {
                                GradientStop { position: 0; color: Theme.dark ? "#1B2A6B" : "#8DB8F0" }
                                GradientStop { position: 1; color: Theme.dark ? "#3150C8" : "#2F6FE0" }
                            }
                        }
                        // Barre des menus (écran principal)
                        Rectangle {
                            visible: Prefs.v.mainDisplay ? Prefs.v.mainDisplay === thumb.modelData.name : thumb.modelData.x === 0 && thumb.modelData.y === 0
                            x: thumb.sel ? 3 : 1.5; y: x
                            width: parent.width - 2 * x
                            height: 5
                            color: Qt.rgba(1, 1, 1, 0.75)
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 80
                        width: Math.max(120, parent.width)
                        horizontalAlignment: Text.AlignHCenter
                        text: root.nameOf(thumb.modelData)
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: SStyle.small
                        font.weight: thumb.sel ? Font.DemiBold : Font.Normal
                        color: SStyle.label
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 95
                        text: thumb.modelData.mirrorOf !== "none" ? "Mirroring" : thumb.modelData.width + " × " + thumb.modelData.height
                        font.family: Theme.font
                        font.pixelSize: SStyle.small
                        color: SStyle.secondary
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.selected = thumb.modelData.name }
                }
            }
        }
    }
    Item {
        visible: root.monitors.length > 1
        width: parent.width
        height: 24
        SButton { anchors.right: parent.right; text: "Arrange…"; onClicked: { root.arrLoad(); arrangeSheet.shown = true; } }
    }

    SGroup {
        visible: root.monitors.length > 1
        SRow {
            title: "Use as"
            SPopUp {
                readonly property var mainName: Prefs.v.mainDisplay || (root.monitors.find(m => m.x === 0 && m.y === 0)?.name ?? "")
                options: [{ text: "Main display", value: "main" }, { text: "Extended display", value: "extended" }, { separator: true }]
                    .concat(root.others.map(o => ({ text: "Mirror for " + root.nameOf(o), value: "mirror:" + o.name })))
                value: !root.mon ? "" : (root.mon.mirrorOf !== "none" ? "mirror:" + (root.monitors.find(o => String(o.id) === String(root.mon.mirrorOf))?.name ?? "")
                                          : (root.mon.name === mainName ? "main" : "extended"))
                onActivated: (v) => {
                    const m = root.mon;
                    if (v === "main") {
                        Prefs.set("mainDisplay", m.name);
                        Quickshell.execDetached(["hyprctl", "keyword", "cursor:default_monitor", m.name]);
                        if (m.mirrorOf !== "none") root.apply(m, { mirror: "" });
                    } else if (v === "extended") {
                        if (m.mirrorOf !== "none") root.apply(m, { mirror: "" });
                        if (Prefs.v.mainDisplay === m.name) Prefs.set("mainDisplay", root.others[0]?.name ?? "");
                    } else {
                        root.apply(m, { mirror: String(v).slice(7) });
                    }
                }
            }
        }
    }

    SGroup {
        SRow {
            title: "Resolution"
            minHeight: root.showAll ? 36 : 104
            alignTop: !root.showAll
            controlTop: 12
            visible: !!root.mon
            Row {
                visible: !root.showAll
                spacing: 14
                Repeater {
                    model: root.scales
                    Item {
                        id: opt
                        required property real modelData
                        required property int index
                        readonly property bool sel: root.mon && Math.abs(root.mon.scale - modelData) < 0.01
                        width: 58
                        height: 80
                        Rectangle {
                            width: 58; height: 40; radius: 6
                            color: SStyle.groupFill
                            border.width: opt.sel ? 3 : 1
                            border.color: opt.sel ? SStyle.accent : SStyle.separator
                            Text {
                                anchors.centerIn: parent
                                text: "Aa"
                                font.family: Theme.font
                                font.pixelSize: Math.round(9 + 5 * (opt.modelData - 1))
                                color: SStyle.label
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 46
                            text: opt.modelData === 1 ? "Default" : (opt.index === 0 ? "Larger Text" : "")
                            font.family: Theme.font
                            font.pixelSize: SStyle.small
                            color: opt.sel ? SStyle.label : SStyle.secondary
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 60
                            visible: ma.containsMouse || opt.sel
                            text: Math.round(root.mon.width / opt.modelData) + " × " + Math.round(root.mon.height / opt.modelData)
                            font.family: Theme.font
                            font.pixelSize: 10
                            color: SStyle.tertiary
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: root.apply(root.mon, { scale: opt.modelData }) }
                    }
                }
            }
            SPopUp {
                visible: root.showAll
                options: root.resolutions.map(x => ({ text: x.w + " × " + x.h + (x === root.resolutions[0] ? " (Default)" : ""), value: x.w + "x" + x.h }))
                value: root.mon ? root.mon.width + "x" + root.mon.height : ""
                onActivated: (v) => {
                    const [w, h] = String(v).split("x").map(Number);
                    const best = root.modes(root.mon).filter(x => x.w === w && x.h === h).sort((a, b) => b.r - a.r)[0];
                    root.apply(root.mon, { w: w, h: h, r: best ? best.r : 60, scale: 1 });
                }
            }
        }
        SRow {
            title: "Show all resolutions"
            SSwitch { checked: root.showAll; onToggled: (on) => root.showAll = on }
        }
    }
    SGroup {
        SRow {
            title: "Refresh rate"
            SPopUp {
                options: root.rates.map(r => ({ text: (Math.abs(r - Math.round(r)) < 0.05 ? Math.round(r) : r.toFixed(2)) + " Hertz", value: r }))
                value: root.rates.find(r => root.mon && Math.abs(r - root.mon.refreshRate) < 0.05)
                onActivated: (v) => root.apply(root.mon, { r: v })
            }
        }
        SRow {
            title: "Rotation"
            SPopUp {
                options: [{ text: "Standard", value: 0 }, { text: "90°", value: 1 }, { text: "180°", value: 2 }, { text: "270°", value: 3 }]
                value: root.mon?.transform ?? 0
                onActivated: (v) => root.apply(root.mon, { transform: v })
            }
        }
        SRow {
            title: "Color profile"
            dimmed: true
            SPopUp { options: [root.nameOf(root.mon)]; value: root.nameOf(root.mon); enabledPopUp: false }
        }
    }
    Item {
        width: parent.width
        height: 28
        Row {
            anchors.right: parent.right
            y: 4
            spacing: 10
            SButton { text: "Advanced…"; onClicked: advSheet.shown = true }
            SButton { text: "Night Shift…"; onClicked: nightSheet.shown = true }
            HelpButton { url: "https://support.apple.com/guide/mac-help/mh40768/mac" }
        }
    }

    // ---- Feuille Night Shift ----
    SSheet {
        id: nightSheet
        sheetWidth: 480
        body: Component {
            Column {
                width: parent ? parent.width : 0
                spacing: SStyle.groupSpacing
                SNote { text: "Night Shift automatically shifts the colors of your display to the warmer end of the color spectrum after dark. This may help you get a better night’s sleep." }
                SGroup {
                    SRow {
                        title: "Schedule"
                        SPopUp {
                            options: [{ text: "Off", value: "off" }, { text: "Custom", value: "custom" }, { text: "Sunset to Sunrise", value: "sun" }]
                            value: Prefs.v.nightSchedule ?? "off"
                            onActivated: (v) => { Prefs.set("nightSchedule", v); NightSchedule.evaluate(); }
                        }
                    }
                    SRow {
                        visible: (Prefs.v.nightSchedule ?? "off") === "custom"
                        title: "From"
                        Row {
                            spacing: 6
                            SPopUp { options: NightSchedule.hours; value: Prefs.v.nightFrom ?? 22; onActivated: (v) => { Prefs.set("nightFrom", v); NightSchedule.evaluate(); } }
                            Text { text: "to"; font.family: Theme.font; font.pixelSize: SStyle.body; color: SStyle.secondary; anchors.verticalCenter: parent.verticalCenter }
                            SPopUp { options: NightSchedule.hours; value: Prefs.v.nightTo ?? 7; onActivated: (v) => { Prefs.set("nightTo", v); NightSchedule.evaluate(); } }
                        }
                    }
                    SRow {
                        title: "Turn on until " + (NightSchedule.active ? "tomorrow" : "sunrise")
                        SSwitch { checked: CC.NightShift.on; enabledSwitch: CC.NightShift.available; onToggled: (on) => CC.NightShift.on = on }
                    }
                    SRow {
                        title: "Color temperature"
                        minHeight: 50
                        SSlider {
                            width: 200
                            minLabel: "Less Warm"; maxLabel: "More Warm"
                            value: (6000 - CC.NightShift.temperature) / 3300
                            onReleased: (v) => NightSchedule.setTemperature(Math.round(6000 - v * 3300))
                        }
                    }
                }
                SNote { visible: !CC.NightShift.available; text: "Night Shift requires hyprsunset." }
            }
        }
    }

    // ---- Feuille Advanced ----
    SSheet {
        id: advSheet
        sheetWidth: 480
        body: Component {
            Column {
                width: parent ? parent.width : 0
                spacing: SStyle.groupSpacing
                SSection { text: "Link to Mac or iPad" }
                SGroup {
                    SRow { title: "Allow your pointer and keyboard to move between any nearby Mac or iPad"; dimmed: true; SSwitch { checked: false; enabledSwitch: false } }
                }
                SSection { text: "Advanced" }
                SGroup {
                    SRow { title: "Show resolutions as list"; SSwitch { checked: root.showAll; onToggled: (on) => root.showAll = on } }
                    SRow {
                        title: "Variable refresh rate (VRR)"
                        SSwitch {
                            checked: !!root.mon?.vrr
                            onToggled: (on) => { Prefs.setHypr("misc:vrr", on ? 1 : 0); }
                        }
                    }
                }
            }
        }
    }

    // ---- Feuille Arrange ----
    SSheet {
        id: arrangeSheet
        sheetWidth: 560
        cancelText: "Cancel"
        onDone: root.arrCommit()
        body: Component {
            Column {
                width: parent ? parent.width : 0
                spacing: SStyle.groupSpacing
                SNote { text: "To rearrange displays, drag them to the desired position. To relocate the menu bar, drag it to a different display." }
                Rectangle {
                    id: arrange
                    width: parent.width
                    height: 260
                    radius: 10
                    color: SStyle.groupFill
                    readonly property real k: Math.min((width - 80) / (root.arrBounds.w * 1.6), (height - 40) / (root.arrBounds.h * 1.6))
                    Repeater {
                        model: root.monitors
                        Rectangle {
                            id: r
                            required property var modelData
                            readonly property var p: root.arrPos[modelData.name] ?? { x: modelData.x, y: modelData.y }
                            width: modelData.width / modelData.scale * arrange.k
                            height: modelData.height / modelData.scale * arrange.k
                            function bx() { return Math.round((arrange.width - root.arrBounds.w * arrange.k) / 2 + (p.x - root.arrBounds.x0) * arrange.k); }
                            function by() { return Math.round((arrange.height - root.arrBounds.h * arrange.k) / 2 + (p.y - root.arrBounds.y0) * arrange.k); }
                            x: bx()
                            y: by()
                            radius: 4
                            color: Theme.dark ? "#3150C8" : "#5A8EE8"
                            border.width: 2
                            border.color: dragArea.pressed ? SStyle.accent : Qt.rgba(1, 1, 1, 0.7)
                            Rectangle {
                                visible: (Prefs.v.mainDisplay || root.monitors.find(m => m.x === 0 && m.y === 0)?.name) === r.modelData.name
                                x: 2; y: 2; width: parent.width - 4; height: 5; color: Qt.rgba(1, 1, 1, 0.85)
                            }
                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 8
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: root.nameOf(r.modelData)
                                font.family: Theme.font
                                font.pixelSize: SStyle.small
                                color: "#FFFFFF"
                            }
                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                drag.target: r
                                onReleased: {
                                    const k = arrange.k;
                                    const ox = (arrange.width - root.arrBounds.w * k) / 2, oy = (arrange.height - root.arrBounds.h * k) / 2;
                                    root.arrSnap(r.modelData.name, (r.x - ox) / k + root.arrBounds.x0, (r.y - oy) / k + root.arrBounds.y0);
                                    r.x = Qt.binding(() => r.bx());
                                    r.y = Qt.binding(() => r.by());
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
