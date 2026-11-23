import QtQuick
import QtQuick.Effects
import Quickshell
import qs.common

// Contenu d'un écran verrouillé, mise en page macOS Tahoe :
//  - fond d'écran net (depuis Sonoma l'écran de verrouillage montre le fond
//    tel quel) ;
//  - en haut au centre : date puis grande heure en "verre" (remplissage givré
//    tiré du fond, voile blanc, ombre douce) ;
//  - en bas au centre : avatar rond, nom, champ mot de passe en pilule de verre
//    "Saisir le mot de passe", flèche d'envoi, secousse sur erreur.
Item {
    id: root

    required property var lockRoot
    property var screen

    readonly property real s: Math.max(0.75, Math.min(height / 982, 1.6))   // échelle (réf. MacBook Air 13")

    // ---------------- Fond ----------------
    WallpaperView {
        id: wp
        anchors.fill: parent
    }
    // Léger assombrissement en bas pour la lisibilité du nom / champ
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.35
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.18) }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ---------------- Date + heure ----------------
    Item {
        id: top
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(46 * root.s)
        width: Math.max(dateText.implicitWidth, timeBox.width)
        height: timeBox.y + timeBox.height
        opacity: 0
        transform: Translate { id: topShift; y: -14 }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const d = Qt.locale().toString(clock.date, "dddd d MMMM");
                return d.charAt(0).toUpperCase() + d.slice(1);
            }
            font.family: Theme.font
            font.pixelSize: Math.round(22 * root.s)
            font.weight: Font.DemiBold
            color: Qt.rgba(1, 1, 1, 0.88)
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.25)
                shadowBlur: 0.6
                shadowVerticalOffset: 1
            }
        }

        // Heure "Liquid Glass"
        Item {
            id: timeBox
            anchors.horizontalCenter: parent.horizontalCenter
            y: dateText.height - Math.round(10 * root.s)
            width: timeText.implicitWidth + 40
            height: timeText.implicitHeight

            // Forme de l'heure (masque)
            Text {
                id: timeText
                anchors.centerIn: parent
                text: Qt.formatTime(clock.date, "H:mm")
                font.family: root.clockFamily
                font.pixelSize: Math.round(118 * root.s)
                font.weight: Font.Bold
                font.letterSpacing: -2 * root.s
                color: "white"
                visible: false
                layer.enabled: true
            }
            Item {
                id: maskItem
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Text {
                    anchors.centerIn: parent
                    text: timeText.text
                    font: timeText.font
                    color: "white"
                }
            }

            // Fond d'écran sous l'heure, flouté et éclairci = verre givré
            ShaderEffectSource {
                id: under
                sourceItem: wp
                sourceRect: {
                    const p = timeBox.mapToItem(root, 0, 0);
                    return Qt.rect(p.x, p.y, timeBox.width, timeBox.height);
                }
                anchors.fill: parent
                visible: false
            }
            // Ombre portée très douce
            MultiEffect {
                anchors.fill: parent
                source: maskItem
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.22)
                shadowBlur: 0.8
                shadowVerticalOffset: 2
                opacity: 0.9
                // n'affiche que l'ombre : le texte est rendu par-dessus
                brightness: -1
                colorization: 0
            }
            MultiEffect {
                anchors.fill: parent
                source: under
                blurEnabled: true
                blur: 1
                blurMax: 40
                brightness: 0.42
                saturation: 0.25
                maskEnabled: true
                maskSource: maskItem
            }
            // Voile blanc translucide (luminosité du verre)
            MultiEffect {
                anchors.fill: parent
                source: maskItem
                opacity: 0.42
            }
            // Reflet spéculaire : plus clair en haut des chiffres
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: maskItem
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.15; color: Qt.rgba(1, 1, 1, 0.35) }
                        GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.0) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.10) }
                    }
                }
            }
        }
    }

    // Police de l'heure : SF Pro Rounded si installée, sinon Inter Display
    readonly property string clockFamily: {
        const fams = Qt.fontFamilies();
        for (const f of ["SF Pro Rounded", "SF Pro Display", Theme.fontDisplay])
            if (fams.includes(f)) return f;
        return Theme.font;
    }

    // ---------------- Utilisateur + mot de passe ----------------
    Column {
        id: bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(74 * root.s)
        spacing: 0
        opacity: 0
        transform: Translate { id: shake; x: 0 }

        // Avatar
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 56
            height: 56

            Rectangle {
                id: avatarShape
                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
            }
            Image {
                id: face
                anchors.fill: parent
                source: "file://" + root.lockRoot.facePath
                sourceSize: Qt.size(112, 112)
                fillMode: Image.PreserveAspectCrop
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                source: face
                visible: face.status === Image.Ready
                maskEnabled: true
                maskSource: avatarShape
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.3)
                shadowBlur: 0.5
                shadowVerticalOffset: 1
            }
            // Monogramme (pas de ~/.face) : dégradé gris + initiales
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                visible: face.status !== Image.Ready
                gradient: Gradient {
                    GradientStop { position: 0; color: "#A5A9B1" }
                    GradientStop { position: 1; color: "#7D828B" }
                }
                Text {
                    anchors.centerIn: parent
                    text: root.lockRoot.fullName.split(/\s+/).map(w => w.charAt(0)).join("").slice(0, 2).toUpperCase()
                    font.family: Theme.fontDisplay
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                    color: "white"
                }
            }
        }

        Item { width: 1; height: 10 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.lockRoot.fullName
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: "white"
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.35)
                shadowBlur: 0.4
                shadowVerticalOffset: 1
            }
        }

        Item { width: 1; height: 10 }

        // Champ mot de passe (pilule de verre)
        Item {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 186
            height: 30

            // Verre : fond flouté + voile
            ShaderEffectSource {
                id: fieldUnder
                sourceItem: wp
                sourceRect: {
                    const p = field.mapToItem(root, 0, 0);
                    return Qt.rect(p.x - shake.x, p.y, field.width, field.height);
                }
                anchors.fill: parent
                visible: false
            }
            Rectangle {
                id: fieldShape
                anchors.fill: parent
                radius: height / 2
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                source: fieldUnder
                blurEnabled: true
                blur: 1
                blurMax: 32
                brightness: 0.12
                saturation: 0.2
                maskEnabled: true
                maskSource: fieldShape
            }
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(1, 1, 1, input.activeFocus ? 0.24 : 0.20)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.22)
                // liseré spéculaire du haut
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.18)
                    anchors.topMargin: 0
                    anchors.bottomMargin: 1
                }
            }

            Text {
                anchors.centerIn: parent
                visible: input.text.length === 0
                text: "Saisir le mot de passe"
                font.family: Theme.font
                font.pixelSize: 13
                color: Qt.rgba(1, 1, 1, 0.62)
            }

            TextInput {
                id: input
                anchors.left: parent.left
                anchors.right: go.left
                anchors.leftMargin: 13
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                focus: true
                echoMode: TextInput.Password
                passwordCharacter: "●"
                font.family: Theme.font
                font.pixelSize: 10
                font.letterSpacing: 2.5
                color: "white"
                selectionColor: Qt.rgba(1, 1, 1, 0.3)
                clip: true
                readOnly: root.lockRoot.authenticating || root.lockRoot.unlocking
                text: root.lockRoot.password
                onTextEdited: root.lockRoot.password = text
                onAccepted: root.lockRoot.submit()
                Keys.onEscapePressed: root.lockRoot.password = ""
                cursorDelegate: Rectangle {
                    width: 1.5
                    color: "white"
                    visible: input.activeFocus && input.text.length > 0 && !input.readOnly
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: true
                        NumberAnimation { to: 0; duration: 500; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutQuad }
                    }
                }
            }

            // Bouton flèche (apparaît dès qu'on tape) / indicateur d'attente
            Item {
                id: go
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                opacity: input.text.length > 0 ? 1 : 0
                scale: input.text.length > 0 ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, goMouse.pressed ? 0.45 : 0.30)
                    visible: !root.lockRoot.authenticating
                    Symbol {
                        anchors.centerIn: parent
                        name: "arrow.right"
                        size: 11
                        color: "white"
                    }
                }
                // Roue d'attente pendant la vérification PAM
                Canvas {
                    id: spinner
                    anchors.fill: parent
                    visible: root.lockRoot.authenticating
                    onPaint: {
                        const c = getContext("2d");
                        c.reset();
                        c.lineWidth = 2;
                        c.lineCap = "round";
                        c.strokeStyle = "rgba(255,255,255,0.9)";
                        c.beginPath();
                        c.arc(10, 10, 7, 0, Math.PI * 1.4);
                        c.stroke();
                    }
                    RotationAnimation on rotation {
                        running: spinner.visible
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                    }
                }
                MouseArea {
                    id: goMouse
                    anchors.fill: parent
                    onClicked: root.lockRoot.submit()
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: 28
                cursorShape: Qt.IBeamCursor
                onClicked: input.forceActiveFocus()
            }
        }

        Item { width: 1; height: 8 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.lockRoot.errorText
            visible: text.length > 0
            font.family: Theme.font
            font.pixelSize: 11
            color: Qt.rgba(1, 1, 1, 0.85)
        }
    }

    // ---------------- Animations ----------------
    // Entrée : l'heure descend légèrement en fondu, puis le bloc utilisateur
    ParallelAnimation {
        id: enter
        running: true
        NumberAnimation { target: top; property: "opacity"; to: 1; duration: 420; easing.type: Easing.OutCubic }
        NumberAnimation { target: topShift; property: "y"; to: 0; duration: 520; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            NumberAnimation { target: bottom; property: "opacity"; to: 1; duration: 380; easing.type: Easing.OutCubic }
        }
    }

    // Sortie (déverrouillage réussi)
    Connections {
        target: root.lockRoot
        function onUnlockingChanged() {
            if (root.lockRoot.unlocking) leave.restart();
        }
        function onShakeSerialChanged() { shakeAnim.restart(); }
    }
    ParallelAnimation {
        id: leave
        NumberAnimation { target: top; property: "opacity"; to: 0; duration: 240; easing.type: Easing.InQuad }
        NumberAnimation { target: topShift; property: "y"; to: -24; duration: 240; easing.type: Easing.InQuad }
        NumberAnimation { target: bottom; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InQuad }
    }

    // Secousse "mauvais mot de passe" (≈ 0,5 s, amplitude décroissante)
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shake; property: "x"; to: -14; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: shake; property: "x"; to: 14; duration: 80; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: -10; duration: 75; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: 10; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: -5; duration: 65; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: 4; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 55; easing.type: Easing.OutQuad }
        ScriptAction { script: input.forceActiveFocus() }
    }

    Component.onCompleted: input.forceActiveFocus()
}
