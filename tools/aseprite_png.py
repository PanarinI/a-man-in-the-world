#!/usr/bin/env python3
"""Aseprite → PNG без Aseprite. Рождён 2026-10-06.

Зачем. Пиксель Фотона нарисован в Aseprite (`Visual/*.aseprite`), а самой Aseprite на этом Mac нет.
Формат открыт (github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md), поэтому кадры читаем сами:
слои, ячейки (cels), палитра, теги анимаций. Только стандартная библиотека Python.

    python3 tools/aseprite_png.py Visual/foton_move_left_right.aseprite out/        # каждый кадр — PNG
    python3 tools/aseprite_png.py Visual/foton_move_left_right.aseprite out/ --list # слои, кадры, теги
    python3 tools/aseprite_png.py Visual/foton_v2_sprite_0.1.aseprite out/ --sloi   # каждый слой отдельно

Что умеет: цвет RGBA, оттенки серого и палитра; видимые слои с прозрачностью, режим смешивания «обычный»;
связанные ячейки; теги (имена анимаций и диапазоны кадров) — в `теги.json` рядом с кадрами. Слои-группы и
тайлмапы пропускает, другие режимы смешивания рисует как обычный.
"""
from __future__ import annotations

import json
import struct
import sys
import zlib
from pathlib import Path


def chitat(path: Path) -> dict:
    b = path.read_bytes()
    (razmer, magic, kadrov, w, h, glubina, flagi, _skor, _a, _b, prozr, _x, cvetov, _pw, _ph) = struct.unpack_from(
        "<IHHHHHIHIIB3sHBB", b, 0)
    if magic != 0xA5E0:
        raise ValueError(f"{path.name}: не Aseprite (magic {magic:#x})")
    sloi, kadry, palitra, tegi = [], [], {}, []
    pos = 128
    for nomer in range(kadrov):
        (bajt, fmagic, staryh, dlit, _r, novyh) = struct.unpack_from("<IHHH2sI", b, pos)
        if fmagic != 0xF1FA:
            raise ValueError(f"{path.name}: битый кадр {nomer}")
        chankov = novyh or staryh
        cp, kadr = pos + 16, {"dlit": dlit, "yacheiki": []}
        for _ in range(chankov):
            (crazmer, ctip) = struct.unpack_from("<IH", b, cp)
            d = b[cp + 6: cp + crazmer]
            if ctip == 0x2004:                                    # слой
                (lflagi, ltip, uroven, _dw, _dh, smesh, prozrachnost) = struct.unpack_from("<HHHHHHB", d, 0)
                n = struct.unpack_from("<H", d, 16)[0]
                sloi.append({"imya": d[18:18 + n].decode("utf-8", "replace"), "vidim": bool(lflagi & 1),
                             "tip": ltip, "prozr": prozrachnost, "smesh": smesh})
            elif ctip == 0x2005:                                  # ячейка
                (sloj, x, y, cprozr, ctipj) = struct.unpack_from("<HhhBH", d, 0)
                ya = {"sloj": sloj, "x": x, "y": y, "prozr": cprozr}
                if ctipj == 1:
                    ya["svyaz"] = struct.unpack_from("<H", d, 16)[0]
                elif ctipj in (0, 2):
                    (cw, ch) = struct.unpack_from("<HH", d, 16)
                    pix = d[20:] if ctipj == 0 else zlib.decompress(d[20:])
                    ya.update(w=cw, h=ch, pix=pix)
                else:
                    cp += crazmer
                    continue                                      # тайлмапы не нужны
                kadr["yacheiki"].append(ya)
            elif ctip == 0x2019:                                  # палитра
                (_vsego, perv, posl) = struct.unpack_from("<III", d, 0)
                p = 20
                for i in range(perv, posl + 1):
                    (pflagi, r, g, bl, a) = struct.unpack_from("<HBBBB", d, p)
                    p += 6
                    if pflagi & 1:
                        p += 2 + struct.unpack_from("<H", d, p)[0]
                    palitra[i] = (r, g, bl, a)
            elif ctip == 0x2018:                                  # теги анимаций
                n = struct.unpack_from("<H", d, 0)[0]
                p = 10
                for _ in range(n):
                    (ot, do, _napr) = struct.unpack_from("<HHB", d, p)
                    p += 17
                    dl = struct.unpack_from("<H", d, p)[0]
                    tegi.append({"imya": d[p + 2:p + 2 + dl].decode("utf-8", "replace"), "ot": ot, "do": do})
                    p += 2 + dl
            cp += crazmer
        kadry.append(kadr)
        pos += bajt
    return {"w": w, "h": h, "glubina": glubina, "prozr_indeks": prozr, "sloi": sloi, "kadry": kadry,
            "palitra": palitra, "tegi": tegi}


def piksel(fajl: dict, pix: bytes, i: int) -> tuple[int, int, int, int]:
    g = fajl["glubina"]
    if g == 32:
        return tuple(pix[i * 4:i * 4 + 4])                       # type: ignore[return-value]
    if g == 16:
        v, a = pix[i * 2], pix[i * 2 + 1]
        return (v, v, v, a)
    idx = pix[i]
    if idx == fajl["prozr_indeks"]:
        return (0, 0, 0, 0)
    return fajl["palitra"].get(idx, (0, 0, 0, 0))


def sobrat_kadr(fajl: dict, nomer: int) -> bytearray:
    """Кадр целиком: видимые слои снизу вверх, обычное смешивание с учётом прозрачности слоя и ячейки."""
    w, h = fajl["w"], fajl["h"]
    holst = bytearray(w * h * 4)
    yacheiki = {}
    for ya in fajl["kadry"][nomer]["yacheiki"]:
        if "svyaz" in ya:                                         # связанная ячейка — берём из другого кадра
            src = next((c for c in fajl["kadry"][ya["svyaz"]]["yacheiki"] if c["sloj"] == ya["sloj"]), None)
            if src:
                ya = dict(src, x=ya["x"], y=ya["y"], prozr=ya["prozr"])
        if "pix" in ya:
            yacheiki[ya["sloj"]] = ya
    for nsloj, sloj in enumerate(fajl["sloi"]):
        ya = yacheiki.get(nsloj)
        if not ya or not sloj["vidim"] or sloj["tip"] != 0:
            continue
        mnozh = sloj["prozr"] / 255 * ya["prozr"] / 255
        for yy in range(ya["h"]):
            ty = ya["y"] + yy
            if not 0 <= ty < h:
                continue
            for xx in range(ya["w"]):
                tx = ya["x"] + xx
                if not 0 <= tx < w:
                    continue
                r, g, bl, a = piksel(fajl, ya["pix"], yy * ya["w"] + xx)
                a = a * mnozh / 255
                if a <= 0:
                    continue
                o = (ty * w + tx) * 4
                da = holst[o + 3] / 255
                na = a + da * (1 - a)
                for k, c in enumerate((r, g, bl)):
                    holst[o + k] = round((c * a + holst[o + k] * da * (1 - a)) / na)
                holst[o + 3] = round(na * 255)
    return holst


def png(put: Path, w: int, h: int, rgba: bytes) -> None:
    def chank(tip: bytes, dannye: bytes) -> bytes:
        return struct.pack(">I", len(dannye)) + tip + dannye + struct.pack(">I", zlib.crc32(tip + dannye))
    stroki = b"".join(b"\x00" + bytes(rgba[y * w * 4:(y + 1) * w * 4]) for y in range(h))
    put.write_bytes(b"\x89PNG\r\n\x1a\n" + chank(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                    + chank(b"IDAT", zlib.compress(stroki, 9)) + chank(b"IEND", b""))


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    fajl = chitat(src)
    if "--list" in sys.argv:
        print(f"{src.name}: {fajl['w']}×{fajl['h']}, глубина {fajl['glubina']}, кадров {len(fajl['kadry'])}")
        for i, s in enumerate(fajl["sloi"]):
            print(f"  слой {i}: «{s['imya']}» {'видим' if s['vidim'] else 'скрыт'} тип {s['tip']} прозр {s['prozr']}")
        for t in fajl["tegi"]:
            print(f"  тег «{t['imya']}»: кадры {t['ot']}–{t['do']}")
        print("  длительности кадров, мс:", [k["dlit"] for k in fajl["kadry"]])
        return 0
    out.mkdir(parents=True, exist_ok=True)
    if "--sloi" in sys.argv:                  # каждый слой отдельно — варианты облика лежат слоями
        for nsloj, sloj in enumerate(fajl["sloi"]):
            for i in range(len(fajl["kadry"])):
                if not any(ya["sloj"] == nsloj for ya in fajl["kadry"][i]["yacheiki"]):
                    continue
                odin = dict(fajl, sloi=[dict(sl, vidim=(n == nsloj)) for n, sl in enumerate(fajl["sloi"])])
                imya = "".join(c if c.isalnum() else "_" for c in sloj["imya"])
                png(out / f"{src.stem}_{imya}_{i:02d}.png", fajl["w"], fajl["h"], sobrat_kadr(odin, i))
        print(f"{src.name}: слои по отдельности → {out}")
        return 0
    for i in range(len(fajl["kadry"])):
        png(out / f"{src.stem}_{i:02d}.png", fajl["w"], fajl["h"], sobrat_kadr(fajl, i))
    (out / f"{src.stem}_tegi.json").write_text(json.dumps(
        {"w": fajl["w"], "h": fajl["h"], "dlit": [k["dlit"] for k in fajl["kadry"]], "tegi": fajl["tegi"]},
        ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{src.name}: {len(fajl['kadry'])} кадров → {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
