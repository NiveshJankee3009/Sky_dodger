"""Generates Sky Dodger's in-game sprites into assets/images/.

Needs: python3 + numpy + Pillow, and rsvg-convert on PATH.
    python3 tool/make_sprites.py

Everything is original artwork described in SVG (ship, asteroids, coin,
planets) or generated procedurally (nebula clouds).
"""
import io
import math
import random
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "images"
OUT.mkdir(parents=True, exist_ok=True)


def render(svg, w, h):
    png = subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h)],
                         input=svg.encode(), capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA")


def save(img, name):
    img.save(OUT / name, optimize=True)
    print("wrote", name, img.size)


# ------------------------------------------------------------------ ship
def ship():
    # 100 x 122 design box; nose at top. Engine flame is drawn in-game.
    svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 122">
<defs>
  <linearGradient id="hull" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#B3E5FC"/><stop offset=".45" stop-color="#FFFFFF"/>
    <stop offset=".7" stop-color="#E1F5FE"/><stop offset="1" stop-color="#81D4FA"/></linearGradient>
  <linearGradient id="wing" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#D1C4E9"/><stop offset=".5" stop-color="#9575CD"/>
    <stop offset="1" stop-color="#5E35B1"/></linearGradient>
  <linearGradient id="glass" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#E0F7FA"/><stop offset=".4" stop-color="#4FC3F7"/>
    <stop offset="1" stop-color="#01579B"/></linearGradient>
  <linearGradient id="pod" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#90A4AE"/><stop offset="1" stop-color="#455A64"/></linearGradient>
</defs>
<!-- wings -->
<path d="M50,40 L98,88 Q99,94 93,94 L64,88 L36,88 L7,94 Q1,94 2,88 Z" fill="url(#wing)" stroke="#311B92" stroke-width="1.2"/>
<path d="M50,48 L88,86 M50,48 L12,86" stroke="#EDE7F6" stroke-opacity=".55" stroke-width="1.4"/>
<!-- wing tips -->
<rect x="4" y="80" width="5" height="12" rx="2" fill="#FF80AB"/>
<rect x="91" y="80" width="5" height="12" rx="2" fill="#FF80AB"/>
<!-- side engine pods -->
<rect x="27" y="74" width="9" height="26" rx="4" fill="url(#pod)"/>
<rect x="64" y="74" width="9" height="26" rx="4" fill="url(#pod)"/>
<!-- hull -->
<path d="M50,2 Q74,46 65,100 L35,100 Q26,46 50,2 Z" fill="url(#hull)" stroke="#0277BD" stroke-width="1.2"/>
<path d="M50,8 Q55,40 54,96" stroke="#FFFFFF" stroke-opacity=".9" stroke-width="2" fill="none"/>
<!-- accent stripes -->
<path d="M38,70 L62,70 L61,76 L39,76 Z" fill="#4FC3F7"/>
<path d="M40,82 L60,82 L59.5,86 L40.5,86 Z" fill="#B388FF"/>
<!-- cockpit -->
<ellipse cx="50" cy="40" rx="8" ry="14" fill="url(#glass)" stroke="#01579B" stroke-width="1"/>
<ellipse cx="47" cy="34" rx="2.5" ry="5" fill="#FFFFFF" opacity=".85"/>
<!-- nozzle -->
<rect x="40" y="98" width="20" height="7" rx="2" fill="#37474F"/>
</svg>"""
    save(render(svg, 200, 244), "ship.png")


# ------------------------------------------------------------------ rocks
def rock(seed, name, base, dark, light):
    rnd = random.Random(seed)
    n = 13
    pts = []
    for i in range(n):
        a = i / n * 2 * math.pi
        r = 44 * (0.80 + rnd.random() * 0.20)
        pts.append((50 + math.cos(a) * r, 50 + math.sin(a) * r))
    poly = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    craters = ""
    for _ in range(5):
        cx, cy = 50 + rnd.uniform(-24, 24), 50 + rnd.uniform(-24, 24)
        cr = rnd.uniform(4, 9)
        craters += (f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{cr:.1f}" fill="{dark}" opacity=".75"/>'
                    f'<circle cx="{cx - cr * .25:.1f}" cy="{cy - cr * .25:.1f}" r="{cr * .7:.1f}" fill="{base}" opacity=".6"/>'
                    f'<path d="M{cx - cr:.1f},{cy:.1f} A{cr:.1f},{cr:.1f} 0 0 0 {cx + cr:.1f},{cy:.1f}" '
                    f'stroke="{light}" stroke-opacity=".55" stroke-width="1.3" fill="none"/>')
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
<defs>
  <radialGradient id="shade" cx=".35" cy=".3" r=".8">
    <stop offset="0" stop-color="{light}"/><stop offset=".55" stop-color="{base}"/>
    <stop offset="1" stop-color="{dark}"/></radialGradient>
  <clipPath id="c"><polygon points="{poly}"/></clipPath>
</defs>
<polygon points="{poly}" fill="url(#shade)"/>
<g clip-path="url(#c)">{craters}
  <ellipse cx="66" cy="72" rx="40" ry="34" fill="#000" opacity=".22"/></g>
<polygon points="{poly}" fill="none" stroke="{dark}" stroke-width="2.4" stroke-linejoin="round"/>
</svg>"""
    save(render(svg, 192, 192), name)


# ------------------------------------------------------------------ coin
def coin():
    star = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 22 if i % 2 == 0 else 10
        star.append(f"{50 + math.cos(a) * r:.1f},{50 + math.sin(a) * r:.1f}")
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
<defs>
  <radialGradient id="g" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#FFF8E1"/>
    <stop offset=".45" stop-color="#FFD54F"/><stop offset="1" stop-color="#FF8F00"/></radialGradient>
  <linearGradient id="rim" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFE082"/>
    <stop offset="1" stop-color="#E65100"/></linearGradient>
</defs>
<circle cx="50" cy="50" r="46" fill="url(#rim)"/>
<circle cx="50" cy="50" r="38" fill="url(#g)"/>
<polygon points="{" ".join(star)}" fill="#FFF3C4" stroke="#FF8F00" stroke-width="2" stroke-linejoin="round"/>
<path d="M22,34 A32,32 0 0 1 46,16" stroke="#fff" stroke-width="5" stroke-linecap="round" fill="none" opacity=".8"/>
</svg>"""
    save(render(svg, 96, 96), "coin.png")


# ------------------------------------------------------------------ planets
def planet(name, c1, c2, c3, ring=None, bands=0, seed=0):
    rnd = random.Random(seed)
    band_svg = "".join(
        f'<ellipse cx="50" cy="{30 + i * 12 + rnd.uniform(-3, 3):.1f}" rx="40" ry="{rnd.uniform(2, 4):.1f}" '
        f'fill="{c3}" opacity=".35"/>' for i in range(bands))
    ring_back = ring_front = ""
    if ring:
        ring_back = (f'<ellipse cx="50" cy="50" rx="46" ry="11" fill="none" stroke="{ring}" '
                     f'stroke-width="5" opacity=".55" transform="rotate(-18 50 50)"/>')
        ring_front = (f'<path d="M4.3,50 A46,11 0 0 0 95.7,50" fill="none" stroke="{ring}" '
                      f'stroke-width="5" opacity=".85" transform="rotate(-18 50 50)"/>')
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
<defs>
  <radialGradient id="p" cx=".35" cy=".3" r=".75"><stop offset="0" stop-color="{c1}"/>
    <stop offset=".6" stop-color="{c2}"/><stop offset="1" stop-color="#05040F"/></radialGradient>
  <radialGradient id="atm" cx=".5" cy=".5" r=".5"><stop offset=".78" stop-color="{c1}" stop-opacity="0"/>
    <stop offset=".9" stop-color="{c1}" stop-opacity=".35"/><stop offset="1" stop-color="{c1}" stop-opacity="0"/></radialGradient>
  <clipPath id="cp"><circle cx="50" cy="50" r="30"/></clipPath>
</defs>
<circle cx="50" cy="50" r="38" fill="url(#atm)"/>
{ring_back}
<circle cx="50" cy="50" r="30" fill="url(#p)"/>
<g clip-path="url(#cp)">{band_svg}</g>
{ring_front}
</svg>"""
    save(render(svg, 384, 384), name)


# ------------------------------------------------------------------ nebulae
def nebula(name, colors, seed, size=512):
    rng = np.random.default_rng(seed)
    img = np.zeros((size, size, 4), np.float32)
    # fractal noise: sum of upscaled random grids
    noise = np.zeros((size, size), np.float32)
    for octave, weight in [(4, 1.0), (8, .5), (16, .25), (32, .12)]:
        grid = rng.random((octave, octave)).astype(np.float32)
        layer = np.array(Image.fromarray((grid * 255).astype(np.uint8)).resize(
            (size, size), Image.BICUBIC), np.float32) / 255
        noise += layer * weight
    noise /= noise.max()
    yy, xx = np.mgrid[0:size, 0:size] / size - 0.5
    falloff = np.clip(1 - np.sqrt(xx ** 2 + yy ** 2) * 2.1, 0, 1) ** 1.6
    density = np.clip((noise - 0.22) * 2.2, 0, 1) * falloff
    for i, (r, g, b) in enumerate(colors):
        w = np.clip(1 - abs(noise * len(colors) - i - 0.5), 0, 1)
        img[..., 0] += w * r
        img[..., 1] += w * g
        img[..., 2] += w * b
    img[..., :3] = np.clip(img[..., :3], 0, 255)
    img[..., 3] = density * 200
    out = Image.fromarray(img.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(6))
    save(out, name)


if __name__ == "__main__":
    ship()
    rock(3, "rock_0.png", "#8D6E63", "#3E2723", "#BCAAA4")
    rock(7, "rock_1.png", "#78909C", "#263238", "#CFD8DC")
    rock(11, "rock_2.png", "#A1887F", "#4E342E", "#D7CCC8")
    coin()
    planet("planet_0.png", "#B39DDB", "#5E35B1", "#EDE7F6", ring="#FFCC80", bands=4, seed=1)
    planet("planet_1.png", "#80DEEA", "#00838F", "#E0F7FA", bands=0, seed=2)
    planet("planet_2.png", "#FFAB91", "#BF360C", "#FFE0B2", bands=5, seed=3)
    nebula("nebula_0.png", [(126, 87, 194), (236, 64, 122), (79, 195, 247)], seed=5)
    nebula("nebula_1.png", [(38, 198, 218), (92, 107, 192), (171, 71, 188)], seed=9)
