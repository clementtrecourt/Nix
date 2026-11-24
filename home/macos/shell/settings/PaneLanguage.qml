import QtQuick
import qs.common

// General > Language & Region (Tahoe 26), en lecture : langues préférées
// (LANG / LANGUAGE), région, calendrier, température, système de mesure,
// premier jour de la semaine, formats de date et de nombre (locale active).
PaneBase {
    id: root

    property var env: ({})
    ProcessText {
        running: true
        command: ["sh", "-c", 'locale 2>/dev/null; printf "LANGUAGE=%s\\n" "$LANGUAGE"']
        onDone: (t) => {
            const o = {};
            for (const l of t.split("\n")) { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1).replace(/"/g, ""); }
            root.env = o;
        }
    }
    function langName(code) {
        const names = { en_US: "English (US) — Primary", en_GB: "English (UK) — Primary", fr_FR: "French", de_DE: "German", es_ES: "Spanish", it_IT: "Italian", C: "English (US) — Primary" };
        const c = (code ?? "").split(".")[0];
        return names[c] ?? c;
    }
    readonly property string region: {
        const c = ((env.LC_TIME || env.LANG || "en_US").split(".")[0].split("_")[1]) ?? "US";
        return ({ US: "United States", FR: "France", GB: "United Kingdom", DE: "Germany", CA: "Canada", ES: "Spain", IT: "Italy", BE: "Belgium", CH: "Switzerland" })[c] ?? c;
    }
    readonly property bool metric: region !== "United States"

    SSection { text: "Preferred Languages" }
    SGroup {
        Repeater {
            model: (root.env.LANGUAGE ? root.env.LANGUAGE.split(":") : [root.env.LANG || "en_US"]).filter(x => x)
            SRow {
                required property string modelData
                required property int index
                title: index === 0 ? "English (US) — Primary" : root.langName(modelData)
                subtitle: index === 0 ? "English (US)" : ""
                minHeight: 44
            }
        }
    }
    SNote { text: "Apps and websites will use the first language in this list that they support." }
    SGroup {
        SRow { title: "Region"; detail: root.region }
        SRow { title: "Calendar"; detail: "Gregorian" }
        SRow { title: "Temperature"; detail: root.metric ? "Celsius (°C)" : "Fahrenheit (°F)" }
        SRow { title: "Measurement system"; detail: root.metric ? "Metric" : "US" }
        SRow { title: "First day of week"; detail: root.metric ? "Monday" : "Sunday" }
        SRow { title: "Date format"; detail: Qt.formatDate(new Date(2026, 0, 19), root.metric ? "dd/MM/yyyy" : "M/d/yy") }
        SRow { title: "Number format"; detail: root.metric ? "1 234 567,89" : "1,234,567.89" }
    }
    SNote { text: "Region: " + root.region + " · Locale: " + (root.env.LANG || "C") + ". Languages and formats are set in your NixOS configuration (i18n)." }
}
