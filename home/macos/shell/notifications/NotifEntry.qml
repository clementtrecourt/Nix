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
    property int notifId: -1          // id D-Bus (rattachement après rechargement)
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
    // Réponse en ligne possible (Messages, etc.) : seulement tant que la
    // notification D-Bus est vivante.
    readonly property bool canReply: !!notif && notif.hasInlineReply
    readonly property string replyPlaceholder: notif ? (notif.inlineReplyPlaceholder ?? "") : ""

    // Bannière actuellement affichée à l'écran
    property bool popup: false
    // « Show in Notification Center » désactivé pour l'app : absente du Centre
    property bool centerHidden: false
    // Interne (NotifStore) : mise à jour de remplacement en attente ; bannière à
    // réafficher après un rechargement à chaud
    property bool pendingUpdate: false
    property bool wasPopup: false

    function serialize() {
        return {
            uid: uid, notifId: notif ? notif.id : -1, appName: appName, appKey: appKey, appIcon: appIcon,
            // Les images "image://" (données D-Bus) ne survivent pas au redémarrage
            image: image.startsWith("image://") ? "" : image,
            summary: summary, body: body, time: time, urgency: urgency, popup: popup
        };
    }
}
