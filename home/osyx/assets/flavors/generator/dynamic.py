"""Palette dynamique : construit une palette osyx à partir de la sortie JSON de matugen.

Les couleurs viennent des rôles Material (mode sombre). La palette `base16` de matugen n'est
volontairement pas utilisée : avec le backend wal elle donne des gris presque identiques.
Le rôle tertiary est décalé de 60° de teinte (vert pour une source orange) : il ne sert qu'au vert ANSI.
"""
from __future__ import annotations

import colorsys
import os
from pathlib import Path
from typing import Any

from .config import PALETTES_DIR

DYNAMIC_NAME = "dynamic"


def _tint_factor() -> float:
    # 0 = surfaces grises, 1 = teinte Material brute (brune pour une source orange). Défaut 0.25.
    try:
        return min(max(float(os.environ.get("OSYX_TINT", "0.25")), 0.0), 1.0)
    except ValueError:
        return 0.25


def _desaturate(hex_color: str, factor: float) -> str:
    r, g, b = (int(hex_color[i : i + 2], 16) / 255 for i in (0, 2, 4))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    r, g, b = colorsys.hls_to_rgb(h, l, s * factor)
    return "%02x%02x%02x" % tuple(round(x * 255) for x in (r, g, b))


def _hex(colors: dict[str, Any], role: str) -> str:
    return colors[role]["dark"]["color"].lstrip("#").lower()


def palette_from_matugen(data: dict[str, Any]) -> dict[str, dict[str, str]]:
    colors = data["colors"]

    tint = _tint_factor()

    def c(role: str) -> str:
        return _hex(colors, role)

    def neutral(role: str, strength: float = 1.0) -> str:
        # surfaces et textes : on garde la luminosité Material mais on retire la teinte du wallpaper
        return _desaturate(c(role), tint * strength)

    ansi = [
        "surface", "error", "tertiary", "secondary",
        "primary", "primary_fixed_dim", "secondary_fixed", "on_surface_variant",
        "outline", "error", "tertiary_fixed", "secondary_fixed",
        "primary_fixed", "inverse_primary", "secondary_fixed_dim", "on_surface",
    ]

    kitty = {
        "bg": neutral("surface"),
        "fg": neutral("on_surface", 2.0),
        "cursor": c("primary"),
        "selection_bg": c("primary"),
        "selection_fg": c("on_primary"),
    }
    for index, role in enumerate(ansi):
        kitty[f"color{index}"] = c(role)
    kitty["color0"] = neutral("surface")

    return {
        "starship": {
            "os_bg": c("primary"),
            "os_fg": c("on_primary"),
            "dir_bg": neutral("secondary_container", 2.0),
            "dir_fg": c("on_secondary_container"),
            "git_branch_bg": neutral("primary_container", 2.0),
            "git_branch_fg": c("on_primary_container"),
            "git_status_bg": neutral("primary_container", 2.0),
            "git_status_fg": c("primary"),
            "langs_bg": neutral("surface_container_high"),
            "langs_fg": neutral("on_surface", 2.0),
            "time_bg": neutral("surface_container"),
            "time_fg": c("primary"),
            "success": c("primary"),
            "error": c("error"),
        },
        "tmux": {
            "pane_border": neutral("outline", 2.0),
            "pane_active_border": c("primary"),
            "message_bg": c("primary"),
            "message_fg": c("on_primary"),
            "git_bg": neutral("primary_container", 2.0),
            "git_fg": c("on_primary_container"),
            "host_bg": neutral("surface_container_high"),
            "host_fg": neutral("on_surface", 2.0),
            "time_bg": neutral("surface_container"),
            "time_fg": neutral("on_surface", 2.0),
        },
        "hyprland": {
            "active_border": c("primary"),
            "inactive_border": neutral("outline", 2.0),
        },
        "mako": {
            "bg": neutral("surface"),
            "text": neutral("on_surface", 2.0),
            "border": neutral("outline", 2.0),
            "progress": c("primary"),
        },
        "kitty": kitty,
        "wofi": {
            "bg": neutral("surface"),
            "border": c("primary"),
            "input_bg": neutral("surface_container_high"),
            "input_border": neutral("outline", 2.0),
            "text": neutral("on_surface", 2.0),
            "selected_bg": c("primary"),
            "selected_text": c("on_primary"),
        },
        "ui": {
            "surface": neutral("surface"),
            "raised": neutral("surface_container_high"),
            "hover": neutral("surface_container_highest", 2.0),
            "border": neutral("outline_variant", 2.0),
            "muted": neutral("outline", 2.0),
        },
        "theme_names": {"nvim": "kanagawa-dragon"},
        "dircolors": {
            "dir": c("primary"),
            "link": c("primary_fixed_dim"),
            "archive": c("secondary"),
            "media": c("secondary_fixed"),
            "source": c("on_surface"),
            "exec": c("secondary"),
            "ignored": neutral("outline", 2.0),
            "bg": neutral("surface"),
            "fg": neutral("on_surface", 2.0),
            "orphan": c("error"),
        },
    }


def write_palette(palette: dict[str, dict[str, str]]) -> Path:
    lines: list[str] = []
    for section, values in palette.items():
        lines.append(f"[{section}]")
        for key, value in values.items():
            lines.append(f'{key} = "{value}"')
        lines.append("")

    path = PALETTES_DIR / f"{DYNAMIC_NAME}.toml"
    path.write_text("\n".join(lines), encoding="utf-8")
    return path
