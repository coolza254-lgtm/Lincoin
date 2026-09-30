"""Generate the Android launcher icons and in-app brand images from
logo-source.png. Run after changing the logo:

    python3 tools/brand/make_icons.py

Needs Pillow. Outputs are committed so builds do not need Python.
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).with_name("logo-source.png")
RES = ROOT / "app/android/app/src/main/res"
BRAND = ROOT / "app/assets/brand"
BG = (253, 252, 251)
# Symbol only (coin, book, bubbles): the wordmark is unreadable at icon size.
SYMBOL_BOX = (344, 254, 1012, 794)
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def symbol() -> Image.Image:
    im = Image.open(SRC).convert("RGBA").crop(SYMBOL_BOX)
    # Make the near-white card background transparent so it sits on any bg.
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            d = max(abs(r - BG[0]), abs(g - BG[1]), abs(b - BG[2]))
            if d < 6:
                px[x, y] = (r, g, b, 0)
            elif d < 18:
                px[x, y] = (r, g, b, int(255 * (d - 6) / 12))
    return im


def fit(sym: Image.Image, canvas: int, share: float) -> Image.Image:
    """Center [sym] on a transparent square, its longer side = share×canvas."""
    scale = canvas * share / max(sym.size)
    s = sym.resize((round(sym.width * scale), round(sym.height * scale)), Image.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.alpha_composite(s, ((canvas - s.width) // 2, (canvas - s.height) // 2))
    return out


def main() -> None:
    sym = symbol()
    for name, k in DENSITIES.items():
        d = RES / f"mipmap-{name}"
        d.mkdir(parents=True, exist_ok=True)
        # Adaptive icon foreground: 108dp, content inside the 66dp safe zone.
        fit(sym, round(108 * k), 0.58).save(d / "ic_launcher_foreground.png")
        # Legacy icon (Android < 8): rounded square.
        size = round(48 * k)
        big = size * 4
        base = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        ImageDraw.Draw(base).rounded_rectangle(
            (big * 0.04, big * 0.04, big * 0.96, big * 0.96), radius=big * 0.22, fill=BG + (255,))
        base.alpha_composite(fit(sym, big, 0.72))
        base.resize((size, size), Image.LANCZOS).save(d / "ic_launcher.png")
    any_dir = RES / "mipmap-anydpi-v26"
    any_dir.mkdir(exist_ok=True)
    (any_dir / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n')
    (RES / "values/ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#%02X%02X%02X</color>\n</resources>\n' % BG)
    BRAND.mkdir(parents=True, exist_ok=True)
    fit(sym, 512, 0.96).save(BRAND / "symbol.png", optimize=True)
    full = Image.open(SRC).convert("RGB").crop((150, 140, 1106, 1096)).resize((640, 640), Image.LANCZOS)
    full.save(BRAND / "logo.png", optimize=True)


if __name__ == "__main__":
    main()
