import QtQuick
import Quickshell
import qs.common
import qs.session as Session

// Users & Groups (Tahoe 26), en lecture : comptes du système (avatar, nom
// complet, Admin / Standard), Guest User, ouverture de session automatique.
// Les comptes NixOS sont déclaratifs (users.users) : ajout et suppression
// grisés, comme pour un compte non administrateur.
PaneBase {
    id: root

    Component.onCompleted: Users.refresh()

    SGroup {
        Repeater {
            model: Users.users
            SRow {
                id: ur
                required property var modelData
                title: modelData.full
                subtitle: modelData.admin ? "Admin" : "Standard"
                minHeight: 52
                Symbol {
                    name: "info.circle"; size: 16; color: SStyle.secondary
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; anchors.margins: -3; onClicked: Nav.go("account"); enabled: modelData.name === Users.userName }
                }
                Session.Avatar {
                    parent: ur
                    x: SStyle.pad
                    anchors.verticalCenter: parent.verticalCenter
                    size: 32
                    shadow: false
                    source: modelData.name === Users.userName ? Users.faceUrl : ""
                    name: modelData.full
                }
                leadOffset: 40
            }
        }
        SRow {
            id: gr
            title: "Guest User"
            subtitle: "Off"
            minHeight: 52
            leadOffset: 40
            Session.Avatar { parent: gr; x: SStyle.pad; anchors.verticalCenter: parent.verticalCenter; size: 32; shadow: false; name: "Guest User" }
        }
    }
    Item {
        width: parent.width
        height: 28
        SButton { anchors.right: parent.right; y: 2; text: "Add User…"; enabledButton: false }
    }
    SGroup {
        SRow { title: "Automatically log in as"; detail: autologin.text || "Off" }
        SRow { title: "Network account server"; dimmed: true; SButton { text: "Edit…"; enabledButton: false } }
    }
    SNote { text: "User accounts are defined in your NixOS configuration (users.users)." }
    ProcessText {
        id: autologinProbe
        running: true
        command: ["sh", "-c", "grep -hs -A2 'initial_session' /etc/greetd/config.toml | sed -n 's/^user *= *\"\\(.*\\)\"/\\1/p' | head -1"]
        onDone: (t) => autologin.text = t.trim()
    }
    QtObject { id: autologin; property string text: "" }
}
