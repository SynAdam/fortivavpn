#!/usr/bin/env python3
"""Draw the home screen's power button from the app icon.

The power button is the icon's shield, and the helmet's eyes light up with
the connection (lib/widgets/power_button.dart). This cuts the shield out
of assets/icon/fortiva_icon.png, without its white plate, and draws the
light the button lays over it. A new icon means running this again rather
than drawing the light by hand:

    python3 tool/hero_art.py

Needs Pillow and NumPy. Writes four files to assets/hero/. They share one
canvas, the shield with room around it for its halo, so the button draws
each of them into the same box:

- shield.webp: the shield without the plate. WebP at quality 92 is a ninth
  of the PNG's size and looks the same at the size it is drawn.
- eyes.png: the two eyes, white, in the slits of the helmet's visor.
- glow.png: the eyes' light, white: inside the visor, then softly over
  the steel around it.
- halo.png: the light around the shield's edge, white.

The button tints the white files with the colour of its state, so one set
of files serves every state.

The places below (the visor and the eyes) are in the icon's own pixels.
They fit this icon; a new icon needs them checked. The button reads the
canvas size and the eyes' places from _Art in power_button.dart, so change
both together. A test checks the files against _Art.
"""

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ICON = ROOT / "assets/icon/fortiva_icon.png"
OUT = ROOT / "assets/hero"

# The canvas: the shield's box in the icon, and room around it for the
# halo. Icon pixels.
SHIELD = (166, 67, 858, 975)  # left, top, right, bottom
PAD = 110

# The files' sizes, as shares of the icon's pixels. The shield and the eyes
# are crisp and are drawn up to about 700 pixels high on a phone; the glow
# and the halo are soft and need far fewer.
SHARP = 0.8
SOFT = 0.4
HALO = 0.2

# A point inside the visor's slot, below the eyes.
VISOR_SEED = (512, 650)

# The eyes: an almond in each slit of the visor, the left one centred here,
# the right one its mirror image about the icon's middle. The slits slope
# down toward the nose guard, and the eyes follow them.
EYE_CENTRE = (418.0, 528.0)
EYE_LENGTH = 100.0
EYE_HEIGHT = 30.0
EYE_TILT = 15.0  # degrees, the inner end lower
MIDDLE = 511.5


def load() -> np.ndarray:
    return np.asarray(Image.open(ICON).convert("RGB")).astype(np.float32) / 255


def cut_plate(icon: np.ndarray) -> np.ndarray:
    """The icon as RGBA, with the white plate around the shield clear.

    The plate is the light area that reaches the icon's edge. The pixels on
    its border, where the plate meets the shield's black outline, keep a
    share of opacity from how dark they are, and take the outline's colour,
    so the edge stays smooth and no white fringe shows on a dark screen.
    """
    h, w, _ = icon.shape
    lightest = icon.min(axis=2)
    # A copy: Pillow does not fill an image that still shares the array's
    # memory, and says nothing.
    light = Image.fromarray(np.where(lightest > 0.5, 255, 0).astype(np.uint8)).copy()
    for corner in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if light.getpixel(corner) == 255:
            ImageDraw.floodfill(light, corner, 128)
    plate = np.asarray(light) == 128

    outline = np.array([0.08, 0.09, 0.10], np.float32)
    alpha = np.ones((h, w), np.float32)
    alpha[plate] = np.clip((1 - lightest[plate]) / (1 - outline.min()), 0, 1)
    rgb = icon.copy()
    rgb[plate] = outline
    return np.dstack([rgb, alpha])


def visor(icon: np.ndarray) -> np.ndarray:
    """The helmet's T-shaped visor opening, as a 0 to 1 mask.

    The visor is black, and so are the drawing's outlines, which touch it.
    Shrinking the black first cuts those thin lines off, so the fill from
    the slot keeps to the visor, and growing it back restores its size.
    """
    dark = np.where(icon.max(axis=2) < 70 / 255, 255, 0).astype(np.uint8)
    shrunk = Image.fromarray(dark).filter(ImageFilter.MinFilter(19))
    ImageDraw.floodfill(shrunk, VISOR_SEED, 128)
    core = np.where(np.asarray(shrunk) == 128, 255, 0).astype(np.uint8)
    grown = np.asarray(Image.fromarray(core).filter(ImageFilter.MaxFilter(19)))
    return ((grown > 0) & (dark > 0)).astype(np.float32)


def almond(cx: float, cy: float, tilt: float, n: int = 48) -> list:
    """One eye: an almond along the slit, flatter on top, which reads as a
    steady look rather than a wide one."""
    pts = []
    for i in range(n + 1):
        u = i / n
        pts.append(((u - 0.5) * EYE_LENGTH, -EYE_HEIGHT / 2 * math.sin(math.pi * u) ** 0.7 * 0.8))
    for i in range(n, -1, -1):
        u = i / n
        pts.append(((u - 0.5) * EYE_LENGTH, EYE_HEIGHT / 2 * math.sin(math.pi * u) ** 0.7))
    a = math.radians(tilt)
    return [
        (cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a))
        for x, y in pts
    ]


def eyes(w: int, h: int) -> np.ndarray:
    """Both eyes, as a 0 to 1 mask, drawn four times over for clean edges."""
    over = 4
    big = Image.new("L", (w * over, h * over), 0)
    draw = ImageDraw.Draw(big)
    cx, cy = EYE_CENTRE
    left = almond(cx, cy, EYE_TILT)
    right = [(2 * MIDDLE - x, y) for x, y in left]
    for eye in (left, right):
        draw.polygon([(x * over, y * over) for x, y in eye], fill=255)
    return np.asarray(big.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255


def blur(mask: np.ndarray, radius: float) -> np.ndarray:
    img = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(radius))).astype(np.float32) / 255


def glow(eye: np.ndarray, opening: np.ndarray) -> np.ndarray:
    """The eyes' light: a tight glow round each eye, kept mostly inside the
    visor, two wider ones that spill onto the steel round it, and the
    inside of the visor lit, most at the eyes and less down the slot.

    The parts add up like light and pass 1 near the eyes, so they are
    eased into 0 to 1 rather than cut off: the brightest part keeps its
    shape.
    """
    h, _ = opening.shape
    rows = np.arange(h, dtype=np.float32)[:, None]
    down_the_slot = np.clip(1 - (rows - 560) / 300, 0.15, 1)
    light = (
        0.38 * blur(opening, 2) * down_the_slot
        + 0.85 * blur(eye, 36)
        + 0.35 * blur(eye, 80)
        + 1.10 * blur(eye, 12) * np.maximum(opening, 0.4)
        + 1.00 * blur(eye, 4)
    )
    return 1 - np.exp(-1.8 * light)


def halo(alpha: np.ndarray) -> np.ndarray:
    """The light around the shield: its outline, blurred. The button draws
    it behind the shield, so only the part outside the shield shows."""
    return np.clip(blur(alpha, 36) * 1.15, 0, 1)


def on_canvas(layer: np.ndarray) -> np.ndarray:
    """[layer] (icon pixels) cut to the canvas: the shield's box and PAD."""
    left, top, right, bottom = SHIELD
    pad = [(PAD, PAD), (PAD, PAD)] + [(0, 0)] * (layer.ndim - 2)
    padded = np.pad(layer, pad)
    return padded[top : bottom + 2 * PAD, left : right + 2 * PAD]


def save_white(mask: np.ndarray, scale: float, name: str) -> None:
    """[mask] as the opacity of white: the button tints it."""
    h, w = mask.shape
    a = Image.fromarray((np.clip(mask, 0, 1) * 255).round().astype(np.uint8))
    a = a.resize((round(w * scale), round(h * scale)), Image.LANCZOS)
    white = Image.new("L", a.size, 255)
    Image.merge("LA", (white, a)).save(OUT / name, optimize=True)


def save_shield(rgba: np.ndarray, scale: float, name: str) -> None:
    h, w, _ = rgba.shape
    # Premultiplied while scaling, so the clear plate does not bleed its
    # colour into the edge.
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255).round().astype(np.uint8), "RGBA")
    img = img.convert("RGBa").resize((round(w * scale), round(h * scale)), Image.LANCZOS)
    img.convert("RGBA").save(OUT / name, "WEBP", quality=92, method=6, alpha_quality=100)


def main() -> None:
    icon = load()
    shield = cut_plate(icon)
    h, w, _ = icon.shape
    eye = eyes(w, h)
    opening = visor(icon)

    OUT.mkdir(parents=True, exist_ok=True)
    save_shield(on_canvas(shield), SHARP, "shield.webp")
    save_white(on_canvas(eye), SHARP, "eyes.png")
    save_white(on_canvas(glow(eye, opening)), SOFT, "glow.png")
    save_white(on_canvas(halo(shield[..., 3])), HALO, "halo.png")

    left, top, right, bottom = SHIELD
    # What _Art in power_button.dart holds, on the canvas.
    cw, ch = right - left + 2 * PAD, bottom - top + 2 * PAD
    dx, dy = PAD - left, PAD - top
    cx, cy = EYE_CENTRE[0] + dx, EYE_CENTRE[1] + dy
    a = math.radians(EYE_TILT)
    ox, oy = cx - EYE_LENGTH / 2 * math.cos(a), cy - EYE_LENGTH / 2 * math.sin(a)
    print(f"canvas {cw}x{ch}, the shield {bottom - top} high")
    print(f"left eye: centre ({cx:.1f}, {cy:.1f}), outer end ({ox:.1f}, {oy:.1f}); middle at x {MIDDLE + dx:.1f}")
    for f in sorted(OUT.iterdir()):
        with Image.open(f) as img:
            print(f"wrote {f.relative_to(ROOT)} {img.size[0]}x{img.size[1]} {f.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
