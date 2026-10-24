#!/usr/bin/env python3
"""Draw the Android TV launcher banner from the app icon.

Android TV and Google TV show a 320x180 banner in place of the launcher
icon (android:banner in the manifest). This draws it from
assets/icon/fortiva_icon.png and the Inter font the app ships, so a new
icon means running this again rather than redrawing it by hand:

    python3 tool/tv_banner.py

Needs Pillow. Writes android/app/src/main/res/drawable-xhdpi/tv_banner.png.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ICON = ROOT / "assets/icon/fortiva_icon.png"
FONT = ROOT / "assets/fonts/Inter/Inter-Bold.ttf"
OUT = ROOT / "android/app/src/main/res/drawable-xhdpi/tv_banner.png"

W, H = 320, 180
SCALE = 4  # drawn at four times the size, then scaled down for clean edges

BACKGROUND = (0x0F, 0x14, 0x19, 255)  # AppDesign.backgroundMain
TEXT = (0xE6, 0xED, 0xF3, 255)  # AppDesign.textPrimary
TEAL = (0x14, 0xB8, 0xA6)  # AppDesign.accentTeal


def mark(height: int) -> Image.Image:
    """The icon without its white plate, cropped and scaled to [height]."""
    icon = Image.open(ICON).convert("RGBA")
    px = icon.load()
    for y in range(icon.height):
        for x in range(icon.width):
            r, g, b, a = px[x, y]
            lightest = min(r, g, b)
            if lightest > 235:
                # Fade the near-white plate out rather than cutting it, so
                # the edge of the shield is not jagged.
                px[x, y] = (r, g, b, a * (255 - lightest) // 20)
    icon = icon.crop(icon.getbbox())
    return icon.resize((icon.width * height // icon.height, height), Image.LANCZOS)


def font(size: int) -> ImageFont.FreeTypeFont:
    # The app ships static Inter files now, so the weight and optical size
    # are the file's: Bold (700) at the text size. The banner was first
    # drawn from the variable font at display size and 750 for "Fortiva",
    # so a new run draws the words a little differently.
    return ImageFont.truetype(str(FONT), size * SCALE)


def main() -> None:
    img = Image.new("RGBA", (W * SCALE, H * SCALE), BACKGROUND)

    cx, cy, r = 78 * SCALE, 90 * SCALE, 70 * SCALE
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((cx - r, cy - r, cx + r, cy + r), fill=TEAL + (70,))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(28 * SCALE)))

    shield = mark(128 * SCALE)
    img.alpha_composite(shield, (cx - shield.width // 2, cy - shield.height // 2))

    draw = ImageDraw.Draw(img)
    draw.text((150 * SCALE, 64 * SCALE), "Fortiva", font=font(40), fill=TEXT, anchor="ls")
    draw.text((152 * SCALE, 108 * SCALE), "VPN", font=font(30), fill=TEAL + (255,), anchor="ls")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.resize((W, H), Image.LANCZOS).convert("RGB").save(OUT, optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
