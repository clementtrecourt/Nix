"""Palette dynamique : construit une palette osyx à partir de la sortie JSON de matugen.

Les couleurs viennent des rôles Material (mode sombre). La palette `base16` de matugen n'est
volontairement pas utilisée : avec le backend wal elle donne des gris presque identiques.
Le rôle tertiary est décalé de 60° de teinte (vert pour une source orange) : il ne sert qu'au vert ANSI.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any

from .config import PALETTES_DIR

DYNAMIC_NAME = "dynamic"


def _hex(colors: dict[str, Any], role: str) -> str:
    return colors[role]["dark"]["color"].lstrip("#").lower()


def palette_from_matugen(data: dict[str, Any]) -> dict[str, dict[str, str]]:
    colors = data["colors"]

    def c(role: str) -> str:
        return _hex(colors, role)

    ansi = [
        "surface", "error", "tertiary", "secondary",
        "primary", "primary_fixed_dim", "secondary_fixed", "on_surface_variant",
        "outline", "error", "tertiary_fixed", "secondary_fixed",
        "primary_fixed", "inverse_primary", "secondary_fixed_dim", "on_surface",
    ]

    kitty = {
        "bg": c("surface"),
        "fg": c("on_surface"),
        "cursor": c("primary"),
        "selection_bg": c("primary"),
        "selection_fg": c("on_primary"),
    }
    for index, role in enumerate(ansi):
        kitty[f"color{index}"] = c(role)

    return {
        "starship": {
            "os_bg": c("primary"),
            "os_fg": c("on_primary"),
            "dir_bg": c("secondary_container"),
            "dir_fg": c("on_secondary_container"),
            "git_branch_bg": c("primary_container"),
            "git_branch_fg": c("on_primary_container"),
            "git_status_bg": c("primary_container"),
            "git_status_fg": c("primary"),
            "langs_bg": c("surface_container_high"),
            "langs_fg": c("on_surface"),
            "time_bg": c("surface_container"),
            "time_fg": c("primary"),
            "success": c("primary"),
            "error": c("error"),
        },
        "tmux": {
            "pane_border": c("outline"),
            "pane_active_border": c("primary"),
            "message_bg": c("primary"),
            "message_fg": c("on_primary"),
            "git_bg": c("primary_container"),
            "git_fg": c("on_primary_container"),
            "host_bg": c("surface_container_high"),
            "host_fg": c("on_surface"),
            "time_bg": c("surface_container"),
            "time_fg": c("on_surface"),
        },
        "hyprland": {
            "active_border": c("primary"),
            "inactive_border": c("outline"),
        },
        "mako": {
            "bg": c("surface"),
            "text": c("on_surface"),
            "border": c("outline"),
            "progress": c("primary"),
        },
        "kitty": kitty,
        "wofi": {
            "bg": c("surface"),
            "border": c("primary"),
            "input_bg": c("surface_container_high"),
            "input_border": c("outline"),
            "text": c("on_surface"),
            "selected_bg": c("primary"),
            "selected_text": c("on_primary"),
        },
        "theme_names": {"nvim": "kanagawa-dragon"},
        "dircolors": {
            "dir": c("primary"),
            "link": c("primary_fixed_dim"),
            "archive": c("secondary"),
            "media": c("secondary_fixed"),
            "source": c("on_surface"),
            "exec": c("secondary"),
            "ignored": c("outline"),
            "bg": c("surface"),
            "fg": c("on_surface"),
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
