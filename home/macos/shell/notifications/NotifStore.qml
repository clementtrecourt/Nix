pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.common
import qs.services

// Serveur de notifications + modèle partagé par les bannières et le Centre de
// notifications.
//
// Comportement macOS reproduit :
//  - une bannière s'affiche ~5 s (pause au survol) puis la notification reste dans
//    le Centre de notifications jusqu'à ce qu'on l'efface (persistée sur disque) ;
//  - les notifications "critiques" se comportent comme des alertes macOS : elles
//    restent à l'écran jusqu'à action de l'utilisateur ;
//  - regroupement par application (pile) ;
//  - "Ne pas déranger" (services/Focus.qml, s'il existe) : pas de bannière, mais la
//    notification arrive quand même dans le Centre de notifications ;
//  - System Settings > Notifications (services/SystemPrefs.qml, appliqué en
//    direct) : aperçus (Always / When Unlocked / Never), autorisation quand
//    l'écran est en veille, verrouillé ou recopié / partagé, et réglages par
//    app (autoriser, style Temporary / Persistent, bureau, Centre de
//    notifications, écran de verrouillage, son, aperçus, regroupement).
Singleton {
    id: root

    // ---- Réglages ----
    readonly property int bannerDuration: 5000   // durée d'une bannière macOS
    readonly property int maxBannerGroups: 4

    // Ralentisseur d'animations (débogage : captures image par image)
    property real slow: 1.0

    // ---- État ----
    property var entries: []          // NotifEntry, plus récente d'abord
    property int nextUid: 1
    property real now: Date.now()     // horloge pour "il y a 5 min"
    readonly property bool centerOpen: ShellState.openPanel === "notificationcenter"
    // Focus.qml est optionnel (créé par un autre composant) : typeof évite la ReferenceError.
    readonly property bool doNotDisturb: typeof Focus !== "undefined" && !!Focus.doNotDisturb

    // Bannières visibles : un élément par application ({ key }), plus récente en haut.
    // `rev` change quand une notification rejoint ou met à jour cette bannière :
    // seule la minuterie de cette bannière repart (chaque bannière a sa durée).
    property ListModel bannerModel: ListModel {}
    property int bannerRev: 0         // compteur des `rev`

    // Groupes du Centre de notifications ({ key }), synchronisés par diff pour que
    // les délégués (et leurs animations) restent stables.
    property ListModel groupModel: ListModel {}
    property var expandedGroups: ({})

    // Débogage (pas de souris dans le banc de test)
    property bool debugHover: false
    property bool debugActions: false
    property bool debugClearAll: false
    property bool debugReply: false

    // Notification en cours de réponse en ligne (la fenêtre des bannières prend
    // alors le clavier)
    property var replying: null

    readonly property int count: entries.length

    // ---------------------------------------------------------------------------
    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: false     // macOS n'affiche pas de texte enrichi
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: true

        onNotification: n => root.receive(n)
    }

    property Component entryComponent: Component { NotifEntry {} }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    // ---- Réception ----------------------------------------------------------
    function receive(n) {
        // App non autorisée (Allow notifications désactivé) : la notification
        // n'est ni affichée ni conservée (non suivie, le serveur la détruit)
        if (!confFor(groupKey(n.desktopEntry, n.appName), n.appName).allow) return;
        n.tracked = true;
        let e = entries.find(x => x.notif === n);
        // Rechargement à chaud : le serveur réémet les notifications conservées
        // (lastGeneration). On les rattache à l'entrée restaurée, sans bannière.
        if (!e && n.lastGeneration) { attach(n); return; }
        const isNew = !e;
        if (isNew) {
            e = entryComponent.createObject(root, { uid: nextUid++, notif: n, notifId: n.id });
            n.closed.connect(reason => root.onClosed(e, reason));
            watch(e, n);
        }
        fill(e, n);
        e.time = Date.now();
        // « Show in Notification Center » désactivé : seulement la bannière
        // (et l'écran de verrouillage), l'entrée est retirée ensuite
        e.centerHidden = !confOf(e).center;
        entries = [e].concat(entries.filter(x => x !== e));
        showBanner(e);
        playSound(n, e);
        if (e.centerHidden && !e.popup && !onLockScreen(e)) Qt.callLater(() => root.dismiss(e));
        scheduleSave();
    }

    // Remplacement (replaces_id : progression, lecteur…) : Quickshell ne réémet
    // pas onNotification, il met l'objet à jour sur place. On suit donc ses
    // propriétés et on recopie l'entrée (une seule fois par lot de changements).
    function watch(e, n) {
        const upd = () => root.scheduleUpdate(e, n);
        for (const sig of [n.summaryChanged, n.bodyChanged, n.appIconChanged, n.imageChanged,
                           n.actionsChanged, n.urgencyChanged, n.hintsChanged, n.appNameChanged,
                           n.desktopEntryChanged])
            sig.connect(upd);
    }
    function scheduleUpdate(e, n) {
        if (e.pendingUpdate) return;
        e.pendingUpdate = true;
        Qt.callLater(() => root.replaced(e, n));
    }
    function replaced(e, n) {
        if (!entries.includes(e)) return;
        e.pendingUpdate = false;
        if (e.notif !== n) return;
        fill(e, n);
        e.time = Date.now();
        if (entries[0] !== e) entries = [e].concat(entries.filter(x => x !== e));
        // La bannière réapparaît (ou reste affichée 5 s de plus), sans son
        showBanner(e);
        scheduleSave();
    }

    // Son de la notification (indices freedesktop "sound-file" / "sound-name"),
    // comme macOS : seulement si l'app en demande un, jamais en "Ne pas déranger".
    function playSound(n, e) {
        const h = n.hints ?? {};
        if (h["suppress-sound"] || (doNotDisturb && n.urgency < 2)) return;
        // « Play sound for notification » (réglage de l'app)
        if (e && !confOf(e).sound) return;
        // Bannière retenue (veille, recopie, écran verrouillé sans affichage
        // sur l'écran de verrouillage) : pas de son non plus
        const paused = e ? pausedReason() : "";
        if (paused !== "" && !(paused === "locked" && onLockScreen(e))) return;
        const file = h["sound-file"] ? String(h["sound-file"]).replace(/^file:\/\//, "") : "";
        const name = h["sound-name"] ? String(h["sound-name"]) : "";
        if (!file && !name) return;
        Quickshell.execDetached(["sh", "-c", soundScript, "sound", file, name]);
    }
    readonly property string soundScript: `
command -v pw-play >/dev/null || exit 0
f="$1"
if [ -z "$f" ]; then
  IFS=:
  for d in "\${XDG_DATA_HOME:-$HOME/.local/share}" \${XDG_DATA_DIRS:-/run/current-system/sw/share}; do
    for ext in oga ogg wav; do
      [ -f "$d/sounds/freedesktop/stereo/$2.$ext" ] && { f="$d/sounds/freedesktop/stereo/$2.$ext"; break 2; }
    done
  done
fi
[ -f "$f" ] && exec pw-play "$f"
`

    // Rattache une notification conservée lors d'un rechargement à son entrée
    // restaurée du disque (même id D-Bus, sinon même contenu).
    function attach(n) {
        let e = entries.find(x => !x.notif && x.notifId === n.id)
            ?? entries.find(x => !x.notif && x.summary === (n.summary ?? "")
                                 && x.body === cleanBody(n.body ?? ""));
        if (!e) {
            e = entryComponent.createObject(root, { uid: nextUid++, time: Date.now() });
            entries = [e].concat(entries);
        }
        e.notif = n;
        e.notifId = n.id;
        fill(e, n);
        n.closed.connect(reason => root.onClosed(e, reason));
        watch(e, n);
        scheduleSave();
    }

    function fill(e, n) {
        e.appKey = groupKey(n.desktopEntry, n.appName);
        e.appName = displayName(n.desktopEntry, n.appName);
        const icon = resolveIcon(n.desktopEntry, n.appIcon, n.appName);
        const img = n.image ?? "";
        // notify-send -i <nom> arrive comme image "image://icon/<nom>" : c'est l'icône
        // de l'app, pas une image de contenu.
        // Mais si ce « nom » est un chemin de fichier (notify-send -i /…/avatar.png),
        // c'est une image de contenu : avatar avec pastille de l'app (style messagerie).
        // (App inconnue : l'avatar s'affiche quand même en rond, sans pastille.)
        const iconRef = img.startsWith("image://icon/") ? decodeURIComponent(img.substring(13).split("?")[0]) : "";
        if (iconRef.startsWith("/")) {
            e.appIcon = icon;
            e.image = "file://" + iconRef;
        } else if (img.startsWith("image://icon/")) {
            e.appIcon = icon === genericIcon ? img : icon;
            e.image = "";
        } else {
            e.appIcon = icon;
            e.image = resolveImage(img, icon);
        }
        e.summary = n.summary ?? "";
        e.body = cleanBody(n.body ?? "");
        e.urgency = n.urgency;
        e.resident = n.resident;
        e.isTransient = n.transient;
        const acts = [];
        let def = null;
        for (const a of n.actions) {
            if (a.identifier === "default") def = a;
            else if (a.text) acts.push({ identifier: a.identifier, text: a.text, ref: a });
        }
        e.actions = acts;
        e.defaultAction = def;
    }

    function onClosed(e, reason) {
        // Fermée par l'application (CloseRequested) ou expirée : on la retire.
        // (Dismissed vient de nous : déjà retirée.)
        e.notif = null;
        e.actions = [];
        e.defaultAction = null;
        if (reason === NotificationCloseReason.CloseRequested || e.isTransient)
            remove(e, false);
    }

    // ---- Résolution nom / icône ------------------------------------------------
    function groupKey(desktopEntry, appName) {
        return (desktopEntry || appName || "notification").toLowerCase();
    }

    function displayName(desktopEntry, appName) {
        const e = Apps.entryFor(desktopEntry || appName);
        if (e && e.name) return e.name;
        return appName || "Notification";
    }

    function resolveIcon(desktopEntry, appIcon, appName) {
        const de = desktopEntry ? Apps.entryFor(desktopEntry) : null;
        if (de && de.icon) {
            const p = Quickshell.iconPath(de.icon, true);
            if (p) return p;
        }
        if (appIcon) {
            if (appIcon.startsWith("/")) return "file://" + appIcon;
            if (appIcon.startsWith("file://") || appIcon.startsWith("image://")) return appIcon;
            const p = Quickshell.iconPath(appIcon, true);
            if (p) return p;
        }
        const byName = appName ? Apps.entryFor(appName) : null;
        if (byName && byName.icon) {
            const p = Quickshell.iconPath(byName.icon, true);
            if (p) return p;
        }
        // Icône générique d'application (comme macOS pour un émetteur inconnu)
        return genericIcon;
    }
    readonly property string genericIcon: Quickshell.iconPath("application-x-executable", "application-default-icon")

    // Image de contenu (avatar…) : chemin, URL ou nom d'icône. Ignorée si c'est en
    // fait l'icône de l'app (notify-send -i la transmet aussi comme image).
    function resolveImage(img, appIcon) {
        if (!img) return "";
        let url = img;
        if (img.startsWith("/")) url = "file://" + img;
        else if (!img.startsWith("file://") && !img.startsWith("image://"))
            url = Quickshell.iconPath(img, true);
        return url === appIcon ? "" : (url || "");
    }

    // Corps en texte brut (certaines apps envoient du HTML malgré tout)
    function cleanBody(s) {
        return s.replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]+>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
            .replace(/&#39;/g, "'").replace(/&amp;/g, "&").trim();
    }

    // ---- Heure relative, façon macOS (anglais US) ----------------------------
    // « now », « 2m ago », « 3h ago » (jour même), « Yesterday », nom du jour
    // (semaine écoulée), puis date courte « 11/17/26 ».
    function relTime(t) {
        const d = Math.max(0, (now - t) / 1000);
        if (d < 60) return "now";
        if (d < 3600) return Math.floor(d / 60) + "m ago";
        const dt = new Date(t), today = new Date(now);
        if (dt.toDateString() === today.toDateString()) return Math.floor(d / 3600) + "h ago";
        const y = new Date(now - 86400000);
        if (dt.toDateString() === y.toDateString()) return "Yesterday";
        const d0 = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        if (dt >= new Date(d0.getTime() - 6 * 86400000))
            return ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][dt.getDay()];
        return (dt.getMonth() + 1) + "/" + dt.getDate() + "/" + String(dt.getFullYear()).slice(-2);
    }

    // ---- Bannières ------------------------------------------------------------
    function showBanner(e) {
        if (centerOpen) return;
        if (doNotDisturb && e.urgency < 2) return;
        // « Show notifications on desktop » (réglage de l'app)
        if (!confOf(e).desktop) return;
        // Écran verrouillé, en veille, recopié / partagé : pas de bannière
        if (pausedReason() !== "") return;
        e.popup = true;
        let idx = -1;
        for (let i = 0; i < bannerModel.count; i++)
            if (bannerModel.get(i).key === e.appKey) { idx = i; break; }
        bannerRev++;
        if (idx >= 0) bannerModel.setProperty(idx, "rev", bannerRev);
        if (idx > 0) bannerModel.move(idx, 0, 1);
        else if (idx < 0) bannerModel.insert(0, { key: e.appKey, rev: bannerRev });
        // Trop de bannières : on retire la plus ancienne
        while (bannerModel.count > maxBannerGroups)
            hideBanner(bannerModel.get(bannerModel.count - 1).key);
        scheduleSave();     // l'état « bannière » survit à un rechargement à chaud
    }

    function bannerItems(key) {
        return entries.filter(x => x.popup && x.appKey === key);
    }

    // Fin d'affichage d'une bannière (délai écoulé, glissement, ouverture du centre)
    function hideBanner(key) {
        for (const e of entries.filter(x => x.popup && x.appKey === key)) {
            e.popup = false;
            if (e.isTransient || e.centerHidden) dismiss(e);
        }
        for (let i = 0; i < bannerModel.count; i++)
            if (bannerModel.get(i).key === key) { bannerModel.remove(i); break; }
        scheduleSave();
    }

    function hideAllBanners() {
        while (bannerModel.count > 0) hideBanner(bannerModel.get(0).key);
    }

    onCenterOpenChanged: if (centerOpen) hideAllBanners()

    // ---- Actions utilisateur ------------------------------------------------------
    // Clic sur la notification : action par défaut, sinon on ouvre l'app (macOS).
    function activate(e) {
        if (e.defaultAction) e.defaultAction.invoke();
        else if (e.appKey && Apps.entryFor(e.appKey))
            Windows.activateApp(e.appKey, () => Apps.launch(e.appKey));
        if (!e.resident) dismiss(e);
        else hideBannerOf(e);
        if (centerOpen) ShellState.close();
    }

    // Réponse en ligne envoyée à l'app, puis la notification est rangée
    function reply(e, text) {
        if (e.notif && e.notif.hasInlineReply) e.notif.sendInlineReply(text);
        if (!e.resident) dismiss(e);
        else hideBannerOf(e);
    }

    function invoke(e, action) {
        if (action && action.ref) action.ref.invoke();
        if (!e.resident) dismiss(e);
        else hideBannerOf(e);
    }

    function hideBannerOf(e) {
        if (!e.popup) return;
        e.popup = false;
        if (bannerItems(e.appKey).length === 0) hideBanner(e.appKey);
    }

    // Effacer une notification (bouton ×)
    function dismiss(e) {
        if (e.notif) {
            const n = e.notif;
            e.notif = null;
            n.dismiss();
        }
        remove(e, true);
    }

    function remove(e, alreadyClosed) {
        if (!entries.includes(e)) return;
        if (!alreadyClosed && e.notif) { const n = e.notif; e.notif = null; n.dismiss(); }
        const wasPopup = e.popup;
        e.popup = false;
        entries = entries.filter(x => x !== e);
        if (wasPopup && bannerItems(e.appKey).length === 0) hideBanner(e.appKey);
        scheduleSave();
        Qt.callLater(() => e.destroy());
    }

    function clearGroup(key) {
        for (const e of entries.filter(x => x.appKey === key)) dismiss(e);
        setExpanded(key, false);
    }

    function clearAll() {
        for (const e of entries.slice()) dismiss(e);
        expandedGroups = ({});
    }

    function isExpanded(key) { return !!expandedGroups[key]; }
    function setExpanded(key, v) {
        const m = Object.assign({}, expandedGroups);
        if (v) m[key] = true; else delete m[key];
        expandedGroups = m;
    }

    // ---- Groupes du Centre de notifications --------------------------------------
    // Regroupement (réglage de l'app) : Automatic / By Application = une pile
    // par app ; Off = chaque notification seule
    function groupOf(e) { return confOf(e).grouping === "off" ? e.appKey + "#" + e.uid : e.appKey; }
    function groupItems(key) { return entries.filter(x => !x.centerHidden && groupOf(x) === key); }

    onEntriesChanged: syncGroups()
    function syncGroups() {
        const keys = [];
        for (const e of entries) {
            if (e.centerHidden) continue;
            const k = groupOf(e);
            if (!keys.includes(k)) keys.push(k);
        }
        // Supprime les groupes disparus
        for (let i = groupModel.count - 1; i >= 0; i--)
            if (!keys.includes(groupModel.get(i).key)) groupModel.remove(i);
        // Insère / réordonne
        for (let i = 0; i < keys.length; i++) {
            let cur = -1;
            for (let j = 0; j < groupModel.count; j++)
                if (groupModel.get(j).key === keys[i]) { cur = j; break; }
            if (cur < 0) groupModel.insert(i, { key: keys[i] });
            else if (cur !== i) groupModel.move(cur, i, 1);
        }
    }

    // ---- Persistance --------------------------------------------------------------
    FileView {
        id: store
        path: Quickshell.statePath("notifications.json")
        printErrors: false
        blockLoading: true
        atomicWrites: true
    }

    Timer {
        id: saveTimer
        interval: 600
        onTriggered: {
            const data = entries.map(e => Object.assign(e.serialize(), { notifId: e.notif ? e.notif.id : -1 }));
            // pid : distingue un rechargement à chaud (même processus, ids D-Bus et
            // bannières encore valides) d'un redémarrage complet.
            store.setText(JSON.stringify({ version: 1, pid: Quickshell.processId, nextUid: root.nextUid,
                                           entries: data }, null, 1));
        }
    }
    function scheduleSave() { saveTimer.restart(); }
    // Rechargement à chaud imminent : on écrit tout de suite
    Component.onDestruction: if (saveTimer.running) { saveTimer.stop(); saveTimer.triggered(); }

    Component.onCompleted: {
        let saved = [];
        let sameProcess = false;
        try {
            const t = store.text();
            if (t) {
                const j = JSON.parse(t);
                saved = j.entries ?? [];
                nextUid = Math.max(nextUid, j.nextUid ?? 1);
                sameProcess = j.pid === Quickshell.processId;
            }
        } catch (err) { saved = []; }

        const list = [];
        for (const s of saved) {
            // Déjà rattachée (réémise par le serveur avant ce point) : on ignore la copie
            if (entries.some(e => e.notif && e.notif.id === s.notifId)) continue;
            // Après un redémarrage complet, les ids D-Bus de l'ancienne session ne
            // désignent plus rien (et pourraient être réattribués) : on les oublie.
            const e = entryComponent.createObject(root, {
                uid: s.uid ?? nextUid++, notifId: sameProcess ? (s.notifId ?? -1) : -1, appName: s.appName ?? "",
                appKey: s.appKey ?? "", appIcon: s.appIcon ?? "", image: s.image ?? "",
                summary: s.summary ?? "", body: s.body ?? "", time: s.time ?? Date.now(),
                urgency: s.urgency ?? 1
            });
            e.wasPopup = sameProcess && !!s.popup;
            list.push(e);
        }
        entries = entries.concat(list).sort((a, b) => b.time - a.time);

        // Après un rechargement à chaud, le serveur garde ses notifications : on les
        // rattache aux entrées restaurées au lieu de les dupliquer.
        for (const n of server.trackedNotifications.values)
            if (!entries.some(e => e.notif === n)) attach(n);

        // Rechargement à chaud : les bannières qui étaient à l'écran y reviennent
        for (const e of entries.slice().reverse())
            if (e.wasPopup) { e.wasPopup = false; showBanner(e); }
    }

    // ---- Réglages (System Settings > Notifications) ---------------------------------
    // Réglages de l'app d'une entrée (clé de regroupement + id .desktop connu)
    function confFor(appKey, appName) {
        const de = Apps.entryFor(appKey) ?? (appName ? Apps.entryFor(appName) : null);
        return SystemPrefs.appConf(de?.id ?? appKey, appKey);
    }
    function confOf(e) { return e ? confFor(e.appKey, e.appName) : SystemPrefs.appNotifDefaults; }

    // Style « Persistent » : la bannière reste jusqu'à ce qu'on la ferme
    function isPersistent(e) { return !!e && confOf(e).style === "persistent"; }

    // Aperçu masqué (« Show previews ») : réglage de l'app, sinon réglage global.
    // When Unlocked = masqué tant que l'écran est verrouillé.
    function previewHidden(e) {
        if (!e) return false;
        const own = confOf(e).previews;
        const p = own && own !== "default" ? own : SystemPrefs.notifPreviews;
        return p === "never" || (p === "unlocked" && ShellState.locked);
    }

    // Notification affichée sur l'écran de verrouillage : reçue depuis le
    // verrouillage, autorisée globalement et pour l'app
    function onLockScreen(e) {
        return ShellState.locked && SystemPrefs.notifLocked && e.time >= ShellState.lockedSince && confOf(e).lock;
    }
    // Notifications de l'écran de verrouillage (plus récente d'abord)
    readonly property var lockEntries: {
        entries; SystemPrefs.appNotif; SystemPrefs.notifLocked; ShellState.locked; ShellState.lockedSince;
        return entries.filter(e => root.onLockScreen(e));
    }

    // Pourquoi les bannières sont retenues ("" = rien ne les retient) : écran
    // verrouillé (elles vont sur l'écran de verrouillage), écran en veille ou
    // recopié / partagé sans autorisation
    function pausedReason() {
        if (ShellState.locked) return "locked";
        if (!SystemPrefs.notifSleeping && DisplayState.asleep) return "sleeping";
        if (!SystemPrefs.notifMirroring && (DisplayState.mirroring || DisplayState.sharing)) return "mirroring";
        return "";
    }

    // Réglages changés : regroupement et visibilité dans le Centre réévalués
    Connections {
        target: SystemPrefs
        function onAppNotifChanged() { root.syncGroups(); }
    }
    // Déverrouillage : les notifications gardées seulement pour l'écran de
    // verrouillage (absentes du Centre) disparaissent
    Connections {
        target: ShellState
        function onLockedChanged() {
            if (ShellState.locked) return;
            for (const e of root.entries.filter(x => x.centerHidden && !x.popup)) root.dismiss(e);
        }
    }

    // ---- IPC -----------------------------------------------------------------------
    IpcHandler {
        target: "notifications"
        function toggleCenter(): void { ShellState.toggle("notificationcenter"); }
        function clearAll(): void { root.clearAll(); }
        function count(): int { return root.entries.length; }
        function doNotDisturb(): bool { return root.doNotDisturb; }
        function list(): string {
            return root.entries.map(e => [e.uid, e.appKey, e.appName, e.summary, e.appIcon, e.image, e.popup ? "[banner]" : ""].join("\t")).join("\n");
        }
    }

    // Débogage : forcer le survol, ralentir les animations, déplier un groupe.
    IpcHandler {
        target: "notifications-debug"
        function hover(on: bool): void { root.debugHover = on; }
        function actions(on: bool): void { root.debugActions = on; }
        function reply(on: bool): void { root.debugReply = on; }
        function clearAllHover(on: bool): void { root.debugClearAll = on; }
        function slow(factor: real): void { root.slow = factor; }
        function expand(key: string, on: bool): void { root.setExpanded(key, on); }
        function dismissFirst(): void { if (root.entries.length) root.dismiss(root.entries[0]); }
        function invokeFirst(index: int): void {
            const e = root.entries[0];
            if (e && e.actions[index]) root.invoke(e, e.actions[index]);
        }
        function activateFirst(): void { if (root.entries.length) root.activate(root.entries[0]); }
        function hideBanners(): void { root.hideAllBanners(); }
        // Apparence en mémoire seulement (captures claires / sombres)
        function dark(on: bool): void { Theme.dark = on; }
        // Injection d'une notification factice (dans le banc, la session hôte
        // possède déjà org.freedesktop.Notifications). `actions` : libellés
        // séparés par « | » ; `minutesAgo` : antidatage (heure relative).
        function inject(app: string, summary: string, body: string, actions: string,
                        urgency: int, image: string, minutesAgo: int): void {
            root.injectFake(app, summary, body, actions, urgency, image, minutesAgo);
        }
    }
    function injectFake(app, summary, body, actions, urgency, image, minutesAgo) {
        if (!confFor(groupKey(app, app), app).allow) return;
        const e = entryComponent.createObject(root, {
            uid: nextUid++, appKey: groupKey(app, app), appName: displayName(app, app),
            appIcon: resolveIcon(app, "", app), image: image ? (image.startsWith("/") ? "file://" + image : image) : "",
            summary: summary, body: body, urgency: urgency,
            time: Date.now() - minutesAgo * 60000
        });
        e.actions = actions ? actions.split("|").map((t, i) => ({ identifier: "a" + i, text: t, ref: null })) : [];
        e.centerHidden = !confOf(e).center;
        entries = [e].concat(entries).sort((a, b) => b.time - a.time);
        if (minutesAgo === 0) showBanner(e);
        scheduleSave();
    }
}
