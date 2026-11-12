"""Draws the extension's toolbar icons from the app icon.

    python3 browser/tool/icons.py

Writes browser/icons/on-<size>.png and off-<size>.png for 16, 32, 48 and
128 pixels. The white around the shield becomes transparent, so the icon
sits on a dark toolbar as well as a light one. "off" is the same shield in
grey, shown while the extension is not connected. Run it again when the app
icon changes.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "icon" / "fortiva_icon.png"
OUT = ROOT / "browser" / "icons"
SIZES = (16, 32, 48, 128)


def without_background(im: Image.Image) -> Image.Image:
    """The icon with the white that touches its edges made transparent."""
    im = im.convert("RGBA")
    # A marker colour the icon does not use, flooded from each corner.
    marker = (255, 0, 255, 255)
    w, h = im.size
    for corner in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        ImageDraw.floodfill(im, corner, marker, thresh=40)
    data = [(0, 0, 0, 0) if px == marker else px for px in im.getdata()]
    im.putdata(data)
    return im.crop(im.getbbox())


def square(im: Image.Image) -> Image.Image:
    side = max(im.size)
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    return out


def grey(im: Image.Image) -> Image.Image:
    alpha = im.getchannel("A")
    g = ImageOps.grayscale(im).convert("RGBA")
    g.putalpha(alpha.point(lambda a: a * 0.75))
    return g


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    on = square(without_background(Image.open(SOURCE)))
    off = grey(on)
    for size in SIZES:
        on.resize((size, size), Image.LANCZOS).save(OUT / f"on-{size}.png", optimize=True)
        off.resize((size, size), Image.LANCZOS).save(OUT / f"off-{size}.png", optimize=True)


if __name__ == "__main__":
    main()
