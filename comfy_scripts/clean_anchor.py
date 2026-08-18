#!/usr/bin/env python3
"""clean_anchor.py — 흰/단색 배경에서 그림자 제거

사용법:
    python3 clean_anchor.py ref/Amaryllis_anchor.png
    python3 clean_anchor.py in.png -o out.png --lum 140 --fill 128
    python3 clean_anchor.py in.png --dry-run
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageStat


def parse_fill(v: str) -> tuple[int, int, int]:
    """255 / '128' / '#A8C4C8' 모두 허용"""
    v = v.strip()
    if v.startswith("#"):
        h = v[1:]
        if len(h) != 6:
            raise argparse.ArgumentTypeError(f"hex는 #RRGGBB 형식: {v}")
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    n = int(v)
    return (n, n, n)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path, help="입력 이미지")
    ap.add_argument("-o", "--out", type=Path,
                    help="출력 경로 (기본: <입력>_clean.png)")
    ap.add_argument("--lum", type=float, default=150,
                    help="이 밝기보다 밝으면 배경 후보 (기본 150)")
    ap.add_argument("--chroma", type=float, default=18,
                    help="이 채도보다 낮으면 무채색으로 판정 (기본 18)")
    ap.add_argument("--fill", type=parse_fill, default=(255, 255, 255),
                    help="채울 색. 정수 또는 #RRGGBB (기본 255)")
    ap.add_argument("--dry-run", action="store_true",
                    help="저장하지 않고 통계만 출력")
    args = ap.parse_args()

    if not args.src.is_file():
        print(f"파일 없음: {args.src}", file=sys.stderr)
        return 1

    out_path = args.out or args.src.with_name(f"{args.src.stem}_clean.png")

    im = Image.open(args.src).convert("RGB")
    a = np.array(im).astype(np.int16)

    chroma = a.max(axis=2) - a.min(axis=2)
    lum = a.mean(axis=2)
    mask = (lum > args.lum) & (chroma < args.chroma)

    print(f"입력   {args.src}  {im.size[0]}x{im.size[1]}")
    print(f"임계값 lum>{args.lum} chroma<{args.chroma}")
    print(f"치환   {mask.mean() * 100:.1f}% → RGB{args.fill}")

    if args.dry_run:
        return 0

    a[mask] = args.fill
    res = Image.fromarray(a.astype(np.uint8))
    res.save(out_path)

    # 네 모서리 균일도 검증 (qc.py와 동일 기준)
    w, h, p = *res.size, 64
    boxes = {"좌상": (0, 0, p, p), "우상": (w - p, 0, w, p),
             "좌하": (0, h - p, p, h), "우하": (w - p, h - p, w, h)}
    worst = 0.0
    for name, box in boxes.items():
        sd = max(ImageStat.Stat(res.crop(box)).stddev)
        worst = max(worst, sd)
        print(f"  {name} stddev {sd:.2f}")

    print(f"저장   {out_path}")
    if worst > 6.0:
        print("경고: 모서리 stddev가 QC 기준(6.0)을 넘습니다. --lum을 낮춰보세요.")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())