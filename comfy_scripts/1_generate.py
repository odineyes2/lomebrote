#!/usr/bin/env python3
"""워크플로를 실행한다. 1장이든 20장이든 이 스크립트 하나로.

    python3 1_generate.py                       워크플로에 저장된 시드로 1장
    python3 1_generate.py -c 20                 무작위 시드로 20장
    python3 1_generate.py --seed 1073105527350607
    python3 1_generate.py --seed 1073105527350607 -c 20    인접 시드 20개
    python3 1_generate.py --wf faceDetailer_v1_basic.json --randomize -c 5
    python3 1_generate.py -c 20 --dry-run       계획만 확인

시드 규칙
    --seed 없고 --randomize 없고 -c 1   →  워크플로에 저장된 시드를 그대로
    --seed 없고 (--randomize 또는 -c 2+) →  매 장 무작위
    --seed X, -c 1                      →  X 고정
    --seed X, -c N                      →  X, X+1, X+2 … (인접 시드 탐색용)
"""
import csv
import sys

from common_args import base_parser, resolve
from comfy_utils import (ComfyRunner, clone, get_seed, load_workflow,
                         new_seed, set_seed)


def plan_seeds(args) -> list[int | None]:
    """생성할 장수만큼 시드 목록을 만든다. None 은 워크플로 시드 유지."""
    if args.seed is not None:
        return [args.seed + i for i in range(args.count)]
    if args.randomize or args.count > 1:
        return [new_seed() for _ in range(args.count)]
    return [None]


def main() -> int:
    ap = base_parser("워크플로 실행 (단발 / 배치 공용)", count=True, count_default=1)
    ap.add_argument("--seed", "-s", type=int,
                    help="시드. -c 가 2 이상이면 이 값부터 1씩 증가시킨다")
    ap.add_argument("--randomize", "-r", action="store_true",
                    help="1장일 때도 시드를 무작위로 뽑는다")
    ap.add_argument("--prefix", default="gen",
                    help="저장 파일명 접두어 (기본: gen)")
    args = ap.parse_args()

    workflow_path = resolve(args.workflow)
    out_dir = resolve(args.out)

    if not workflow_path.is_file():
        print(f"워크플로 없음: {workflow_path}", file=sys.stderr)
        return 1
    if args.count < 1:
        print("--count 는 1 이상이어야 합니다", file=sys.stderr)
        return 1

    base = load_workflow(str(workflow_path))
    seeds = plan_seeds(args)

    print(f"워크플로 {workflow_path.name}   출력 {out_dir}   {args.count}장")
    if args.dry_run:
        for i, s in enumerate(seeds, 1):
            print(f"  [{i:>3}] seed={s if s is not None else f'{get_seed(base)} (워크플로 값 유지)'}")
        return 0

    out_dir.mkdir(parents=True, exist_ok=True)
    ledger = out_dir / "generated.csv"
    is_new = not ledger.exists()

    ok = 0
    with ComfyRunner(args.server, quiet=args.quiet, timeout=args.timeout) as runner, \
            open(ledger, "a", newline="", encoding="utf-8") as fp:
        writer = csv.writer(fp)
        if is_new:
            writer.writerow(["seed", "file", "workflow", "prompt_id", "status"])

        for i, seed in enumerate(seeds, 1):
            wf = clone(base)
            if seed is not None:
                set_seed(wf, seed)
            actual = seed if seed is not None else get_seed(wf)

            name = f"{args.prefix}_{actual}.png"
            head = f"[{i}/{args.count}] " if args.count > 1 else ""
            print(f"{head}seed={actual}")

            try:
                res = runner.run(wf, save_to=out_dir / name)
                writer.writerow([actual, name, workflow_path.name, res["prompt_id"], "ok"])
                ok += 1
                print(f"    저장 {name}")
            except Exception as exc:
                writer.writerow([actual, name, workflow_path.name, "", f"fail: {exc}"])
                print(f"    실패 {exc}", file=sys.stderr)
            fp.flush()

    print(f"\n완료 {ok}/{args.count}   →  {out_dir}")
    print(f"대장 {ledger}")
    return 0 if ok == args.count else 2


if __name__ == "__main__":
    sys.exit(main())
