import QtQuick

// Une notification telle que l'affiche le shell (bannière + Centre de notifications).
// Copie "à plat" des champs utiles d'une Notification D-Bus : elle survit à la
// fermeture de la notification côté serveur et au redémarrage du shell
// (sérialisée par NotifStore). `notif` pointe vers l'objet vivant s'il existe
// encore (nécessaire pour invoquer les actions).
QtObject {
    id: entry

    property int uid: 0
    property var notif: null          // Notification vivante, null si restaurée du disque
    property string appName: ""
    property string appKey: ""        // clé de regroupement (desktop entry ou nom d'app)
    property string appIcon: ""       // chemin d'icône résolu
    property string image: ""         // image de contenu (avatar, pièce jointe)
    property string summary: ""
    property string body: ""
    property real time: 0             // horodatage (ms)
    property int urgency: 1           // 0 basse, 1 normale, 2 critique
    property bool resident: false
    property bool isTransient: false
    // Actions affichables : [{ identifier, text, ref }] (sans "default")
    property var actions: []
    property var defaultAction: null

    // Bannière actuellement affichée à l'écran
    property bool popup: false

    function serialize() {
        return {
            uid: uid, appName: appName, appKey: appKey, appIcon: appIcon,
            // Les images "image://" (données D-Bus) ne survivent pas au redémarrage
            image: image.startsWith("image://") ? "" : image,
            summary: summary, body: body, time: time, urgency: urgency
        };
    }
}
