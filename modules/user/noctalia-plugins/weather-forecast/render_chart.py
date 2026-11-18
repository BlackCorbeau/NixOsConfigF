#!/usr/bin/env python3
"""Draw a transparent weather chart using only Python stdlib."""

from __future__ import annotations

import math
import struct
import sys
import zlib
from pathlib import Path

WIDTH = 312
HEIGHT = 56
SCALE = 3
DAY_COUNT = 7


def parse_color(value: str) -> tuple[int, int, int]:
    text = value.strip().lstrip("#")
    if len(text) == 8:
        # Noctalia may include alpha in its resolved palette color.
        text = text[:6]
    if len(text) != 6:
        raise ValueError(f"Expected #RRGGBB color, got {value!r}")
    return tuple(int(text[index:index + 2], 16) for index in (0, 2, 4))


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    body = kind + payload
    return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def main() -> int:
    # New format: render_chart.py OUTPUT COLOR COUNT TEMP...
    # Legacy format: render_chart.py OUTPUT COLOR TEMP1..TEMP7
    if len(sys.argv) >= 5 and len(sys.argv) != 10:
        output = Path(sys.argv[1])
        rgb = parse_color(sys.argv[2])
        count = int(sys.argv[3])
        temperatures = [float(value) for value in sys.argv[4:4 + count]]
    elif len(sys.argv) == 10:
        output = Path(sys.argv[1])
        rgb = parse_color(sys.argv[2])
        temperatures = [float(value) for value in sys.argv[3:10]]
        count = len(temperatures)
    else:
        print(
            "usage: render_chart.py OUTPUT COLOR COUNT TEMP... "
            "or render_chart.py OUTPUT COLOR TEMP1 TEMP2 TEMP3 TEMP4 TEMP5 TEMP6 TEMP7",
            file=sys.stderr,
        )
        return 2

    if count < 1 or count > DAY_COUNT or len(temperatures) != count:
        raise ValueError("The chart requires 1 to 7 temperatures")
    if not all(math.isfinite(value) for value in temperatures):
        raise ValueError("The chart requires finite temperatures")

    high_width = WIDTH * SCALE
    high_height = HEIGHT * SCALE
    pixels = bytearray(high_width * high_height * 4)

    def paint_disc(x: float, y: float, radius: float) -> None:
        left = max(0, int(math.floor(x - radius)))
        right = min(high_width - 1, int(math.ceil(x + radius)))
        top = max(0, int(math.floor(y - radius)))
        bottom = min(high_height - 1, int(math.ceil(y + radius)))
        radius_squared = radius * radius

        for py in range(top, bottom + 1):
            dy = py + 0.5 - y
            for px in range(left, right + 1):
                dx = px + 0.5 - x
                if dx * dx + dy * dy <= radius_squared:
                    offset = (py * high_width + px) * 4
                    pixels[offset:offset + 4] = bytes((*rgb, 255))

    minimum = min(temperatures)
    maximum = max(temperatures)
    spread = maximum - minimum
    anchors: list[tuple[float, float]] = []

    for index, temperature in enumerate(temperatures):
        normalized = 0.5 if spread < 0.01 else 0.16 + ((temperature - minimum) / spread) * 0.68
        # Position each point under the center of the corresponding day column
        # in a fixed 7-day grid.
        x = index * (WIDTH - 1) / float(DAY_COUNT - 1)
        y = (1.0 - normalized) * (HEIGHT - 10) + 5
        anchors.append((x * SCALE, y * SCALE))

    # Smooth cosine interpolation between the available daily maxima.
    if len(anchors) == 1:
        paint_disc(anchors[0][0], anchors[0][1], 1.3 * SCALE)
    else:
        line_radius = 1.3 * SCALE
        for index in range(len(anchors) - 1):
            x1, y1 = anchors[index]
            x2, y2 = anchors[index + 1]
            distance = math.hypot(x2 - x1, y2 - y1)
            steps = max(20, int(distance * 1.5))

            for step in range(steps + 1):
                progress = step / steps
                eased = (1.0 - math.cos(math.pi * progress)) / 2.0
                x = x1 + (x2 - x1) * progress
                y = y1 + (y2 - y1) * eased
                paint_disc(x, y, line_radius)

    # Larger solid points sit exactly under the temperature labels.
    for x, y in anchors:
        paint_disc(x, y, 3.5 * SCALE)

    # Downsample the supersampled canvas with coverage-based alpha.
    rows = bytearray()
    sample_count = SCALE * SCALE
    for y in range(HEIGHT):
        rows.append(0)  # PNG filter: None
        for x in range(WIDTH):
            alpha_sum = 0
            for dy in range(SCALE):
                for dx in range(SCALE):
                    offset = (((y * SCALE + dy) * high_width) + (x * SCALE + dx)) * 4
                    alpha_sum += pixels[offset + 3]
            alpha = round(alpha_sum / sample_count)
            if alpha:
                rows.extend((*rgb, alpha))
            else:
                rows.extend((0, 0, 0, 0))

    header = struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", header)
        + png_chunk(b"IDAT", zlib.compress(bytes(rows), level=6))
        + png_chunk(b"IEND", b"")
    )

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(png)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
