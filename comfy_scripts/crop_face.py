#!/usr/bin/env python3
"""인물 영역을 찾아 머리 부분을 중앙 정렬로 크롭"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

src, out = Path(sys.argv[1]), Path(sys.argv[2])
HEAD_RATIO = float(sys.argv[3]) if len(sys.argv) > 3 else 0.22  # 위에서 몇 %까지
PAD        = float(sys.argv[4]) if len(sys.argv) > 4 else 0.12  # 좌우 여백 비율

im = Image.open(src).convert("RGB")
a = np.array(im)
w, h = im.size

# 비배경(어둡거나 유채색인) 픽셀 = 인물
nonbg = (a.mean(axis=2) < 240) | ((a.max(axis=2) - a.min(axis=2)) > 20)

bottom = int(h * HEAD_RATIO)
band = nonbg[:bottom]
cols = np.where(band.any(axis=0))[0]
rows = np.where(band.any(axis=1))[0]
if len(cols) == 0:
    sys.exit("인물을 못 찾음. HEAD_RATIO를 키워보세요.")

x0, x1 = cols[0], cols[-1]
y0, y1 = rows[0], bottom
pad = int((x1 - x0) * PAD)

box = (max(0, x0 - pad), max(0, y0 - pad),
       min(w, x1 + pad), min(h, y1 + pad))
crop = im.crop(box)
print(f"원본 {w}x{h}  인물폭 {x0}~{x1}  크롭 {crop.size}")

scale = 1024 / max(crop.size)
crop = crop.resize((int(crop.width*scale), int(crop.height*scale)), Image.LANCZOS)
out.parent.mkdir(parents=True, exist_ok=True)
crop.save(out)
print(f"저장 {out}  {crop.size}")
