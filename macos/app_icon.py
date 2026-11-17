#!/usr/bin/env python3
"""Builds the macOS app icon from the app's logo, assets/icon/fortiva_icon.png.

    python3 macos/app_icon.py        # needs Pillow

macOS draws an icon as given, so it must already have the system's shape:
a rounded square of 824 x 824 in a 1024 canvas, with a soft shadow below.
An icon without it is shown inside a grey square on macOS 26. The logo is
cut to its drawing (its white background left out), scaled into the
square, and the result written at every size AppIcon.appiconset lists.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / "assets/icon/fortiva_icon.png"
OUT = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"

CANVAS = 1024
SQUARE = 824  # Apple's macOS icon grid
RADIUS = 185  # about 22.4% of the square, as the system's
DRAWING = 0.80  # share of the square the logo's taller side fills
SIZES = (16, 32, 64, 128, 256, 512, 1024)


def drawing(logo: Image.Image) -> Image.Image:
    """The logo cut to what differs from its white background."""
    white = Image.new("RGB", logo.size, (255, 255, 255))
    box = ImageChops.difference(logo.convert("RGB"), white).point(lambda v: 255 if v > 12 else 0).getbbox()
    return logo.crop(box)


def icon() -> Image.Image:
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    offset = (CANVAS - SQUARE) // 2

    # The shadow: the square's shape, dark, blurred and moved down a little.
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (offset, offset + 12, offset + SQUARE, offset + SQUARE + 12), RADIUS, fill=(0, 0, 0, 70)
    )
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(14)))

    square = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(square).rounded_rectangle(
        (offset, offset, offset + SQUARE, offset + SQUARE), RADIUS, fill=(255, 255, 255, 255)
    )
    canvas = Image.alpha_composite(canvas, square)

    logo = drawing(Image.open(LOGO).convert("RGBA"))
    scale = SQUARE * DRAWING / max(logo.size)
    logo = logo.resize((round(logo.width * scale), round(logo.height * scale)), Image.LANCZOS)
    at = ((CANVAS - logo.width) // 2, (CANVAS - logo.height) // 2)
    canvas.alpha_composite(logo, at)
    return canvas


def main() -> None:
    full = icon()
    for size in SIZES:
        full.resize((size, size), Image.LANCZOS).save(OUT / f"app_icon_{size}.png", optimize=True)
        print(f"app_icon_{size}.png")


if __name__ == "__main__":
    main()
