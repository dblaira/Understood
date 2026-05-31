#!/usr/bin/env python3
"""Measure black-hero to light-section cutoff ratio from a full-screen PNG.

Usage:
  python3 docs/scripts/measure_hero_cutoff.py screenshot.png

Looks for the largest mean-luminance jump between consecutive rows (typical:
black hero -> cream section). Prints cutoff_ratio = row_index / height.
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Install Pillow: pip3 install --user Pillow", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    if len(sys.argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(2)
    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"Not a file: {path}", file=sys.stderr)
        sys.exit(1)

    img = Image.open(path).convert("RGB")
    w, h = img.size
    pix = img.load()

    lum: list[float] = []
    for y in range(h):
        s = 0.0
        for x in range(w):
            r, g, b = pix[x, y]
            s += 0.2126 * r + 0.7152 * g + 0.0722 * b
        lum.append(s / w)

    start = int(h * 0.4)
    max_d = -1e9
    max_i = start
    for i in range(start, h - 1):
        d = lum[i + 1] - lum[i]
        if d > max_d:
            max_d = d
            max_i = i

    ratio = max_i / h
    print(f"size: {w}x{h}")
    print(f"cutoff_row: {max_i}")
    print(f"cutoff_ratio: {ratio:.4f}")
    print(f"delta_lum: {max_d:.2f}")
    ref = 0.634
    tol = 0.02
    ok = abs(ratio - ref) <= tol
    print(f"vs_ref_0.634: {'PASS' if ok else 'FAIL'} (tolerance ±{tol})")


if __name__ == "__main__":
    main()
