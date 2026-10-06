#!/usr/bin/env python3
"""Тёплый свет под стулом — пиксельный слой для сцены 2. Рождён 2026-10-06.

Замысел автора (README, 2025): «уют будут создавать тёплый комнатный свет, возникающий внутри пространства
под стулом». Стиль (чат, 15.12.2024): «грубо разлитый свет, как краска» — поэтому не гладкий градиент, а
несколько ступеней яркости с упорядоченным дизерингом на границах. Рисуется в родном разрешении сцены
480×280, в Godot кладётся слоем со сложением цветов (add) между задними ножками и Фотоном.

    python3 tools/teplo.py igra/scena2/teplo.png

Геометрия снята с ножек стула автора (scene_chair_480x280_collage.aseprite): низ сиденья ≈ y 137,
задние ножки x 95–110 и 175–188, передние x 140–161 и 225–242, пол под стулом ≈ y 246.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from aseprite_png import png  # noqa: E402

W, H = 480, 280
CVET = (255, 186, 104)          # тёплый комнатный, янтарь
STUPENI = (0.0, 0.22, 0.42, 0.62, 0.85)   # уровни прозрачности: «грубо», ступенями
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

VERH, NIZ = 137, 247            # низ сиденья и пол
CENTR_X = 172                   # середина пространства под стулом
ISTOCHNIK = (172, 146)          # откуда «горит» — прямо под сиденьем


def sila(x: int, y: int) -> float:
    """Яркость 0…1 в точке: объём под сиденьем + лужа света на полу."""
    s = 0.0
    if VERH <= y <= NIZ:                                   # объём: трапеция, расширяется к полу
        t = (y - VERH) / (NIZ - VERH)
        polu = 74 + 14 * t
        dx = abs(x - CENTR_X) / polu
        if dx < 1:
            dist = ((x - ISTOCHNIK[0]) ** 2 + ((y - ISTOCHNIK[1]) * 1.6) ** 2) ** 0.5
            k_polu = 0.25 + 0.75 * t ** 1.5                 # в воздухе слабо, к полу гуще
            s = max(s, (1 - dx) ** 1.4 * (0.18 + 0.32 * max(0.0, 1 - dist / 90) + 0.2 * k_polu))
    ex, ey = (x - CENTR_X) / 124, (y - NIZ) / 17           # лужа на полу
    d = (ex * ex + ey * ey) ** 0.5
    if d < 1:
        s = max(s, (1 - d ** 1.2) * 0.9)
    return min(1.0, s)


def main() -> int:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "igra/scena2/teplo.png")
    rgba = bytearray(W * H * 4)
    for y in range(H):
        for x in range(W):
            v = sila(x, y)
            if v <= 0:
                continue
            porog = (BAYER[y % 4][x % 4] + 0.5) / 16           # дизеринг между соседними ступенями
            uroven = v * (len(STUPENI) - 1)
            n = int(uroven)
            if uroven - n > porog:
                n += 1
            a = STUPENI[min(n, len(STUPENI) - 1)]
            if a <= 0:
                continue
            o = (y * W + x) * 4
            rgba[o:o + 4] = bytes((*CVET, round(a * 255)))
    png(out, W, H, rgba)
    print(f"тёплый свет → {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
