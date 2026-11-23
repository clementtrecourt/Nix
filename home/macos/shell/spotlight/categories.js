.pragma library

// Catégories de la vue Applications de Tahoe (celles de l'App Store, comme la
// bibliothèque d'apps d'iOS), dans l'ordre d'affichage, avec la correspondance
// depuis les catégories freedesktop (champ Categories= des .desktop).

const LIST = [
    { id: "productivity", name: "Productivité et finance" },
    { id: "creativity",   name: "Créativité" },
    { id: "social",       name: "Réseaux sociaux" },
    { id: "entertainment", name: "Divertissement" },
    { id: "reading",      name: "Informations et lecture" },
    { id: "education",    name: "Éducation" },
    { id: "games",        name: "Jeux" },
    { id: "developer",    name: "Outils de développement" },
    { id: "utilities",    name: "Utilitaires" },
    { id: "other",        name: "Autres" }
];

// Ordre de priorité : la première règle qui correspond l'emporte.
const RULES = [
    ["games",        ["Game", "ArcadeGame", "BoardGame", "CardGame", "LogicGame", "Emulator"]],
    ["developer",    ["Development", "IDE", "Debugger", "RevisionControl", "WebDevelopment", "GUIDesigner", "Profiling", "Translation"]],
    ["social",       ["Chat", "InstantMessaging", "IRCClient", "VideoConference", "Telephony", "Email"]],
    ["creativity",   ["Graphics", "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics", "Photography", "AudioVideoEditing", "Midi", "Mixer", "Sequencer", "Recorder", "Publishing"]],
    ["entertainment", ["Player", "Music", "Video", "TV", "Audio", "AudioVideo"]],
    ["education",    ["Education", "Science", "Math", "Astronomy", "Languages", "Geography", "Dictionary"]],
    ["productivity", ["Office", "Finance", "WordProcessor", "Spreadsheet", "Presentation", "Calendar", "ContactManagement", "ProjectManagement", "Database", "Chart", "Viewer"]],
    ["reading",      ["WebBrowser", "News", "Feed", "Literature", "Documentation", "Maps"]],
    ["utilities",    ["Utility", "System", "Settings", "TerminalEmulator", "FileManager", "FileTools", "Archiving", "Compression", "Monitor", "Security", "Accessibility", "Calculator", "TextEditor", "Network", "HardwareSettings", "PackageManager", "Core"]]
];

function categoryOf(cats) {
    const set = {};
    for (const c of (cats ?? [])) set[c] = true;
    for (const r of RULES) {
        for (const c of r[1]) if (set[c]) return r[0];
    }
    return "other";
}

function nameOf(id) {
    for (const c of LIST) if (c.id === id) return c.name;
    return "";
}
