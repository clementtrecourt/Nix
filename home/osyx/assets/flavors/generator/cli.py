from __future__ import annotations

def main(args: list[str]) -> int:
    if not args:
        print("Usage: python3 generate.py <theme_name> [theme_name ...]")
        print("Example: python3 generate.py malachite")
        return 1

    if args[0] == "--from-matugen":
        if len(args) != 2:
            print("Usage: python3 generate.py --from-matugen <matugen.json>")
            return 1

        import json
        from pathlib import Path

        from .dynamic import DYNAMIC_NAME, palette_from_matugen, write_palette

        try:
            data = json.loads(Path(args[1]).read_text(encoding="utf-8"))
            write_palette(palette_from_matugen(data))
        except (OSError, ValueError, KeyError) as error:
            print(f"Error: invalid matugen output: {error}")
            return 1

        args = [DYNAMIC_NAME]

    try:
        from .render import ThemeError, generate_theme
    except RuntimeError as error:
        print(f"Error: {error}")
        return 1

    for theme in args:
        try:
            generate_theme(theme)
        except ThemeError as error:
            print(f"Error: {error}")
            return 1

    return 0
