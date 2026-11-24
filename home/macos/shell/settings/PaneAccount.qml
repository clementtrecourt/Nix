import QtQuick
import Quickshell
import qs.common
import qs.session as Session

// Carte utilisateur de la barre latérale (à la place de l'Apple Account) :
// avatar, nom complet, « NixOS », informations du compte local, changement de
// mot de passe (passwd dans un terminal), photo (~/.face).
PaneBase {
    id: root

    Item {
        width: parent.width
        height: 150
        Session.Avatar {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 6
            size: 84
            source: Users.faceUrl
            name: Users.fullName
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 100
            text: Users.fullName
            font.family: Theme.font; font.pixelSize: 20; font.weight: Font.Bold
            color: SStyle.label
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 127
            text: Users.userName + "  ·  NixOS"
            font.family: Theme.font; font.pixelSize: SStyle.small
            color: SStyle.secondary
        }
    }
    SGroup {
        SRow { title: "Full name"; detail: Users.fullName }
        SRow { title: "Account name"; detail: Users.userName }
        SRow { title: "Home folder"; detail: Users.home }
        SRow { title: "Login shell"; detail: Users.shell.split("/").pop() }
        SRow { title: "Groups"; detail: Users.groups.join(", ") }
    }
    SGroup {
        SRow {
            title: "Password"
            SButton { text: "Change Password…"; onClicked: Quickshell.execDetached(["kitty", "--title", "Change Password", "-e", "passwd"]) }
        }
        SRow {
            title: "Picture"
            subtitle: "~/.face"
            SButton { text: "Choose…"; onClicked: pick.running = true }
        }
    }
    ProcessText {
        id: pick
        command: ["sh", "-c", "command -v zenity >/dev/null || exit 3; f=$(zenity --file-selection --title='Choose a Picture' --file-filter='Images | *.jpg *.jpeg *.png') && cp -f \"$f\" \"$HOME/.face\""]
        onExited: Users.refresh()
    }
}
