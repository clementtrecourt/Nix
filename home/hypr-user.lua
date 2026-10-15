-- Animations rapides et snappy (speed en dixièmes de seconde : plus bas = plus rapide)
hl.curve("snappy", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("snappyOut", { type = "bezier", points = { { 0.4, 0 }, { 0.6, 1 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.5, bezier = "snappy", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "snappyOut", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, bezier = "snappy" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "snappy" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2.5, bezier = "snappy", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "snappyOut", style = "slide" })
hl.animation({ leaf = "fade", enabled = true, speed = 2.5, bezier = "snappy" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 2.5, bezier = "snappy" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 2.5, bezier = "snappy" })
hl.animation({ leaf = "border", enabled = true, speed = 2.5, bezier = "snappy" })

-- Écrans : définis par machine dans hypr-monitors.lua (généré par home/home.nix / home/work.nix)
-- Workspaces 1-5 sur l'écran principal, 6-9 sur le secondaire (ignoré s'il n'y a qu'un écran)
local m = require("hypr-monitors")
for i = 1, 5 do
    hl.workspace_rule({ workspace = tostring(i), monitor = m.primary, default = (i == 1), persistent = true })
end
for i = 6, 9 do
    hl.workspace_rule({ workspace = tostring(i), monitor = m.secondary, default = (i == 6), persistent = true })
end

-- Blur propre : pas de grain (noise), plus de passes pour éviter les artefacts pixelisés
hl.config({
    decoration = {
        blur = {
            noise = 0,
            passes = 3,
            size = 6,
            contrast = 1.0,
            brightness = 1.0,
        },
    },
})

-- Clavier qwerty-fr (symboles installés par home/hyprland.nix dans ~/.config/xkb)
hl.config({
    input = {
        kb_layout = "us_qwerty-fr",
        kb_variant = "qwerty-fr",
    },
})
