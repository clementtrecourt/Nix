.pragma library

// Catégories de la vue Applications de Tahoe : celles de l'App Library
// (iPhone/iPad), affichées en pastilles sous le champ, des plus fournies aux
// moins fournies. Libellés anglais relevés sur les captures de macOS 26
// (Cult of Mac « Spotlight-Applications » : Utilities, Social, Productivity &
// Finance, Photo & Video, Health & Fitness, Information & Reading… ; Apple
// Support mh35840 : « Productivity & Finance »). Correspondance depuis les
// catégories freedesktop (champ Categories= des .desktop).

const LIST = [
    { id: "utilities",     name: "Utilities" },
    { id: "productivity",  name: "Productivity & Finance" },
    { id: "news",          name: "Information & Reading" },
    { id: "social",        name: "Social" },
    { id: "photo",         name: "Photo & Video" },
    { id: "entertainment", name: "Entertainment" },
    { id: "graphics",      name: "Creativity" },
    { id: "developer",     name: "Developer Tools" },
    { id: "education",     name: "Education" },
    { id: "health",        name: "Health & Fitness" },
    { id: "games",         name: "Games" }
];

// Ordre de priorité : la première règle qui correspond l'emporte.
const RULES = [
    ["games",         ["Game", "ArcadeGame", "BoardGame", "CardGame", "LogicGame", "ActionGame", "AdventureGame",
                       "BlocksGame", "KidsGame", "RolePlaying", "Shooter", "Simulation", "SportsGame", "StrategyGame", "Emulator"]],
    ["developer",     ["Development", "IDE", "Debugger", "RevisionControl", "WebDevelopment", "GUIDesigner", "Profiling", "Building"]],
    ["graphics",      ["Graphics", "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics", "Publishing", "Scanning", "OCR"]],
    ["photo",         ["Photography", "AudioVideoEditing", "Recorder", "DiscBurning", "Video"]],
    ["entertainment", ["Music", "Midi", "Mixer", "Sequencer", "Audio", "TV", "Player", "AudioVideo"]],
    ["social",        ["Chat", "InstantMessaging", "IRCClient", "VideoConference", "Telephony"]],
    ["health",        ["MedicalSoftware", "Sports"]],
    ["education",     ["Education", "Science", "Math", "Astronomy", "Languages", "Geography", "Biology", "Chemistry", "Physics"]],
    ["news",          ["News", "Feed", "Dictionary", "Documentation", "Literature", "Maps", "Translation"]],
    ["productivity",  ["Office", "WordProcessor", "Spreadsheet", "Presentation", "Calendar", "ContactManagement",
                       "ProjectManagement", "Database", "Chart", "Email", "Finance", "Economy",
                       "WebBrowser", "Viewer", "TextEditor", "Network"]],
    ["utilities",     ["Utility", "System", "Settings", "TerminalEmulator", "FileManager", "FileTools", "Archiving",
                       "Compression", "Monitor", "Security", "Accessibility", "Calculator", "HardwareSettings",
                       "PackageManager", "Core", "Filesystem"]]
];

// Sans catégorie reconnue : « Utilities » (l'App Store n'a pas de fourre-tout).
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
