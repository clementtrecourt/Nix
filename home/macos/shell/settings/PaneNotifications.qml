import QtQuick
import Quickshell
import qs.common

// Notifications (Tahoe 26, Apple mh40583) : Notification Center (aperçus,
// autorisations écran en veille / verrouillé / recopie), Application
// Notifications (apps installées susceptibles de notifier ; feuille par app :
// autoriser, style Temporary / Persistent, badge, son, aperçus, regroupement).
// Réglages persistés dans l'état de Réglages (clés notif*, appNotif) pour le
// centre de notifications.
PaneBase {
    id: root

    readonly property var cats: ["Network", "Chat", "InstantMessaging", "Email", "Calendar", "Office", "AudioVideo", "Development", "Game", "Utility"]
    readonly property var apps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay && (e.categories ?? []).some(c => root.cats.includes(c)))
        .sort((a, b) => a.name.localeCompare(b.name))
    property var app: null
    function conf(id) { return Object.assign({ allow: true, style: "temporary", badge: true, sound: true, previews: "default", grouping: "auto", desktop: true, center: true, lock: true }, Prefs.v.appNotif?.[id] ?? {}); }
    function setConf(id, k, val) { const c = conf(id); c[k] = val; Prefs.setIn("appNotif", id, c); }
    function summary(id) {
        const c = conf(id);
        if (!c.allow) return "Off";
        const l = [];
        if (c.badge) l.push("Badges");
        if (c.sound) l.push("Sounds");
        l.push(c.style === "persistent" ? "Alerts" : "Banners");
        return l.join(", ");
    }

    SSection { text: "Notification Center" }
    SGroup {
        SRow {
            title: "Show previews"
            SPopUp {
                options: [{ text: "Always", value: "always" }, { text: "When Unlocked", value: "unlocked" }, { text: "Never", value: "never" }]
                value: Prefs.v.notifPreviews
                onActivated: (v) => Prefs.set("notifPreviews", v)
            }
        }
        SRow { title: "Summarize notifications"; dimmed: true; detail: "Off"; chevron: true; clickable: false }
    }
    SGroup {
        SRow { title: "Allow notifications when the display is sleeping"; SSwitch { checked: Prefs.v.notifSleeping; onToggled: (on) => Prefs.set("notifSleeping", on) } }
        SRow { title: "Allow notifications when the screen is locked"; SSwitch { checked: Prefs.v.notifLocked; onToggled: (on) => Prefs.set("notifLocked", on) } }
        SRow { title: "Allow notifications when mirroring or sharing the display"; SSwitch { checked: Prefs.v.notifMirroring; onToggled: (on) => Prefs.set("notifMirroring", on) } }
    }

    SSection { text: "Application Notifications" }
    SGroup {
        Repeater {
            model: root.apps
            SRow {
                required property var modelData
                title: modelData.name
                subtitle: root.summary(modelData.id)
                iconSource: Quickshell.iconPath(modelData.icon || "application-x-executable", "application-x-executable")
                iconSize: 24
                minHeight: 44
                chevron: true
                onClicked: { root.app = modelData; sheet.shown = true; }
            }
        }
    }

    SSheet {
        id: sheet
        sheetWidth: 480
        readonly property string id_: root.app?.id ?? ""
        readonly property var c: root.app ? root.conf(id_) : ({})
        body: Component {
            Column {
                width: parent ? parent.width : 0
                spacing: SStyle.groupSpacing
                SGroup {
                    SRow {
                        title: root.app?.name ?? ""
                        iconSource: root.app ? Quickshell.iconPath(root.app.icon || "application-x-executable", "application-x-executable") : ""
                        iconSize: 24
                        minHeight: 44
                    }
                    SRow { title: "Allow notifications"; SSwitch { checked: sheet.c.allow ?? true; onToggled: (on) => root.setConf(sheet.id_, "allow", on) } }
                }
                SGroup {
                    opacity: sheet.c.allow ? 1 : 0.45
                    enabled: sheet.c.allow ?? true
                    SRow {
                        title: "Alert Style"
                        SPopUp {
                            options: [{ text: "Temporary", value: "temporary" }, { text: "Persistent", value: "persistent" }]
                            value: sheet.c.style
                            onActivated: (v) => root.setConf(sheet.id_, "style", v)
                        }
                    }
                    SRow { title: "Show notifications on desktop"; SSwitch { checked: sheet.c.desktop ?? true; onToggled: (on) => root.setConf(sheet.id_, "desktop", on) } }
                    SRow { title: "Show in Notification Center"; SSwitch { checked: sheet.c.center ?? true; onToggled: (on) => root.setConf(sheet.id_, "center", on) } }
                    SRow { title: "Show notifications on Lock Screen"; SSwitch { checked: sheet.c.lock ?? true; onToggled: (on) => root.setConf(sheet.id_, "lock", on) } }
                    SRow { title: "Badge application icon"; SSwitch { checked: sheet.c.badge ?? true; onToggled: (on) => root.setConf(sheet.id_, "badge", on) } }
                    SRow { title: "Play sound for notification"; SSwitch { checked: sheet.c.sound ?? true; onToggled: (on) => root.setConf(sheet.id_, "sound", on) } }
                    SRow {
                        title: "Show previews"
                        SPopUp {
                            options: [{ text: "Default", value: "default" }, { text: "Always", value: "always" }, { text: "When Unlocked", value: "unlocked" }, { text: "Never", value: "never" }]
                            value: sheet.c.previews
                            onActivated: (v) => root.setConf(sheet.id_, "previews", v)
                        }
                    }
                    SRow {
                        title: "Notification grouping"
                        SPopUp {
                            options: [{ text: "Automatic", value: "auto" }, { text: "By Application", value: "app" }, { text: "Off", value: "off" }]
                            value: sheet.c.grouping
                            onActivated: (v) => root.setConf(sheet.id_, "grouping", v)
                        }
                    }
                }
            }
        }
    }
}
