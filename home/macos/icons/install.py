#!/usr/bin/env python3
"""Install the pinned macOSicons artwork locally; no image binaries in Git."""
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import urllib.request


def largest_png(data):
    if data[:4] != b"icns" or struct.unpack(">I", data[4:8])[0] != len(data):
        raise ValueError("Invalid ICNS file")
    images = []
    jpeg2000 = []
    pos = 8
    while pos + 8 <= len(data):
        size = struct.unpack(">I", data[pos + 4:pos + 8])[0]
        if size < 8 or pos + size > len(data):
            raise ValueError("Invalid ICNS chunk")
        png = data[pos + 8:pos + size]
        if png.startswith(b"\x89PNG\r\n\x1a\n"):
            width, height = struct.unpack(">II", png[16:24])
            images.append((width * height, png))
        elif png.startswith(b"\x00\x00\x00\x0cjP  \r\n\x87\n"):
            pixels = {b"ic10": 1024, b"ic09": 512, b"ic14": 512,
                      b"ic08": 256, b"ic13": 256, b"ic07": 128}.get(data[pos:pos + 4], 0)
            jpeg2000.append((pixels * pixels, png))
        pos += size
    if jpeg2000 and (not images or max(jpeg2000)[0] > max(images)[0]):
        raw = max(jpeg2000, key=lambda image: image[0])[1]
        return subprocess.run(["magick", "jp2:-", "png:-"], input=raw,
                              stdout=subprocess.PIPE, check=True).stdout
    if not images:
        raise ValueError("No embedded PNG in ICNS")
    return max(images, key=lambda image: image[0])[1]


def fit_grid(png):
    """Ramène une icône pleine page (sans marge) sur la grille Apple :
    squircle de 824 px centré dans une toile de 1024 px."""
    box = subprocess.run(["magick", "png:-", "-alpha", "extract", "-threshold", "10%", "-format", "%@", "info:"],
                         input=png, stdout=subprocess.PIPE, check=True).stdout.decode()
    w, h = (int(v) for v in box.split("+")[0].split("x"))
    if min(w, h) < 930:
        return png
    return subprocess.run(["magick", "png:-", "-resize", "1024x1024", "-resize", "824x824",
                           "-background", "none", "-gravity", "center", "-extent", "1024x1024", "png:-"],
                          input=png, stdout=subprocess.PIPE, check=True).stdout


def main():
    manifest = json.loads(Path(__file__).with_name("macosicons.json").read_text())
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    dest = data_home / "macos-shell/icons"
    cache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "macosicons"
    cache.mkdir(parents=True, exist_ok=True)
    written = set()
    for icon in manifest:
        png_source = icon.get("format") == "png"
        source = cache / (icon["id"] + (".png" if png_source else ".icns"))
        raw = source.read_bytes() if source.exists() else urllib.request.urlopen(icon["url"], timeout=60).read()
        if hashlib.sha256(raw).hexdigest() != icon["sha256"]:
            raise ValueError("Checksum mismatch: " + icon["name"])
        source.write_bytes(raw)
        png = fit_grid(raw if png_source else largest_png(raw))
        folder = dest / icon["variant"]
        folder.mkdir(parents=True, exist_ok=True)
        for key in icon["keys"]:
            # Atomic replacement: the running Dock never sees a partial PNG.
            with tempfile.NamedTemporaryFile(dir=folder, delete=False) as tmp:
                tmp.write(png)
                temp = Path(tmp.name)
            temp.chmod(0o644)
            temp.replace(folder / (key + ".png"))
            written.add(folder / (key + ".png"))
        print(icon["variant"], icon["app"], flush=True)
    # dark/ et light/ ne contiennent que le manifeste : on retire les icônes
    # d'une sélection précédente (les surcharges à la racine restent intactes).
    for variant in ("dark", "light"):
        for old in (dest / variant).glob("*.png"):
            if old not in written:
                old.unlink()
                print("removed", variant, old.name, flush=True)
    (dest / "sources.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
