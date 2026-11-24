pragma Singleton

import QtQuick
import Quickshell
import qs.controlcenter as CC

// Programmation de Night Shift (Displays > Night Shift…) : Custom (heures
// choisies) ou Sunset to Sunrise (19 h – 7 h), évaluée chaque minute ;
// température réglée sur controlcenter/NightShift (hyprsunset relancé).
Singleton {
    id: root

    readonly property var hours: Array.from({ length: 24 }, (_, h) => ({ text: (h % 12 === 0 ? 12 : h % 12) + ":00 " + (h < 12 ? "AM" : "PM"), value: h }))
    readonly property string schedule: Prefs.v.nightSchedule ?? "off"
    readonly property bool active: {
        if (schedule === "off") return false;
        const from = schedule === "sun" ? 19 : (Prefs.v.nightFrom ?? 22);
        const to = schedule === "sun" ? 7 : (Prefs.v.nightTo ?? 7);
        const h = _now.getHours();
        return from <= to ? (h >= from && h < to) : (h >= from || h < to);
    }
    property date _now: new Date()
    property bool _last: false

    function evaluate() {
        _now = new Date();
        if (schedule === "off") return;
        // Ne bascule qu'aux transitions (l'utilisateur garde la main entre deux)
        if (active !== _last) { _last = active; if (CC.NightShift.available) CC.NightShift.on = active; }
    }
    function setTemperature(k) {
        if (CC.NightShift.temperature === k) return;
        CC.NightShift.temperature = k;
        Prefs.set("nightTemperature", k);
        if (CC.NightShift.on) { CC.NightShift.on = false; Qt.callLater(() => CC.NightShift.on = true); }
    }
    Component.onCompleted: {
        _last = !active;
        if (Prefs.v.nightTemperature) CC.NightShift.temperature = Prefs.v.nightTemperature;
    }
    Connections {
        target: Prefs
        function onLoadedChanged() {
            if (Prefs.v.nightTemperature) CC.NightShift.temperature = Prefs.v.nightTemperature;
            root._last = !root.active;
            root.evaluate();
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.evaluate() }
}
