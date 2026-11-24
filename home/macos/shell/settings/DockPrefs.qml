pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Réglages du Dock du shell, lus là où dock/ les garde et pilotés comme il
// l'attend (sans modifier dock/) :
//  - autohide / magnification / showRecents : IPC « dock » de CETTE instance
//    (quickshell ipc --pid) ; le Dock les persiste dans son état (dock.json) ;
//  - tileSize / largeSize / minimizeEffect : clés "dock.*" de settings.json
//    (dossier du shell), que le Dock surveille.
Singleton {
    id: root

    property int tileSize: 48
    property int largeSize: 77
    property bool magnification: false
    property bool autohide: false
    property bool showRecents: true
    property string minimizeEffect: "genie"
    property var _settings: ({})

    FileView {
        id: settingsFile
        path: Quickshell.shellPath("settings.json")
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const o = JSON.parse(text());
                root._settings = o;
                const g = (k, d) => (o["dock." + k] !== undefined ? o["dock." + k] : (o.dock?.[k] !== undefined ? o.dock[k] : d));
                root.tileSize = g("tileSize", root.tileSize);
                root.largeSize = g("largeSize", Math.round(root.tileSize * 1.6));
                root.magnification = g("magnification", root.magnification);
                root.autohide = g("autohide", root.autohide);
                root.showRecents = g("showRecents", root.showRecents);
                root.minimizeEffect = g("minimizeEffect", root.minimizeEffect);
            } catch (e) {}
            stateFile.reload();
        }
        onLoadFailed: stateFile.reload()
    }
    // Préférences changées à l'exécution (prioritaires, comme dans Dock.qml)
    FileView {
        id: stateFile
        path: Quickshell.statePath("dock.json")
        printErrors: false
        onLoaded: {
            try {
                const p = JSON.parse(text()).prefs ?? {};
                if (p.autohide !== undefined) root.autohide = p.autohide;
                if (p.magnification !== undefined) root.magnification = p.magnification;
                if (p.showRecents !== undefined) root.showRecents = p.showRecents;
            } catch (e) {}
        }
    }

    function ipc(fn, arg) {
        Quickshell.execDetached(["quickshell", "ipc", "--pid", String(Quickshell.processId), "call", "dock", fn, String(arg)]);
    }
    function setAutohide(on) { autohide = on; ipc("setAutohide", on); }
    function setMagnification(on) { magnification = on; ipc("setMagnification", on); }
    function setShowRecents(on) { showRecents = on; ipc("setShowRecents", on); }

    // settings.json : fusion des clés "dock.*" (écriture différée pendant le glissement)
    property var _pending: ({})
    function setSetting(k, v) {
        const p = Object.assign({}, _pending);
        p["dock." + k] = v;
        _pending = p;
        writeTimer.restart();
    }
    function setTileSize(v) { tileSize = v; setSetting("tileSize", v); }
    function setLargeSize(v) { largeSize = v; setSetting("largeSize", v); }
    function setMinimizeEffect(v) { minimizeEffect = v; setSetting("minimizeEffect", v); }
    Timer {
        id: writeTimer
        interval: 120
        onTriggered: {
            const o = Object.assign({}, root._settings, root._pending);
            root._pending = {};
            root._settings = o;
            settingsFile.setText(JSON.stringify(o, null, 2));
        }
    }
}
