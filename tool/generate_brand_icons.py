#!/usr/bin/env python3
"""Generate Android mipmaps + iOS AppIcon PNGs from assets/branding/myframe_logo.jpg.

Usage (from app/): python3 tool/generate_brand_icons.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LOGO = ROOT / "assets" / "branding" / "myframe_logo.jpg"

try:
    _LANCZOS = Image.Resampling.LANCZOS  # Pillow >= 9.1
except AttributeError:
    _LANCZOS = Image.LANCZOS  # type: ignore[attr-defined]


def square_logo(im: Image.Image, size: int) -> Image.Image:
    w, h = im.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    cropped = im.crop((left, top, left + side, top + side))
    return cropped.resize((size, size), _LANCZOS)


def main() -> None:
    if not LOGO.is_file():
        raise SystemExit(f"Missing {LOGO}")
    im = Image.open(LOGO).convert("RGBA")

    android = {
        ROOT / "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
        ROOT / "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
        ROOT / "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
        ROOT / "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
        ROOT / "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
    }
    ios_root = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    ios = {
        ios_root / "Icon-App-20x20@2x.png": 40,
        ios_root / "Icon-App-20x20@3x.png": 60,
        ios_root / "Icon-App-29x29@1x.png": 29,
        ios_root / "Icon-App-29x29@2x.png": 58,
        ios_root / "Icon-App-29x29@3x.png": 87,
        ios_root / "Icon-App-40x40@2x.png": 80,
        ios_root / "Icon-App-40x40@3x.png": 120,
        ios_root / "Icon-App-60x60@2x.png": 120,
        ios_root / "Icon-App-60x60@3x.png": 180,
        ios_root / "Icon-App-20x20@1x.png": 20,
        ios_root / "Icon-App-40x40@1x.png": 40,
        ios_root / "Icon-App-76x76@1x.png": 76,
        ios_root / "Icon-App-76x76@2x.png": 152,
        ios_root / "Icon-App-83.5x83.5@2x.png": 167,
        ios_root / "Icon-App-1024x1024@1x.png": 1024,
    }

    for path, px in {**android, **ios}.items():
        out = square_logo(im, px)
        path.parent.mkdir(parents=True, exist_ok=True)
        out.save(path, "PNG")
        print(f"Wrote {path} ({px}px)")

    launch_root = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for name, px in (
        ("LaunchImage.png", 280),
        ("LaunchImage@2x.png", 560),
        ("LaunchImage@3x.png", 840),
    ):
        path = launch_root / name
        square_logo(im, px).save(path, "PNG")
        print(f"Wrote {path} ({px}px)")


if __name__ == "__main__":
    main()
