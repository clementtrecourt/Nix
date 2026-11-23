.pragma library

// Calculatrice et conversions d'unités de Spotlight (sans eval : petit analyseur
// à descente récursive). Renvoie null si la requête n'est pas un calcul.
//
//   evaluate("2*(3+4)^2")      -> { kind: "calc", value: 98, expr: "2*(3+4)^2" }
//   evaluate("10 km en mi")    -> { kind: "convert", value: 6.2137, unit: "mi", ... }
//   evaluate("72 °F")          -> { kind: "convert", ... vers °C }

// ---------------------------------------------------------------- Expressions

const FUNCS = {
    sqrt: Math.sqrt, racine: Math.sqrt, cbrt: Math.cbrt,
    sin: x => Math.sin(x), cos: x => Math.cos(x), tan: x => Math.tan(x),
    asin: Math.asin, acos: Math.acos, atan: Math.atan,
    sinh: Math.sinh, cosh: Math.cosh, tanh: Math.tanh,
    ln: Math.log, log: Math.log10, log10: Math.log10, log2: Math.log2,
    exp: Math.exp, abs: Math.abs, round: Math.round, arrondi: Math.round,
    floor: Math.floor, ceil: Math.ceil
};
const CONSTS = { pi: Math.PI, "π": Math.PI, e: Math.E, tau: 2 * Math.PI };

function tokenize(src) {
    const out = [];
    let i = 0;
    while (i < src.length) {
        const c = src[i];
        if (c === " " || c === " " || c === " ") { i++; continue; }
        // Nombre : "3.5", "3,5" (virgule décimale française), "1e3"
        if (/[0-9.,]/.test(c)) {
            let j = i;
            while (j < src.length && /[0-9.,]/.test(src[j])) j++;
            if (j < src.length && /[eE]/.test(src[j]) && /[0-9+-]/.test(src[j + 1] ?? "")) {
                j++;
                if (/[+-]/.test(src[j])) j++;
                while (j < src.length && /[0-9]/.test(src[j])) j++;
            }
            let txt = src.slice(i, j);
            // "1,234.5" -> séparateur de milliers ; "3,5" -> décimale
            if (txt.includes(",") && txt.includes(".")) txt = txt.replace(/,/g, "");
            else txt = txt.replace(",", ".");
            const v = Number(txt);
            if (isNaN(v)) return null;
            out.push({ t: "num", v: v });
            i = j;
            continue;
        }
        // "3 x 4" : x entre deux nombres = multiplication
        if ((c === "x" || c === "X") && out.length && out[out.length - 1].t === "num"
                && /^\s*[0-9(]/.test(src.slice(i + 1))) {
            out.push({ t: "op", v: "*" });
            i++;
            continue;
        }
        if (/[a-zA-Zπ]/.test(c)) {
            let j = i;
            while (j < src.length && /[a-zA-Z0-9π]/.test(src[j])) j++;
            out.push({ t: "id", v: src.slice(i, j).toLowerCase() });
            i = j;
            continue;
        }
        const map = { "×": "*", "x": "*", "÷": "/", "−": "-", "–": "-", "**": "^" };
        if (src.startsWith("**", i)) { out.push({ t: "op", v: "^" }); i += 2; continue; }
        if ("+-*/^()%!".includes(c) || map[c]) {
            out.push({ t: "op", v: map[c] ?? c });
            i++;
            continue;
        }
        return null;
    }
    return out;
}

function parse(tokens) {
    let p = 0;
    let usedOp = false;
    const peek = () => tokens[p];
    const isOp = v => peek() && peek().t === "op" && peek().v === v;

    function expr() {
        let v = term();
        while (isOp("+") || isOp("-")) {
            const op = tokens[p++].v;
            usedOp = true;
            const r = term();
            v = op === "+" ? v + r : v - r;
        }
        return v;
    }
    function term() {
        let v = unary();
        for (;;) {
            if (isOp("*") || isOp("/")) {
                const op = tokens[p++].v;
                usedOp = true;
                const r = unary();
                v = op === "*" ? v * r : v / r;
            } else if (peek() && (peek().t === "id" || isOp("(")) ) {
                // Multiplication implicite : 2pi, 3(4+1)
                usedOp = true;
                v = v * unary();
            } else break;
        }
        return v;
    }
    function unary() {
        if (isOp("-")) { p++; return -unary(); }
        if (isOp("+")) { p++; return unary(); }
        return power();
    }
    function power() {
        let b = postfix();
        if (isOp("^")) { p++; usedOp = true; return Math.pow(b, unary()); }
        return b;
    }
    function postfix() {
        let v = primary();
        for (;;) {
            if (isOp("!")) {
                p++; usedOp = true;
                if (v < 0 || v > 170 || v !== Math.floor(v)) throw "fact";
                let r = 1; for (let k = 2; k <= v; k++) r *= k;
                v = r;
            } else if (isOp("%")) {
                p++; usedOp = true; v = v / 100;
            } else break;
        }
        return v;
    }
    function primary() {
        const tk = tokens[p++];
        if (!tk) throw "eof";
        if (tk.t === "num") return tk.v;
        if (tk.t === "op" && tk.v === "(") {
            const v = expr();
            if (isOp(")")) p++;          // parenthèse fermante facultative en fin
            else if (p < tokens.length) throw "paren";
            return v;
        }
        if (tk.t === "id") {
            if (tk.v in CONSTS) return CONSTS[tk.v];
            if (tk.v in FUNCS) {
                usedOp = true;
                const a = isOp("(") ? primary() : unary();
                return FUNCS[tk.v](a);
            }
        }
        throw "tok";
    }

    const v = expr();
    if (p !== tokens.length) throw "trail";
    return { value: v, usedOp: usedOp };
}

function calc(q) {
    const s = q.trim().replace(/=$/, "").trim();
    if (!s || !/[0-9π]/.test(s) && !/\b(pi|e|tau)\b/i.test(s)) return null;
    const tk = tokenize(s);
    if (!tk || tk.length < 2) return null;
    try {
        const r = parse(tk);
        if (!r.usedOp || !isFinite(r.value)) return null;
        return { kind: "calc", value: r.value, expr: s };
    } catch (e) {
        return null;
    }
}

// ---------------------------------------------------------------- Unités

// Facteurs vers l'unité de base de chaque dimension.
const UNITS = {};
function def(dim, names, factor, label) {
    for (const n of names) UNITS[n] = { dim: dim, f: factor, label: label ?? names[0] };
}
// Longueur (m)
def("len", ["mm", "millimètre", "millimètres", "millimetre", "millimetres"], 0.001, "mm");
def("len", ["cm", "centimètre", "centimètres", "centimetre", "centimetres"], 0.01, "cm");
def("len", ["m", "mètre", "mètres", "metre", "metres", "meter", "meters"], 1, "m");
def("len", ["km", "kilomètre", "kilomètres", "kilometre", "kilometres", "kilometer", "kilometers"], 1000, "km");
def("len", ["in", "inch", "inches", "pouce", "pouces", "\""], 0.0254, "po");
def("len", ["ft", "foot", "feet", "pied", "pieds", "'"], 0.3048, "pi");
def("len", ["yd", "yard", "yards"], 0.9144, "yd");
def("len", ["mi", "mile", "miles"], 1609.344, "mi");
def("len", ["nmi", "mille", "milles"], 1852, "nmi");
// Masse (kg)
def("mass", ["mg", "milligramme", "milligrammes"], 1e-6, "mg");
def("mass", ["g", "gramme", "grammes", "gram", "grams"], 0.001, "g");
def("mass", ["kg", "kilo", "kilos", "kilogramme", "kilogrammes", "kilogram", "kilograms"], 1, "kg");
def("mass", ["t", "tonne", "tonnes"], 1000, "t");
def("mass", ["lb", "lbs", "livre", "livres", "pound", "pounds"], 0.45359237, "lb");
def("mass", ["oz", "once", "onces", "ounce", "ounces"], 0.028349523125, "oz");
// Volume (l)
def("vol", ["ml", "millilitre", "millilitres"], 0.001, "ml");
def("vol", ["cl", "centilitre", "centilitres"], 0.01, "cl");
def("vol", ["dl", "décilitre", "décilitres"], 0.1, "dl");
def("vol", ["l", "litre", "litres", "liter", "liters"], 1, "l");
def("vol", ["m3", "m³"], 1000, "m³");
def("vol", ["gal", "gallon", "gallons"], 3.785411784, "gal");
def("vol", ["floz"], 0.0295735, "fl oz");
def("vol", ["cup", "cups", "tasse", "tasses"], 0.2365882365, "tasses");
// Surface (m²)
def("area", ["m2", "m²"], 1, "m²");
def("area", ["km2", "km²"], 1e6, "km²");
def("area", ["ha", "hectare", "hectares"], 1e4, "ha");
def("area", ["acre", "acres"], 4046.8564224, "acres");
def("area", ["ft2", "ft²"], 0.09290304, "ft²");
// Durée (s)
def("time", ["ms", "milliseconde", "millisecondes"], 0.001, "ms");
def("time", ["s", "sec", "seconde", "secondes", "second", "seconds"], 1, "s");
def("time", ["min", "minute", "minutes"], 60, "min");
def("time", ["h", "heure", "heures", "hour", "hours"], 3600, "h");
def("time", ["j", "jour", "jours", "d", "day", "days"], 86400, "jours");
def("time", ["sem", "semaine", "semaines", "week", "weeks"], 604800, "semaines");
def("time", ["an", "ans", "année", "années", "year", "years"], 31557600, "ans");
// Vitesse (m/s)
def("speed", ["m/s"], 1, "m/s");
def("speed", ["km/h", "kmh"], 1 / 3.6, "km/h");
def("speed", ["mph"], 0.44704, "mph");
def("speed", ["kn", "nœud", "nœuds", "noeud", "noeuds", "knot", "knots"], 0.514444, "nœuds");
// Données (octets)
def("data", ["o", "octet", "octets", "b", "byte", "bytes"], 1, "o");
def("data", ["ko", "kb"], 1e3, "Ko");
def("data", ["mo", "mb"], 1e6, "Mo");
def("data", ["go", "gb"], 1e9, "Go");
def("data", ["to", "tb"], 1e12, "To");
def("data", ["kio", "kib"], 1024, "Kio");
def("data", ["mio", "mib"], 1048576, "Mio");
def("data", ["gio", "gib"], 1073741824, "Gio");
def("data", ["tio", "tib"], 1099511627776, "Tio");
// Température (traitée à part)
def("temp", ["°c", "c", "celsius", "degrés", "degres"], 0, "°C");
def("temp", ["°f", "f", "fahrenheit"], 0, "°F");
def("temp", ["k", "kelvin", "kelvins"], 0, "K");

// Cible par défaut quand on tape "10 km" sans "en …" (comme Spotlight).
const DEFAULT_TARGET = {
    "km": "mi", "mi": "km", "m": "pi", "pi": "m", "cm": "po", "po": "cm", "mm": "po",
    "yd": "m", "nmi": "km",
    "kg": "lb", "lb": "kg", "g": "oz", "oz": "g", "t": "lb", "mg": "oz",
    "l": "gal", "gal": "l", "ml": "fl oz", "cl": "fl oz", "dl": "tasses", "tasses": "ml", "m³": "l", "fl oz": "ml",
    "°C": "°F", "°F": "°C", "K": "°C",
    "km/h": "mph", "mph": "km/h", "m/s": "km/h", "nœuds": "km/h",
    "m²": "ft²", "ft²": "m²", "ha": "acres", "acres": "ha", "km²": "ha",
    "h": "min", "min": "s", "s": "min", "jours": "h", "semaines": "jours", "ans": "jours", "ms": "s",
    "Go": "Mo", "Mo": "Ko", "Ko": "o", "To": "Go", "o": "Ko", "Gio": "Go", "Mio": "Mo", "Kio": "Ko", "Tio": "To"
};

function unitByLabel(label) {
    for (const k in UNITS) if (UNITS[k].label === label) return UNITS[k];
    return null;
}

function lookupUnit(name) {
    if (!name) return null;
    const n = name.trim().toLowerCase().replace(/^°\s*/, "°");
    return UNITS[n] ?? UNITS[n.replace(/s$/, "")] ?? null;
}

function toBase(u, v) {
    if (u.dim !== "temp") return v * u.f;
    if (u.label === "°C") return v + 273.15;
    if (u.label === "°F") return (v - 32) * 5 / 9 + 273.15;
    return v;
}
function fromBase(u, v) {
    if (u.dim !== "temp") return v / u.f;
    if (u.label === "°C") return v - 273.15;
    if (u.label === "°F") return (v - 273.15) * 9 / 5 + 32;
    return v;
}

function convert(q) {
    const m = q.trim().match(/^(-?[0-9][0-9.,\s]*)\s*([^\s0-9][^\s]*?)(?:\s+(?:en|in|to|vers|→|->|=)\s+([^\s]+))?\s*$/i);
    if (!m) return null;
    const num = Number(m[1].replace(/\s/g, "").replace(",", "."));
    if (isNaN(num)) return null;
    const from = lookupUnit(m[2]);
    if (!from) return null;
    // Un nombre suivi de "c", "f", "k", "j", "t"… seul est ambigu : on exige
    // la forme explicite pour les unités d'une lettre hors m/g/l/s/h.
    if (!m[3] && m[2].length === 1 && !"mglsh".includes(m[2].toLowerCase())) return null;
    let to = m[3] ? lookupUnit(m[3]) : unitByLabel(DEFAULT_TARGET[from.label]);
    if (!to || to.dim !== from.dim || to === from) return null;
    const value = fromBase(to, toBase(from, num));
    if (!isFinite(value)) return null;
    return { kind: "convert", value: value, input: num, fromUnit: from.label, unit: to.label };
}

// ---------------------------------------------------------------- Formatage

// Format français : espace fine insécable pour les milliers, virgule décimale.
// maxDecimals : arrondi optionnel (conversions : 4 décimales au plus).
function format(v, maxDecimals) {
    if (!isFinite(v)) return String(v);
    if (v !== 0 && (Math.abs(v) >= 1e15 || Math.abs(v) < 1e-9)) {
        return v.toExponential(6).replace(/\.?0+e/, "e").replace(".", ",");
    }
    if (maxDecimals !== undefined && Math.abs(v) >= Math.pow(10, -maxDecimals))
        v = Number(v.toFixed(maxDecimals));
    let s = Number(v.toPrecision(12)).toString();
    if (s.includes("e")) return s.replace(".", ",");
    const neg = s.startsWith("-");
    if (neg) s = s.slice(1);
    const parts = s.split(".");
    const int = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, " ");
    return (neg ? "−" : "") + int + (parts[1] ? "," + parts[1] : "");
}

function evaluate(q) {
    if (!q || q.length > 200) return null;
    return convert(q) ?? calc(q);
}
