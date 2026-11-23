.pragma library

// Recherche floue façon Spotlight : préfixe > début de mot > initiales >
// sous-chaîne > sous-séquence. Insensible à la casse et aux accents.

function fold(s) {
    return (s ?? "").toString().normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

// Score 0..100 de `q` (déjà replié) dans `text`.
function score(q, text) {
    if (!q || !text) return 0;
    const t = fold(text);
    if (t === q) return 100;
    if (t.startsWith(q)) return 92 - Math.min(10, (t.length - q.length) * 0.3);
    // Début d'un mot ("code" dans "Visual Studio Code", "ca" dans "Image Capture")
    const words = t.split(/[\s\-_.\/]+/).filter(w => w.length);
    for (let i = 1; i < words.length; i++) {
        if (words[i].startsWith(q)) return 80 - i;
    }
    // Initiales ("vsc" -> Visual Studio Code)
    if (q.length >= 2) {
        const initials = words.map(w => w[0]).join("");
        if (initials.startsWith(q)) return 72;
    }
    const idx = t.indexOf(q);
    if (idx >= 0) return 55 - Math.min(15, idx);
    // Sous-séquence avec bonus de contiguïté
    if (q.length < 3) return 0;
    let ti = 0, run = 0, best = 0, hits = 0;
    for (let qi = 0; qi < q.length; qi++) {
        const found = t.indexOf(q[qi], ti);
        if (found < 0) return 0;
        run = (found === ti) ? run + 1 : 1;
        best = Math.max(best, run);
        hits++;
        ti = found + 1;
    }
    return 18 + best * 3 - Math.min(10, (t.length - q.length) * 0.2);
}
