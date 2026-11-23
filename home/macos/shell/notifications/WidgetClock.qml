import QtQuick
import Quickshell.Io
import qs.common

// Widget Horloge (petit, analogique) façon macOS : cadran sombre, 60 graduations, chiffres 1-12,
// aiguilles blanches à bouts arrondis, trotteuse orange, code de la ville (PAR).
Item {
    id: w

    property bool running: true
    property date now: new Date()
    property string city: "PAR"

    width: 164
    height: 164

    Timer {
        interval: 1000
        running: w.running && w.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: { w.now = new Date(); face.requestPaint(); }
    }

    // Ville du fuseau système : /etc/localtime -> .../Europe/Paris -> "PAR"
    Process {
        running: true
        command: ["readlink", "-f", "/etc/localtime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const c = text.trim().split("/").pop().replace(/_/g, " ");
                if (c) w.city = c.substring(0, 3).toUpperCase();
            }
        }
    }

    WidgetTile { anchors.fill: parent }

    Canvas {
        id: face
        anchors.fill: parent
        anchors.margins: 8
        antialiasing: true
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d");
            const s = width, c = s / 2, r = s / 2;
            ctx.reset();

            // Cadran
            ctx.beginPath();
            ctx.arc(c, c, r, 0, Math.PI * 2);
            ctx.fillStyle = Theme.dark ? "#0d0d0e" : "#ffffff";
            ctx.fill();

            // Graduations des 60 minutes au bord du cadran (plus marquées aux heures)
            ctx.lineCap = "round";
            for (let m = 0; m < 60; m++) {
                const a = m * Math.PI / 30;
                const hour = m % 5 === 0;
                const r0 = r * (hour ? 0.86 : 0.885), r1 = r * 0.95;
                ctx.strokeStyle = Theme.dark ? (hour ? "rgba(255,255,255,0.55)" : "rgba(255,255,255,0.28)")
                                             : (hour ? "rgba(0,0,0,0.45)" : "rgba(0,0,0,0.22)");
                ctx.lineWidth = hour ? 1.4 : 0.9;
                ctx.beginPath();
                ctx.moveTo(c + Math.sin(a) * r0, c - Math.cos(a) * r0);
                ctx.lineTo(c + Math.sin(a) * r1, c - Math.cos(a) * r1);
                ctx.stroke();
            }

            // Chiffres, à l'intérieur des graduations
            ctx.fillStyle = Theme.dark ? "#ffffff" : "#000000";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            ctx.font = "500 " + Math.round(s * 0.112) + "px '" + Theme.font + "'";
            for (let h = 1; h <= 12; h++) {
                const a = h * Math.PI / 6;
                ctx.fillText(String(h), c + Math.sin(a) * r * 0.70, c - Math.cos(a) * r * 0.70 + 0.5);
            }

            // Ville
            ctx.fillStyle = Theme.dark ? "rgba(255,255,255,0.55)" : "rgba(0,0,0,0.5)";
            ctx.font = "600 " + Math.round(s * 0.075) + "px '" + Theme.font + "'";
            ctx.fillText(w.city, c, c - r * 0.33);

            const t = w.now;
            const sec = t.getSeconds();
            const min = t.getMinutes() + sec / 60;
            const hr = (t.getHours() % 12) + min / 60;
            const hand = (angle, len, width, color, back) => {
                ctx.save();
                ctx.translate(c, c);
                ctx.rotate(angle);
                ctx.strokeStyle = color;
                ctx.lineWidth = width;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(0, back);
                ctx.lineTo(0, -len);
                ctx.stroke();
                ctx.restore();
            };
            const fg = Theme.dark ? "#ffffff" : "#000000";
            // Aiguille des heures / minutes : fine tige + partie large
            hand(hr * Math.PI / 6, r * 0.12, 1.6, fg, 0);
            hand(hr * Math.PI / 6, r * 0.50, 4.4, fg, -r * 0.12);
            hand(min * Math.PI / 30, r * 0.12, 1.6, fg, 0);
            hand(min * Math.PI / 30, r * 0.76, 4.4, fg, -r * 0.12);
            // Moyeu
            ctx.beginPath();
            ctx.arc(c, c, 3.2, 0, Math.PI * 2);
            ctx.fillStyle = fg;
            ctx.fill();
            // Trotteuse orange
            hand(sec * Math.PI / 30, r * 0.86, 1.2, Theme.orange.toString(), r * 0.16);
            ctx.beginPath();
            ctx.arc(c, c, 2.2, 0, Math.PI * 2);
            ctx.fillStyle = Theme.orange.toString();
            ctx.fill();
            ctx.beginPath();
            ctx.arc(c, c, 0.9, 0, Math.PI * 2);
            ctx.fillStyle = Theme.dark ? "#0d0d0e" : "#ffffff";
            ctx.fill();
        }
    }
}
