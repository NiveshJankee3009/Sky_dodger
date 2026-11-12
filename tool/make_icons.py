"""Generates Sky Dodger's app icons and store graphics ("Neon Orbit" design).

Needs: python3 + Pillow, and rsvg-convert (librsvg) on PATH.
    python3 tool/make_icons.py

Writes:
    assets/icon/source/*.svg          editable vector sources
    assets/icon/android/res/...       legacy + adaptive (+ monochrome) launcher icons
    assets/icon/ios/AppIcon.appiconset/...   iOS icons (no alpha)
    assets/store/play_icon_512.png, assets/store/feature_graphic_1024x500.png
tool/ci/prepare_platform.sh copies the platform icons into android/ and ios/.
"""
import io
import json
import math
import random
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets"
SRC = OUT / "icon" / "source"

CYAN, VIOLET, PINK = "#4FC3F7", "#B388FF", "#FF80AB"


# ------------------------------------------------------------------ pieces
def ship(uid):
    """Ship in a 100x112 box, nose at (50,0)."""
    return (
        f'<defs><linearGradient id="fl{uid}" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="#FFB74D"/><stop offset="1" stop-color="#FF5252" stop-opacity="0"/>'
        f'</linearGradient></defs>'
        f'<path d="M36,86 L50,112 L64,86 Z" fill="url(#fl{uid})"/>'
        f'<path d="M43,86 L50,102 L57,86 Z" fill="#FFF59D"/>'
        f'<path d="M50,35 L100,82 L62,78 L38,78 L0,82 Z" fill="{VIOLET}"/>'
        f'<path d="M50,0 Q72,45 64,88 L36,88 Q28,45 50,0 Z" fill="#FFFFFF"/>'
        f'<ellipse cx="50" cy="38" rx="6" ry="10" fill="{CYAN}"/>'
    )


def rock(cx, cy, r, seed):
    rnd = random.Random(seed)
    pts = " ".join(
        f"{cx + math.cos(i / 10 * 2 * math.pi) * r * (0.78 + rnd.random() * 0.22):.1f},"
        f"{cy + math.sin(i / 10 * 2 * math.pi) * r * (0.78 + rnd.random() * 0.22):.1f}"
        for i in range(10))
    return (f'<polygon points="{pts}" fill="#8D6E63" stroke="#5D4037" stroke-width="{r * .09:.1f}" stroke-linejoin="round"/>'
            f'<circle cx="{cx - r * .3:.1f}" cy="{cy - r * .2:.1f}" r="{r * .17:.1f}" fill="#5D4037" opacity=".6"/>')


def coin(cx, cy, r):
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#FFC107"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r * .66:.1f}" fill="#FFE082"/>'
            f'<circle cx="{cx - r * .3:.1f}" cy="{cy - r * .35:.1f}" r="{r * .18:.1f}" fill="#fff"/>')


def stars(n, seed, w, h, maxr=3.5):
    rnd = random.Random(seed)
    return "".join(
        f'<circle cx="{rnd.uniform(0, w):.0f}" cy="{rnd.uniform(0, h):.0f}" r="{rnd.uniform(1, maxr):.1f}" '
        f'fill="#fff" opacity="{rnd.uniform(.35, 1):.2f}"/>' for _ in range(n))


BG_DEFS = ('<radialGradient id="bg" cx="0.5" cy="0.45" r="0.75">'
           '<stop offset="0" stop-color="#1C1650"/><stop offset="1" stop-color="#070A1C"/></radialGradient>')
RING_DEFS = (f'<linearGradient id="ring" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{CYAN}"/>'
             f'<stop offset=".5" stop-color="{VIOLET}"/><stop offset="1" stop-color="{PINK}"/></linearGradient>'
             '<filter id="glow" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="22"/></filter>')


def emblem(cx, cy, scale=1.0, mono=False):
    """Ring + ship + rock + coin, designed around a 1024 canvas centre."""
    if mono:
        return (f'<g transform="translate({cx} {cy}) scale({scale}) translate(-512 -512)">'
                '<circle cx="512" cy="512" r="335" fill="none" stroke="#fff" stroke-width="44"/>'
                '<g transform="translate(512 525) translate(-185 -215) scale(3.7)">'
                '<path d="M50,35 L100,82 L62,78 L38,78 L0,82 Z" fill="#fff"/>'
                '<path d="M50,0 Q72,45 64,88 L36,88 Q28,45 50,0 Z" fill="#fff"/>'
                '<path d="M40,86 L50,104 L60,86 Z" fill="#fff"/></g></g>')
    return (f'<g transform="translate({cx} {cy}) scale({scale}) translate(-512 -512)">'
            '<circle cx="512" cy="512" r="335" fill="none" stroke="url(#ring)" stroke-width="64" filter="url(#glow)" opacity=".9"/>'
            '<circle cx="512" cy="512" r="335" fill="none" stroke="url(#ring)" stroke-width="40"/>'
            + rock(800, 285, 62, 9) + coin(240, 770, 44)
            + '<g transform="translate(512 525) translate(-185 -215) scale(3.7)">' + ship("e") + '</g></g>')


def svg(w, h, body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'<defs>{defs}</defs>{body}</svg>')


def full_icon():
    return svg(1024, 1024, f'<rect width="1024" height="1024" fill="url(#bg)"/>'
               + stars(55, 7, 1024, 1024) + emblem(512, 512), BG_DEFS + RING_DEFS)


def adaptive_background():
    return svg(1024, 1024, f'<rect width="1024" height="1024" fill="url(#bg)"/>'
               + stars(70, 8, 1024, 1024), BG_DEFS)


def adaptive_foreground():
    # Android masks the 108dp layer to ~72dp and guarantees a 66dp circle:
    # keep the emblem inside ~60% of the canvas.
    return svg(1024, 1024, emblem(512, 512, scale=0.62), RING_DEFS)


def adaptive_monochrome():
    return svg(1024, 1024, emblem(512, 512, scale=0.62, mono=True))


def feature_graphic():
    w, h = 1024, 500
    defs = (BG_DEFS + RING_DEFS +
            f'<linearGradient id="title" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="{CYAN}"/>'
            f'<stop offset=".55" stop-color="{VIOLET}"/><stop offset="1" stop-color="{PINK}"/></linearGradient>'
            '<radialGradient id="neb" cx=".75" cy=".3" r=".6"><stop offset="0" stop-color="#7E57C2" stop-opacity=".55"/>'
            '<stop offset="1" stop-color="#7E57C2" stop-opacity="0"/></radialGradient>')
    body = (f'<rect width="{w}" height="{h}" fill="#0B1026"/><rect width="{w}" height="{h}" fill="url(#neb)"/>'
            + stars(90, 31, w, h)
            + emblem(835, 245, scale=0.40)
            + rock(90, 420, 34, 41) + coin(600, 70, 18)
            + '<text x="70" y="210" font-family="Inter" font-weight="900" font-size="104" letter-spacing="6" fill="url(#title)">SKY</text>'
            + '<text x="70" y="315" font-family="Inter" font-weight="900" font-size="104" letter-spacing="6" fill="url(#title)">DODGER</text>'
            + '<text x="74" y="372" font-family="Inter" font-weight="600" font-size="28" letter-spacing="3" fill="#ffffff" opacity=".75">DODGE • COLLECT • COMPETE</text>')
    return svg(w, h, body, defs)


# ------------------------------------------------------------------ render
def render(svg_text, w, h):
    png = subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h)],
                         input=svg_text.encode(), capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA")


def save(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def rounded(img, radius_frac=0.22):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.size[0] - 1, img.size[1] - 1),
                                           radius=int(img.size[0] * radius_frac), fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def main():
    sources = {
        "icon_full": full_icon(), "adaptive_background": adaptive_background(),
        "adaptive_foreground": adaptive_foreground(), "adaptive_monochrome": adaptive_monochrome(),
        "feature_graphic": feature_graphic(),
    }
    for name, text in sources.items():
        SRC.mkdir(parents=True, exist_ok=True)
        (SRC / f"{name}.svg").write_text(text)

    big = render(sources["icon_full"], 1024, 1024)

    # ---- Android
    res = OUT / "icon" / "android" / "res"
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for dens, px in legacy.items():
        save(rounded(big.resize((px, px), Image.LANCZOS)), res / f"mipmap-{dens}" / "ic_launcher.png")
        layer = round(px * 108 / 48)
        for name in ("background", "foreground", "monochrome"):
            img = render(sources[f"adaptive_{name}"], layer, layer)
            save(img, res / f"mipmap-{dens}" / f"ic_launcher_{name}.png")
    xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
           '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
           '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
           '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
           '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
           '</adaptive-icon>\n')
    (res / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
    (res / "mipmap-anydpi-v26" / "ic_launcher.xml").write_text(xml)

    # ---- iOS (square, no transparency; iOS rounds the corners itself)
    ios = OUT / "icon" / "ios" / "AppIcon.appiconset"
    images = []
    specs = [("20x20", "2x", "iphone"), ("20x20", "3x", "iphone"), ("29x29", "1x", "iphone"),
             ("29x29", "2x", "iphone"), ("29x29", "3x", "iphone"), ("40x40", "2x", "iphone"),
             ("40x40", "3x", "iphone"), ("60x60", "2x", "iphone"), ("60x60", "3x", "iphone"),
             ("20x20", "1x", "ipad"), ("20x20", "2x", "ipad"), ("29x29", "1x", "ipad"),
             ("29x29", "2x", "ipad"), ("40x40", "1x", "ipad"), ("40x40", "2x", "ipad"),
             ("76x76", "1x", "ipad"), ("76x76", "2x", "ipad"), ("83.5x83.5", "2x", "ipad"),
             ("1024x1024", "1x", "ios-marketing")]
    opaque = Image.new("RGB", big.size, "#070A1C")
    opaque.paste(big, (0, 0), big)
    for size, scale, idiom in specs:
        fname = f"Icon-App-{size}@{scale}.png"
        px = round(float(size.split("x")[0]) * int(scale[0]))
        save(opaque.resize((px, px), Image.LANCZOS), ios / fname)
        images.append({"size": size, "idiom": idiom, "filename": fname, "scale": scale})
    (ios / "Contents.json").write_text(json.dumps(
        {"images": images, "info": {"version": 1, "author": "xcode"}}, indent=2))

    # ---- Store graphics
    store = OUT / "store"
    save(big.resize((512, 512), Image.LANCZOS), store / "play_icon_512.png")
    fg = render(sources["feature_graphic"], 1024, 500)
    fgo = Image.new("RGB", fg.size, "#0B1026")
    fgo.paste(fg, (0, 0), fg)
    save(fgo, store / "feature_graphic_1024x500.png")
    save(big, OUT / "icon" / "icon_1024.png")
    print("Icons written to", OUT)


if __name__ == "__main__":
    main()
