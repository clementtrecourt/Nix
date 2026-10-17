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

-- Écrans : définis par machine dans ~/.config/caelestia/hypr-monitors.lua (fichier local, hors git)
-- Workspaces 1-5 sur l'écran principal, 6-9 sur le secondaire (ignoré s'il n'y a qu'un écran)
local ok, m = pcall(require, "hypr-monitors")
if ok and type(m) == "table" then
    for i = 1, 5 do
        hl.workspace_rule({ workspace = tostring(i), monitor = m.primary, default = (i == 1), persistent = true })
    end
    for i = 6, 9 do
        hl.workspace_rule({ workspace = tostring(i), monitor = m.secondary, default = (i == 6), persistent = true })
    end
else
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
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

-- Hyprshade : applique le shader prévu par ~/.config/hyprshade/config.toml (planning) au démarrage
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprshade auto")
end)
-- Toggle manuel du filtre lumière bleue
hl.bind("SUPER + SHIFT + B", function() hl.exec_cmd("hyprshade toggle blue-light-filter") end)

-- Capture d'écran : sélection d'une région (script home/screenshot.nix), copiée dans le presse-papiers
hl.bind("SUPER + P", function() hl.exec_cmd("screenshot region") end)

-- Sélecteur de wallpaper Caelestia : ouvre le launcher (IPC) puis préremplit ">wallpaper "
hl.bind("SUPER + SHIFT + W", function()
    hl.exec_cmd("sh -c 'caelestia shell drawers toggle launcher; sleep 0.25; wtype \">wallpaper \"'")
end)

-- Super + Shift + 1..9/0 : envoie la fenêtre active vers le workspace N (0 = 10)
for i = 1, 10 do
    hl.bind("SUPER + SHIFT + " .. (i % 10), function()
        hl.dispatch(hl.dsp.window.move({ workspace = i }))
    end)
end

-- Extinction immédiate sur Super + Échap
hl.bind("SUPER + Escape", function() hl.exec_cmd("systemctl poweroff") end)
