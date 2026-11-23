.pragma library

// Disposition des fenêtres de Mission Control : rangées sans chevauchement,
// fenêtres réduites d'un même facteur (les grandes restent plus grandes que les
// petites, comme sur macOS), ordre spatial conservé (haut -> bas, gauche ->
// droite) pour que chaque fenêtre glisse "près" de sa position réelle.
//
// wins : [{ x, y, w, h }] géométrie réelle (coordonnées de l'écran)
// area : { x, y, w, h } zone disponible
// opts : { gapX, gapY, maxScale }
// Retourne [{ x, y, w, h, s }] dans l'ordre de `wins`.
function compute(wins, area, opts) {
    const n = wins.length;
    if (n === 0) return [];
    const gapX = opts.gapX, gapY = opts.gapY, maxScale = opts.maxScale;

    const byY = wins.map((w, i) => i).sort((a, b) => (wins[a].y + wins[a].h / 2) - (wins[b].y + wins[b].h / 2));

    let best = null;
    for (let rows = 1; rows <= n; rows++) {
        // Répartition équilibrée des fenêtres (triées verticalement) en rangées
        const split = [];
        let k = 0;
        for (let r = 0; r < rows; r++) {
            const cnt = Math.floor(n / rows) + (r < n % rows ? 1 : 0);
            const row = byY.slice(k, k + cnt).sort((a, b) => (wins[a].x + wins[a].w / 2) - (wins[b].x + wins[b].w / 2));
            k += cnt;
            split.push(row);
        }
        // Facteur d'échelle maximal pour cette répartition
        let s = maxScale;
        let sumH = 0;
        for (const row of split) {
            let sumW = 0, maxH = 0;
            for (const i of row) { sumW += wins[i].w; maxH = Math.max(maxH, wins[i].h); }
            s = Math.min(s, (area.w - gapX * (row.length - 1)) / sumW);
            sumH += maxH;
        }
        s = Math.min(s, (area.h - gapY * (rows - 1)) / sumH);
        // Légère préférence pour moins de rangées à échelle quasi égale
        if (!best || s > best.s * 1.04) best = { s: s, split: split };
    }

    const s = Math.max(0.05, best.s);
    const rowH = best.split.map(row => Math.max(...row.map(i => wins[i].h)) * s);
    const total = rowH.reduce((a, b) => a + b, 0) + gapY * (best.split.length - 1);
    let y = area.y + (area.h - total) / 2;
    const out = new Array(n);
    best.split.forEach((row, r) => {
        const width = row.reduce((a, i) => a + wins[i].w * s, 0) + gapX * (row.length - 1);
        let x = area.x + (area.w - width) / 2;
        for (const i of row) {
            const w = wins[i].w * s, h = wins[i].h * s;
            out[i] = { x: x, y: y + (rowH[r] - h) / 2, w: w, h: h, s: s };
            x += w + gapX;
        }
        y += rowH[r] + gapY;
    });
    return out;
}
