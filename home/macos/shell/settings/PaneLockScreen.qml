import QtQuick
import qs.common

// Lock Screen (Tahoe 26, Apple mh11784) : économiseur d'écran / extinction
// de l'écran après inactivité, mot de passe exigé, grande horloge, indices,
// message, fenêtre de connexion. Les délais sont appliqués par Settings.qml
// (IdleMonitor) dès qu'ils sont modifiés ici.
PaneBase {
    id: root

    readonly property var delays: [{ text: "Never", value: 0 }, { separator: true }, { text: "For 1 minute", value: 60 }, { text: "For 2 minutes", value: 120 },
        { text: "For 5 minutes", value: 300 }, { text: "For 10 minutes", value: 600 }, { text: "For 15 minutes", value: 900 }, { text: "For 20 minutes", value: 1200 }, { text: "For 30 minutes", value: 1800 },
        { text: "For 1 hour", value: 3600 }, { text: "For 2 hours", value: 7200 }, { text: "For 3 hours", value: 10800 }]
    function setDelay(k, v) { Prefs.set("lockManaged", true); Prefs.set(k, v); }

    SGroup {
        SRow {
            title: "Start Screen Saver when inactive"
            SPopUp { options: root.delays; value: Prefs.v.screenSaverAfter; onActivated: (v) => root.setDelay("screenSaverAfter", v) }
        }
        SRow {
            visible: Nav.hasBattery
            title: "Turn display off on battery when inactive"
            SPopUp { options: root.delays; value: Prefs.v.displayOffAfter; onActivated: (v) => root.setDelay("displayOffAfter", v) }
        }
        SRow {
            title: Nav.hasBattery ? "Turn display off on power adapter when inactive" : "Turn display off when inactive"
            SPopUp { options: root.delays; value: Prefs.v.displayOffAfter; onActivated: (v) => root.setDelay("displayOffAfter", v) }
        }
        SRow {
            title: "Require password after screen saver begins or display is turned off"
            SPopUp {
                options: [{ text: "Immediately", value: 0 }, { text: "After 5 seconds", value: 5 }, { text: "After 1 minute", value: 60 }, { text: "After 5 minutes", value: 300 },
                          { text: "After 15 minutes", value: 900 }, { text: "After 1 hour", value: 3600 }, { text: "After 4 hours", value: 14400 }, { text: "After 8 hours", value: 28800 }]
                value: Prefs.v.requirePassword
                onActivated: (v) => root.setDelay("requirePassword", v)
            }
        }
    }
    SGroup {
        SRow {
            title: "Show large clock"
            SPopUp {
                options: [{ text: "On Screen Saver and Lock Screen", value: "both" }, { text: "On Lock Screen", value: "lock" }, { text: "Never", value: "never" }]
                value: Prefs.v.largeClock ?? "both"
                onActivated: (v) => Prefs.set("largeClock", v)
            }
        }
        SRow { title: "Show password hints"; SSwitch { checked: Prefs.v.passwordHints; onToggled: (on) => Prefs.set("passwordHints", on) } }
        SRow {
            title: "Show message when locked"
            Row {
                spacing: 8
                SButton { text: "Set…"; enabledButton: Prefs.v.lockMessage; onClicked: { msgSheet.msgText = Prefs.v.lockMessageText ?? ""; msgSheet.shown = true; } }
                SSwitch { anchors.verticalCenter: parent.verticalCenter; checked: Prefs.v.lockMessage; onToggled: (on) => Prefs.set("lockMessage", on) }
            }
        }
    }
    SSection { text: "When Switching User" }
    SGroup {
        Item {
            width: parent.width
            height: lw.implicitHeight + 22
            Text { x: SStyle.pad; y: 11; text: "Login window shows"; font.family: Theme.font; font.pixelSize: SStyle.body; color: SStyle.label }
            Column {
                id: lw
                anchors.right: parent.right
                anchors.rightMargin: SStyle.pad
                y: 11
                spacing: 6
                SRadio { text: "List of users"; checked: Prefs.v.loginWindowShows === "list"; onClicked: Prefs.set("loginWindowShows", "list") }
                SRadio { text: "Name and password"; checked: Prefs.v.loginWindowShows === "name"; onClicked: Prefs.set("loginWindowShows", "name") }
            }
        }
        SRow { title: "Show the Sleep, Restart, and Shut Down buttons"; SSwitch { checked: Prefs.v.powerButtons; onToggled: (on) => Prefs.set("powerButtons", on) } }
    }
    Item {
        width: parent.width
        height: 28
        Row {
            anchors.right: parent.right
            y: 4
            spacing: 10
            SButton { text: "Accessibility Options…"; onClicked: Nav.go("accessibility") }
            HelpButton { url: "https://support.apple.com/guide/mac-help/mh11784/mac" }
        }
    }
    SSheet {
        id: msgSheet
        sheetWidth: 420
        cancelText: "Cancel"
        property string msgText: ""
        onDone: Prefs.set("lockMessageText", msgText)
        body: Component {
            Column {
                width: parent ? parent.width : 0
                spacing: SStyle.groupSpacing
                Text { text: "Set a message to appear on the lock screen:"; font.family: Theme.font; font.pixelSize: SStyle.body; color: SStyle.label }
                STextField { width: parent.width; fieldWidth: parent.width; text: msgSheet.msgText; onTextChanged: msgSheet.msgText = text; Component.onCompleted: focusField() }
            }
        }
    }
}
