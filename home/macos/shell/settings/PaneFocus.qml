import QtQuick
import qs.common
import qs.services

// Focus (Tahoe 26) : modes Concentration (pastille de couleur, « On » quand
// actif, feuille par mode avec interrupteur et durée), Share across devices,
// Focus status — piloté par services/Focus (partagé avec le Control Center).
PaneBase {
    id: root

    property var mode: null
    function on(m) { return Focus.doNotDisturb && Focus.mode === m.id; }

    SHeaderCard {
        pane: root.spec
        description: "Focus lets you silence notifications and filter what you see to stay on task. Notifications are held in Notification Center while a Focus is on."
    }
    SGroup {
        Repeater {
            model: Focus.modes
            SRow {
                required property var modelData
                title: modelData.name
                pane: ({ icon: modelData.symbol, c: [Qt.lighter(modelData.color, 1.15), modelData.color] })
                minHeight: 42
                chevron: true
                detail: root.on(modelData) ? "On" : ""
                onClicked: { root.mode = modelData; sheet.shown = true; }
            }
        }
    }
    Item {
        width: parent.width
        height: 28
        SButton { anchors.right: parent.right; y: 2; text: "Add Focus…"; enabledButton: false }
    }
    SGroup {
        SRow {
            title: "Share across devices"
            subtitle: "Focus is shared across your devices, and turning one on for this device will turn it on for all of them."
            SSwitch { checked: Prefs.v.shareAcrossDevices; onToggled: (on) => Prefs.set("shareAcrossDevices", on) }
        }
    }
    SGroup {
        SRow {
            title: "Focus status"
            detail: Prefs.v.focusStatus ? "On" : "Off"
            chevron: true
            onClicked: Prefs.set("focusStatus", !Prefs.v.focusStatus)
        }
    }

    SSheet {
        id: sheet
        sheetWidth: 460
        body: Component {
            Column {
                width: parent ? parent.width : 0
                spacing: SStyle.groupSpacing
                SHeaderCard {
                    pane: root.mode ? ({ icon: root.mode.symbol, c: [Qt.lighter(root.mode.color, 1.15), root.mode.color] }) : null
                    title: root.mode?.name ?? ""
                    description: "Silence notifications while " + (root.mode?.name ?? "this Focus") + " is on."
                    SSwitch {
                        checked: root.mode ? root.on(root.mode) : false
                        onToggled: (on) => {
                            if (!root.mode) return;
                            if (on) { Focus.mode = root.mode.id; Focus.setDoNotDisturb(true, 0); }
                            else if (root.on(root.mode)) Focus.setDoNotDisturb(false);
                        }
                    }
                }
                SGroup {
                    SRow {
                        title: "Turn on"
                        SPopUp {
                            options: [{ text: "Until I turn it off", value: "" }, { text: "For 1 hour", value: "hour" }, { text: "Until this evening", value: "tonight" }, { text: "Until tomorrow morning", value: "morning" }]
                            value: root.mode && root.on(root.mode) ? Focus.untilKind : ""
                            onActivated: (v) => {
                                if (!root.mode) return;
                                const d = new Date();
                                let until = 0;
                                if (v === "hour") until = Date.now() + 3600000;
                                else if (v === "tonight") { d.setHours(19, 0, 0, 0); until = d.getTime(); }
                                else if (v === "morning") { d.setDate(d.getDate() + 1); d.setHours(8, 0, 0, 0); until = d.getTime(); }
                                Focus.mode = root.mode.id;
                                Focus.setDoNotDisturb(true, until, v);
                            }
                        }
                    }
                }
            }
        }
    }
}
