.pragma library

// Catégories de la vue Applications de Tahoe : ce sont celles de l'App Store
// (« Utilitaires », « Productivité », « Actualités », « Réseaux sociaux »,
// « Musique », « Photo et vidéo »…), affichées en pastilles sous le champ, des
// plus fournies aux moins fournies. Correspondance depuis les catégories
// freedesktop (champ Categories= des .desktop).

const LIST = [
    { id: "utilities",     name: "Utilitaires" },
    { id: "productivity",  name: "Productivité" },
    { id: "news",          name: "Actualités" },
    { id: "social",        name: "Réseaux sociaux" },
    { id: "music",         name: "Musique" },
    { id: "photo",         name: "Photo et vidéo" },
    { id: "entertainment", name: "Divertissement" },
    { id: "graphics",      name: "Graphisme et design" },
    { id: "developer",     name: "Outils de développement" },
    { id: "education",     name: "Éducation" },
    { id: "reference",     name: "Référence" },
    { id: "finance",       name: "Finance" },
    { id: "games",         name: "Jeux" }
];

// Ordre de priorité : la première règle qui correspond l'emporte.
const RULES = [
    ["games",         ["Game", "ArcadeGame", "BoardGame", "CardGame", "LogicGame", "ActionGame", "AdventureGame",
                       "BlocksGame", "KidsGame", "RolePlaying", "Shooter", "Simulation", "SportsGame", "StrategyGame", "Emulator"]],
    ["developer",     ["Development", "IDE", "Debugger", "RevisionControl", "WebDevelopment", "GUIDesigner", "Profiling", "Building"]],
    ["graphics",      ["Graphics", "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics", "Publishing", "Scanning", "OCR"]],
    ["photo",         ["Photography", "AudioVideoEditing", "Recorder", "DiscBurning"]],
    ["music",         ["Music", "Midi", "Mixer", "Sequencer", "Audio"]],
    ["entertainment", ["Video", "TV", "Player", "AudioVideo"]],
    ["social",        ["Chat", "InstantMessaging", "IRCClient", "VideoConference", "Telephony"]],
    ["education",     ["Education", "Science", "Math", "Astronomy", "Languages", "Geography", "Biology", "Chemistry", "Physics"]],
    ["reference",     ["Dictionary", "Documentation", "Literature", "Maps", "Translation"]],
    ["news",          ["News", "Feed"]],
    ["finance",       ["Finance", "Economy"]],
    ["productivity",  ["Office", "WordProcessor", "Spreadsheet", "Presentation", "Calendar", "ContactManagement",
                       "ProjectManagement", "Database", "Chart", "Email", "WebBrowser", "Viewer", "TextEditor", "Network"]],
    ["utilities",     ["Utility", "System", "Settings", "TerminalEmulator", "FileManager", "FileTools", "Archiving",
                       "Compression", "Monitor", "Security", "Accessibility", "Calculator", "HardwareSettings",
                       "PackageManager", "Core", "Filesystem"]]
];

// Sans catégorie reconnue : « Utilitaires » (l'App Store n'a pas de fourre-tout).
function categoryOf(cats) {
    const set = {};
    for (const c of (cats ?? [])) set[c] = true;
    for (const r of RULES) {
        for (const c of r[1]) if (set[c]) return r[0];
    }
    return "utilities";
}

function nameOf(id) {
    for (const c of LIST) if (c.id === id) return c.name;
    return "";
}
