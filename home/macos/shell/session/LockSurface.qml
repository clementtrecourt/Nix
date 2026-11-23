import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Networking
import Quickshell.Services.UPower
import qs.common
import qs.menubar

// Contenu d'un écran verrouillé, mise en page macOS Tahoe (proportions
// relevées sur une capture de l'écran verrouillé Tahoe, rapportées à la
// hauteur de l'écran) :
//  - fond d'écran net, exactement comme sur le bureau (depuis Sonoma l'écran
//    de verrouillage montre le fond tel quel, sans voile ni dégradé) ;
//  - en haut au centre : date abrégée (« lun. 23 nov. ») puis grande heure en
//    Liquid Glass translucide : le fond flouté transparaît dans les chiffres,
//    éclairci par un voile laiteux, avec une arête claire et une ombre douce ;
//  - en haut à droite : source de saisie (« Français » + clavier), Wi-Fi,
//    batterie sur un portable ;
//  - en bas au centre : avatar, nom et, au repos, une simple ligne d'indice
//    « Saisir le mot de passe ». La pilule de verre du mot de passe n'apparaît
//    qu'à la première frappe (ou au clic), et elle seule secoue sur erreur.
Item {
    id: root

    required property var lockRoot
    property var screen

    readonly property real s: Math.max(0.75, Math.min(height / 982, 1.6))   // échelle (réf. MacBook Air 13")
    // Hauteur des capitales / chiffres d'Inter, en fraction du corps
    readonly property real capRatio: 0.727

    // Champ mot de passe affiché (sinon : ligne d'indice). Vrai dès qu'on tape,
    // reste vrai après une erreur, retombe au repos après 10 s champ vide.
    property bool engaged: false
    readonly property bool fieldShown: engaged || lockRoot.password.length > 0 || lockRoot.authenticating
    function engage() {
        engaged = true;
        idle.restart();
        input.forceActiveFocus();
    }
    Connections {
        target: root.lockRoot
        function onPasswordChanged() {
            if (root.lockRoot.password.length > 0) root.engaged = true;
            idle.restart();
        }
    }
    Timer {
        id: idle
        interval: 10000
        onTriggered: {
            if (root.lockRoot.password.length === 0 && !root.lockRoot.authenticating) root.engaged = false;
            else restart();
        }
    }

    // ---------------- Fond ----------------
    WallpaperView {
        id: wp
        anchors.fill: parent
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ---------------- Date + heure ----------------
    Item {
        id: top
        anchors.fill: parent
        opacity: 0
        transform: Translate { id: topShift; y: -14 }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            // Centre des capitales à 10,7 % de la hauteur
            y: Math.round(root.height * 0.107 + font.pixelSize * root.capRatio / 2 - baselineOffset)
            // Interface en français, jour et mois abrégés comme Tahoe (« Sun Jul 27 »)
            text: Qt.locale("fr_FR").toString(clock.date, "ddd d MMM")
            font.family: Theme.font
            font.pixelSize: Math.round(23 * root.s)
            font.weight: Font.DemiBold
            color: Qt.rgba(1, 1, 1, 0.94)
            // Ombre : copie sombre floutée dessous (évite les franges colorées
            // d'un layer sur le texte lui-même)
            Text {
                z: -1
                anchors.fill: parent
                text: parent.text
                font: parent.font
                color: Qt.rgba(0, 0, 0, 0.45)
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 0.5
                    blurMax: 12
                    opacity: 0.5
                }
            }
        }

        // Heure "Liquid Glass" : chiffres de 13,9 % à 23,9 % de la hauteur
        Item {
            id: timeBox
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property real px: Math.round(root.height * 0.100 / root.capRatio)
            y: Math.round(root.height * 0.239 - timeText.baselineOffset)
            width: timeText.implicitWidth + 40
            height: timeText.implicitHeight

            // Forme de l'heure
            Text {
                id: timeText
                anchors.centerIn: parent
                text: Qt.formatTime(clock.date, "H:mm")
                font.family: root.clockFamily
                font.pixelSize: timeBox.px
                font.weight: Font.DemiBold
                font.letterSpacing: 0
                color: "white"
                visible: false
            }
            // Masque (texte blanc opaque dans une texture)
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

            // Ombre portée douce : texte sombre flouté sous le verre
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: Math.round(3 * root.s)
                text: timeText.text
                font: timeText.font
                color: Qt.rgba(0, 0, 0, 0.5)
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 32
                }
                opacity: Theme.dark ? 0.30 : 0.24
            }
            // Fond d'écran sous l'heure, flouté : il transparaît dans les chiffres
            ShaderEffectSource {
                id: under
                sourceItem: wp
                // Géométrie explicite (mapToItem ne se réévalue pas au placement)
                sourceRect: Qt.rect(timeBox.x, timeBox.y + topShift.y, timeBox.width, timeBox.height)
                anchors.fill: parent
                visible: false
            }
            // Verre des chiffres, composé dans une seule couche puis découpé
            // par la forme du texte (masque à bord adouci : pas d'épaississement
            // ni de frange) :
            //  - fond flouté qui transparaît ;
            //  - voile laiteux (≈ fond × 0,55 + blanc × 0,45, mesuré sur Tahoe) ;
            //  - reflet un peu plus clair en haut.
            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    autoPaddingEnabled: false
                    maskEnabled: true
                    maskSource: maskItem
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
                MultiEffect {
                    anchors.fill: parent
                    source: under
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 1
                    blurMax: 48
                    saturation: -0.1
                }
                Rectangle {
                    anchors.fill: parent
                    color: "white"
                    opacity: Theme.dark ? 0.40 : 0.50
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.15; color: Qt.rgba(1, 1, 1, 0.12) }
                        GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0.0) }
                    }
                }
            }
            // Arête du verre : contour fin et clair des chiffres
            Text {
                anchors.centerIn: parent
                text: timeText.text
                font: timeText.font
                color: "transparent"
                style: Text.Outline
                styleColor: Qt.rgba(1, 1, 1, 0.38)
            }
        }
    }

    // ---------------- Statut (coin supérieur droit) ----------------
    // Comme l'écran de verrouillage macOS : source de saisie, Wi-Fi, batterie.
    Row {
        id: status
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 14
        height: 18
        spacing: 12
        opacity: top.opacity

        readonly property var battery: UPower.displayDevice
        readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
        readonly property var network: wifi?.networks?.values?.find(n => n.connected) ?? null

        // Source de saisie : nom court + pictogramme clavier
        Row {
            visible: root.lockRoot.layoutName !== ""
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.lockRoot.layoutName
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Qt.rgba(1, 1, 1, 0.9)
            }
            Symbol {
                anchors.verticalCenter: parent.verticalCenter
                name: "keyboard"
                size: 17
                color: Qt.rgba(1, 1, 1, 0.9)
            }
        }
        Row {
            visible: status.battery && status.battery.isLaptopBattery && status.battery.isPresent
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round((status.battery?.percentage ?? 0) * 100) + " %"
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.Medium
                color: "white"
            }
            BatteryGlyph {
                anchors.verticalCenter: parent.verticalCenter
                color: "white"
                level: status.battery?.percentage ?? 1
                charging: status.battery?.state === UPowerDeviceState.Charging
                pluggedFull: !UPower.onBattery && status.battery?.state === UPowerDeviceState.FullyCharged
            }
        }
        WifiGlyph {
            visible: status.wifi !== null
            anchors.verticalCenter: parent.verticalCenter
            color: "white"
            off: !Networking.wifiEnabled
            level: {
                const st = status.network?.signalStrength ?? 0;
                return !status.network ? 0 : st > 0.66 ? 3 : st > 0.33 ? 2 : 1;
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
    // Centres mesurés sur Tahoe : avatar 87,3 %, nom 91,5 %, indice 93,7 %.
    Item {
        id: bottom
        anchors.fill: parent
        opacity: 0

        // Avatar (~/.face ou monogramme) ; un clic fait apparaître le champ
        Avatar {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            size: Math.round(52 * root.s)
            y: Math.round(root.height * 0.873 - height / 2)
            source: root.lockRoot.faceSource
            name: root.lockRoot.fullName
            MouseArea {
                anchors.fill: parent
                onClicked: root.engage()
            }
        }

        Text {
            id: nameText
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * 0.915 - height / 2)
            text: root.lockRoot.fullName
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: "white"
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.30)
                shadowBlur: 0.4
                shadowVerticalOffset: 1
            }
        }

        // Indice au repos (« Touch ID or Enter Password » sur un Mac à Touch ID)
        Text {
            id: hint
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * 0.937 - height / 2)
            text: "Saisir le mot de passe"
            font.family: Theme.font
            font.pixelSize: 11
            font.weight: Font.Medium
            color: Qt.rgba(1, 1, 1, 0.68)
            opacity: root.fieldShown ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 160 } }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                enabled: !root.fieldShown
                cursorShape: Qt.IBeamCursor
                onClicked: root.engage()
            }
        }

        // Champ mot de passe (pilule de verre), à la place de l'indice
        Item {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * 0.937 - height / 2 + 4)
            width: 180
            height: 28
            opacity: root.fieldShown ? 1 : 0
            scale: root.fieldShown ? 1 : 0.94
            // Reste "visible" (opacité nulle) : le TextInput garde le focus
            // clavier pour capter la première frappe.
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            // Seul le champ secoue sur erreur (comme macOS)
            transform: Translate { id: shake; x: 0 }

            // Verre : fond flouté + voile
            ShaderEffectSource {
                id: fieldUnder
                sourceItem: wp
                sourceRect: Qt.rect(field.x + shake.x, field.y, field.width, field.height)
                anchors.fill: parent
                visible: false
            }
            ClippingRectangle {
                anchors.fill: parent
                radius: height / 2
                color: "transparent"
                MultiEffect {
                    anchors.fill: parent
                    source: fieldUnder
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 1
                    blurMax: 32
                    brightness: 0.10
                    saturation: 0.1
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.16)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.24)
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0
                text: "Saisir le mot de passe"
                font.family: Theme.font
                font.pixelSize: 12
                color: Qt.rgba(1, 1, 1, 0.60)
            }

            TextInput {
                id: input
                anchors.left: parent.left
                anchors.right: go.left
                anchors.leftMargin: 12
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                focus: true
                echoMode: TextInput.Password
                passwordCharacter: "●"
                font.family: Theme.font
                font.pixelSize: 9
                font.letterSpacing: 3
                color: "white"
                selectionColor: Qt.rgba(1, 1, 1, 0.3)
                clip: true
                readOnly: root.lockRoot.authenticating || root.lockRoot.unlocking
                text: root.lockRoot.password
                onTextEdited: root.lockRoot.password = text
                onAccepted: root.lockRoot.submit()
                // Échap : efface et revient à l'indice
                Keys.onEscapePressed: {
                    root.lockRoot.password = "";
                    root.engaged = false;
                }
                cursorDelegate: Rectangle {
                    width: 1.5
                    color: "white"
                    visible: input.activeFocus && root.fieldShown && !input.readOnly
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
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                opacity: input.text.length > 0 || root.lockRoot.authenticating ? 1 : 0
                scale: opacity > 0 ? 1 : 0.6
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
                    enabled: go.opacity > 0
                    onClicked: root.lockRoot.submit()
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: 28
                cursorShape: Qt.IBeamCursor
                onClicked: root.engage()
            }
        }

        // Message d'erreur sous le champ (ne secoue pas)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: field.bottom
            anchors.topMargin: 7
            text: root.lockRoot.errorText
            opacity: text.length > 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            font.family: Theme.font
            font.pixelSize: 11
            font.weight: Font.Medium
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
        function onShakeSerialChanged() {
            root.engaged = true;
            idle.restart();
            shakeAnim.restart();
        }
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
        NumberAnimation { target: shake; property: "x"; to: -14; duration: 50 * root.lockRoot.slowmo; easing.type: Easing.OutQuad }
        NumberAnimation { target: shake; property: "x"; to: 14; duration: 80 * root.lockRoot.slowmo; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: -10; duration: 75 * root.lockRoot.slowmo; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: 10; duration: 70 * root.lockRoot.slowmo; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: -5; duration: 65 * root.lockRoot.slowmo; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: 4; duration: 60 * root.lockRoot.slowmo; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 55 * root.lockRoot.slowmo; easing.type: Easing.OutQuad }
        ScriptAction { script: input.forceActiveFocus() }
    }

    Component.onCompleted: input.forceActiveFocus()
}
