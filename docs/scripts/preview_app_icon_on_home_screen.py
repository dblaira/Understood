#!/usr/bin/env python3
"""Composite an app icon onto an iPhone home-screen screenshot for quick visual review.

Does not touch Xcode assets or require a build. Useful for comparing icon variants
(default vs apple-touch-icon) on a realistic home screen without changing the app bundle.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SCREENSHOT = (
    REPO_ROOT / "docs" / "previews" / "reference-home-screen.png"
)
DEFAULT_ICON = (
    REPO_ROOT
    / "Understood"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
    / "apple-touch-icon.png"
)
DEFAULT_OUTPUT = REPO_ROOT / "docs" / "previews" / "icon-home-screen-mockup.png"

# Calibrated against docs/previews/reference-home-screen.png (471×1024 export).
DOCK_ICON_SIZE = 77
DOCK_ICON_X = 248
DOCK_ICON_Y = 904
DOCK_SLOT_INDEX = 2  # third icon in a four-icon dock (0-based)


def content_bbox(icon: Image.Image) -> tuple[int, int, int, int]:
    pixels = icon.load()
    bg = pixels[0, 0][:3]
    min_x, min_y = icon.width, icon.height
    max_x = max_y = 0
    for y in range(icon.height):
        for x in range(icon.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 10 and (
                abs(red - bg[0]) > 8
                or abs(green - bg[1]) > 8
                or abs(blue - bg[2]) > 8
            ):
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
    return min_x, min_y, max_x, max_y


def ios_icon_mask(size: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    radius = int(size * 0.2237)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def prepare_icon(icon_path: Path, slot_size: int) -> Image.Image:
    source = Image.open(icon_path).convert("RGBA")
    bg_color = source.getpixel((0, 0))
    bbox = content_bbox(source)
    cropped = source.crop(bbox) if bbox[2] >= bbox[0] else source

    # Opaque slot fill so the mock fully covers the existing dock icon underneath.
    canvas = Image.new("RGB", (slot_size, slot_size), bg_color[:3])
    scale = min(slot_size / cropped.width, slot_size / cropped.height)
    fitted_size = (
        max(1, int(cropped.width * scale)),
        max(1, int(cropped.height * scale)),
    )
    fitted = cropped.resize(fitted_size, Image.Resampling.LANCZOS)
    offset = ((slot_size - fitted_size[0]) // 2, (slot_size - fitted_size[1]) // 2)
    canvas.paste(fitted, offset, fitted)
    return canvas.convert("RGBA")


def dock_icon_origin(screen_width: int, screen_height: int, slot_index: int) -> tuple[int, int]:
    _ = (screen_width, screen_height, slot_index)
    return DOCK_ICON_X, DOCK_ICON_Y


def composite_icon(
    screenshot_path: Path,
    icon_path: Path,
    output_path: Path,
    *,
    slot_index: int = DOCK_SLOT_INDEX,
) -> Path:
    base = Image.open(screenshot_path).convert("RGBA")
    icon = prepare_icon(icon_path, DOCK_ICON_SIZE)
    x, y = dock_icon_origin(base.width, base.height, slot_index)
    base.paste(icon, (x, y))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").save(output_path, quality=95)
    return output_path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Preview an app icon on an iPhone home-screen screenshot."
    )
    parser.add_argument(
        "--screenshot",
        type=Path,
        default=DEFAULT_SCREENSHOT,
        help="Home screen screenshot PNG",
    )
    parser.add_argument(
        "--icon",
        type=Path,
        default=DEFAULT_ICON,
        help="1024×1024 (or square) icon PNG to preview",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help="Where to write the mockup PNG",
    )
    parser.add_argument(
        "--slot",
        type=int,
        default=DOCK_SLOT_INDEX,
        help="Dock slot index (0=leftmost of four)",
    )
    args = parser.parse_args()

    output = composite_icon(
        args.screenshot,
        args.icon,
        args.output,
        slot_index=args.slot,
    )
    print(output)


if __name__ == "__main__":
    main()
