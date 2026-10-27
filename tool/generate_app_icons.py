"""Generate Carty launcher assets. Requires Python 3 and Pillow >= 10."""

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SCALE = 4
GREEN = "#087F5B"
MINT = "#A7F3D0"


def artwork(background):
    image = Image.new("RGBA", (1024 * SCALE, 1024 * SCALE), background)
    draw = ImageDraw.Draw(image)

    def line(points, color, width):
        points = [(int(x * SCALE), int(y * SCALE)) for x, y in points]
        radius = width * SCALE / 2
        draw.line(points, fill=color, width=width * SCALE, joint="curve")
        for x, y in points:
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)

    # Keep the mark inside Android adaptive icons' central safe region.
    line([(280, 350), (335, 350), (390, 590), (650, 590)], "white", 34)
    line([(355, 410), (715, 410), (675, 535), (380, 535)], "white", 34)
    for x in (425, 625):
        draw.ellipse(tuple(int(v * SCALE) for v in (x - 25, 640, x + 25, 690)), fill="white")
    line([(480, 450), (525, 490), (610, 375)], MINT, 30)
    return image


def main():
    opaque = artwork(GREEN).convert("RGB")
    foreground = artwork((0, 0, 0, 0))

    def save(image, path, size):
        path.parent.mkdir(parents=True, exist_ok=True)
        image.resize((size, size), Image.Resampling.LANCZOS).save(path)

    save(opaque, ROOT / "assets/branding/carty-icon.png", 1024)
    iconset = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for entry in json.loads((iconset / "Contents.json").read_text())["images"]:
        size = round(float(entry["size"].split("x")[0]) * float(entry["scale"][:-1]))
        save(opaque, iconset / entry["filename"], size)

    resources = ROOT / "android/app/src/main/res"
    for density, size, adaptive_size in (
        ("mdpi", 48, 108), ("hdpi", 72, 162), ("xhdpi", 96, 216),
        ("xxhdpi", 144, 324), ("xxxhdpi", 192, 432),
    ):
        save(opaque, resources / f"mipmap-{density}/ic_launcher.png", size)
        save(foreground, resources / f"drawable-{density}/ic_launcher_foreground.png", adaptive_size)


if __name__ == "__main__":
    main()
