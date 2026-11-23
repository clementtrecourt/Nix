import QtQuick
import Quickshell
import qs.services

// Effet génie : provisoire.
Scope {
    id: root
    property var screen
    property var dock
    property bool enabled: true
    function minimizeActive() {
        const t = Windows.activeToplevel;
        if (t) Windows.minimize(t);
    }
    function restore(t, tile) { Windows.restore(t); }
}
