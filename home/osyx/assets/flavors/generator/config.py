from __future__ import annotations

from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1]
ROOT_DIR = SCRIPT_DIR.parent
FLAVORS_DIR = ROOT_DIR / "flavors"
TEMPLATES_DIR = FLAVORS_DIR / "templates"
PALETTES_DIR = FLAVORS_DIR / "palettes"
THEME_NAMES_FILE = FLAVORS_DIR / "theme-names.toml"

OUTPUTS = {
    "mako.conf.j2": ".config/mako/config",
    "starship.toml.j2": ".config/starship.toml",
    "dircolors.j2": ".dircolors",
    "mango-colors.conf.j2": ".config/mango/colors.conf",
    "kitty.conf.j2": ".config/kitty/osyx.conf",
    "gtk.css.j2": ".config/gtk-3.0/gtk.css",
    "gtk.css.j2#4": ".config/gtk-4.0/gtk.css",
    "qt6ct-colors.conf.j2": ".config/qt6ct/colors/osyx.conf",
    "zed-theme.json.j2": ".config/zed/themes/osyx.json",
    "nvim-theme.lua.j2": ".config/nvim/osyx-theme.lua",
    "swaylock.conf.j2": ".config/swaylock/config",
    "tmux-theme.conf.j2": ".config/tmux/osyx-theme.conf",
    "powyx.toml.j2": ".config/powyx/powyx.toml",
    "lookas.toml.j2": ".config/lookas.toml",
    "hyprlock-colors.conf.j2": ".config/hypr/hyprlock-colors.conf",
    "vicinae.toml.j2": ".config/vicinae-theme.toml",
    "gitconfig.j2": ".gitconfig.d/theme",
}
