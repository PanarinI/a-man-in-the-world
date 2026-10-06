#!/usr/bin/env python3
"""Сцена из Aseprite → слои и расписание для Godot. Рождён 2026-10-06.

Зачем. Сцена 2 («под стулом») уже нарисована и оживлена автором в Aseprite: фон, задние ножки стула, Фотон,
дождь, передние ножки, облачко с репликой — по слоям, 127 кадров. Переносим её в Godot не видеороликом, а
слоями: каждый видимый слой становится картинками и расписанием «в каком кадре какая картинка и где». Godot
проигрывает расписание (`igra/scena_po_raspisaniyu.gd`), и в эти же слои потом встраиваются отклики на мышь
и звук.

    python3 tools/scena_iz_aseprite.py "Visual/scene_chair_480x280_collage.aseprite" igra/scena2

Пишет в папку: `<слой>_<n>.png` (одинаковые картинки слоя — один файл) и `raspisanie.json`:
{"w","h","dlit":[мс по кадрам],"tegi":[...],"sloi":[{"imya","fajl_prefiks","kadry":{кадр:[n,x,y]}}]} —
слои снизу вверх, только видимые и не группы.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from aseprite_png import chitat, piksel, png  # noqa: E402


def latin(imya: str, n: int) -> str:
    """Имя файла слоя латиницей (закон Сада): транслит + номер слоя, чтобы имена не совпали."""
    tabl = dict(zip("абвгдеёжзийклмнопрстуфхцчшщъыьэюя",
                    ["a", "b", "v", "g", "d", "e", "e", "zh", "z", "i", "j", "k", "l", "m", "n", "o", "p", "r",
                     "s", "t", "u", "f", "h", "c", "ch", "sh", "sch", "", "y", "", "e", "yu", "ya"]))
    t = "".join(tabl.get(c, c) for c in imya.lower())
    t = "".join(c if c.isalnum() else "_" for c in t).strip("_")
    return f"{n:02d}_{t or 'sloj'}"


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    f = chitat(src)
    sloi = []
    for nsloj, sloj in enumerate(f["sloi"]):
        if not sloj["vidim"] or sloj["tip"] != 0:
            continue
        prefiks = latin(sloj["imya"], nsloj)
        kartinki: dict[str, int] = {}
        kadry = {}
        for nk, kadr in enumerate(f["kadry"]):
            ya = next((c for c in kadr["yacheiki"] if c["sloj"] == nsloj), None)
            if ya and "svyaz" in ya:
                src_ya = next((c for c in f["kadry"][ya["svyaz"]]["yacheiki"] if c["sloj"] == nsloj), None)
                ya = dict(src_ya, x=ya["x"], y=ya["y"], prozr=ya["prozr"]) if src_ya else None
            if not ya or "pix" not in ya:
                continue
            w, h = ya["w"], ya["h"]
            rgba = bytearray(w * h * 4)
            mnozh = sloj["prozr"] / 255 * ya["prozr"] / 255
            for i in range(w * h):
                r, g, b, a = piksel(f, ya["pix"], i)
                rgba[i * 4:i * 4 + 4] = bytes((r, g, b, round(a * mnozh)))
            klyuch = hashlib.md5(bytes(rgba) + f"{w}x{h}".encode()).hexdigest()
            if klyuch not in kartinki:
                kartinki[klyuch] = len(kartinki)
                png(out / f"{prefiks}_{kartinki[klyuch]}.png", w, h, rgba)
            kadry[nk] = [kartinki[klyuch], ya["x"], ya["y"]]
        if kadry:
            sloi.append({"imya": sloj["imya"], "fajl_prefiks": prefiks, "kadry": kadry})
            print(f"  {prefiks}: {len(kadry)} кадров, картинок {len(kartinki)}")
    (out / "raspisanie.json").write_text(json.dumps(
        {"w": f["w"], "h": f["h"], "dlit": [k["dlit"] for k in f["kadry"]], "tegi": f["tegi"], "sloi": sloi},
        ensure_ascii=False), encoding="utf-8")
    print(f"{src.name}: {len(sloi)} слоёв → {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
