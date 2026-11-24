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

// Disposition « organique » de macOS : chaque fenêtre part de sa position réelle
// (ramenée dans la zone disponible), puis les fenêtres qui se chevauchent sont
// écartées deux à deux selon l'axe du plus petit recouvrement. Pas de grille :
// les rangées restent décalées et chaque fenêtre reste près de sa place.
// Échelle de départ : celle de la disposition en rangées (compute), réduite
// tant que l'écartement n'aboutit pas ; repli sur les rangées en dernier recours.
// opts.screen : { x, y, w, h } géométrie de l'écran (coordonnées de `wins`)
function organic(wins, area, opts) {
    const n = wins.length;
    const rows = compute(wins, area, opts);
    if (n <= 1) return rows;
    let s = rows[0].s;
    for (let attempt = 0; attempt < 14; attempt++, s *= 0.95) {
        // Plusieurs préférences d'axe (écarter plutôt en largeur / en hauteur) :
        // on garde la disposition dont les fenêtres sont finalement les plus grandes
        let best = null;
        for (const bias of [0.5, 0.7, 1, 1.4, 2]) {
            const res = separate(wins, area, opts, s, bias);
            if (res && (!best || res[0].s > best[0].s + 1e-6)) best = res;
        }
        if (best) return best;
    }
    return rows;
}

// Écartement à l'échelle s (null si les chevauchements persistent)
function separate(wins, area, opts, s, bias) {
    const n = wins.length;
    const scr = opts.screen;
    const gapX = opts.gapX, gapY = opts.gapY;
    // Départ : la scène réelle réduite du même facteur que les fenêtres,
    // centrée dans la zone (positions relatives conservées)
    const b = wins.map(w => ({
        w: w.w * s, h: w.h * s,
        cx: area.x + area.w / 2 + (w.x + w.w / 2 - scr.x - scr.w / 2) * s,
        cy: area.y + area.h / 2 + (w.y + w.h / 2 - scr.y - scr.h / 2) * s
    }));
    const clamp = q => {
        q.cx = Math.max(area.x + q.w / 2, Math.min(area.x + area.w - q.w / 2, q.cx));
        q.cy = Math.max(area.y + q.h / 2, Math.min(area.y + area.h - q.h / 2, q.cy));
    };
    const bbox = () => {
        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (const q of b) {
            x0 = Math.min(x0, q.cx - q.w / 2); x1 = Math.max(x1, q.cx + q.w / 2);
            y0 = Math.min(y0, q.cy - q.h / 2); y1 = Math.max(y1, q.cy + q.h / 2);
        }
        return { x0: x0, y0: y0, x1: x1, y1: y1 };
    };
    b.forEach(clamp);
    let ok = false;
    for (let it = 0; it < 300 && !ok; it++) {
        ok = true;
        // Proportions de l'ensemble rapportées à celles de la zone : trop
        // large -> on écarte plutôt verticalement, et inversement
        const bb = bbox();
        const r = bias * ((bb.x1 - bb.x0) / Math.max(1, bb.y1 - bb.y0)) / (area.w / area.h);
        for (let i = 0; i < n; i++) for (let j = i + 1; j < n; j++) {
            const p = b[i], q = b[j];
            let dx = q.cx - p.cx, dy = q.cy - p.cy;
            // Fenêtres exactement superposées : ordre d'empilement
            if (Math.abs(dx) < 0.01 && Math.abs(dy) < 0.01) { dx = 0.01; dy = 0.01; }
            const ox = (p.w + q.w) / 2 + gapX - Math.abs(dx);
            const oy = (p.h + q.h) / 2 + gapY - Math.abs(dy);
            if (ox <= 0.5 || oy <= 0.5) continue;
            ok = false;
            // Axe du plus petit recouvrement, pondéré par les proportions
            if (ox * r < oy) {
                const m = (ox / 2 + 0.5) * Math.sign(dx);
                p.cx -= m; q.cx += m;
            } else {
                const m = (oy / 2 + 0.5) * Math.sign(dy);
                p.cy -= m; q.cy += m;
            }
            clamp(p); clamp(q);
        }
    }
    if (!ok) return null;
    // Ensemble agrandi uniformément pour occuper la zone (positions et
    // tailles du même facteur : aucun chevauchement ne réapparaît), sans
    // dépasser maxScale, puis centré
    const bb = bbox();
    const f = Math.max(1, Math.min(area.w / (bb.x1 - bb.x0), area.h / (bb.y1 - bb.y0), opts.maxScale / s));
    const mx = (bb.x0 + bb.x1) / 2, my = (bb.y0 + bb.y1) / 2;
    const ax = area.x + area.w / 2, ay = area.y + area.h / 2;
    return b.map(q => {
        const w = q.w * f, h = q.h * f;
        return { x: ax + (q.cx - mx) * f - w / 2, y: ay + (q.cy - my) * f - h / 2, w: w, h: h, s: s * f };
    });
}
