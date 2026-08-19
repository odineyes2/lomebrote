#!/usr/bin/env python3
"""CSV 한 장으로 데이터셋 전체를 배치 생성한다.

    python3 2_csv_batch.py --csv turnaround.csv
    python3 2_csv_batch.py --wf wf_api.json --csv dataset.csv -o results/pass1
    python3 2_csv_batch.py --csv dataset.csv --dry-run

CSV 컬럼 (없는 건 빈 값으로 두면 됨):
    id, group, view, shot, expression, pose, lighting, extra, seed, refine

prompt 컬럼이 있으면 그 값을 subject_prompt 로 그대로 쓴다.
없으면 view/shot/expression/… 을 TEMPLATE 에 끼워 조립한다.
"""
import csv
import json
import sys

from common_args import base_parser, resolve
from comfy_utils import ComfyRunner, clone, load_workflow, new_seed, set_seed, set_subject_prompt

FIELDS = ("view", "shot", "expression", "pose", "lighting", "extra")
LEAD = ("1girl", "solo")


def build_prompt(row: dict) -> str:
    """prompt 컬럼이 있으면 그대로, 없으면 필드를 이어붙인다.

    빈 필드는 건너뛰므로 CSV 에 공란이 있어도 쉼표가 겹치지 않는다.
    """
    if raw := (row.get("prompt") or "").strip():
        return raw

    parts = [*LEAD, *((row.get(k) or "").strip() for k in FIELDS)]
    return ", ".join(p for p in parts if p)


def row_id(row: dict, i: int) -> str:
    for key in ("id", "page_id"):
        if (v := (row.get(key) or "").strip()):
            return v
    return f"{i:04d}"


def main() -> int:
    ap = base_parser("CSV 배치 생성", csv=True)
    ap.add_argument("--prefix", default="", help="저장 파일명 접두어")
    ap.add_argument("--start", type=int, default=1,
                    help="이 행 번호부터 시작 (1-base). 중단 후 재개용")
    args = ap.parse_args()

    workflow_path = resolve(args.workflow)
    csv_path = resolve(args.csv)
    out_dir = resolve(args.out)

    for p, label in ((workflow_path, "워크플로"), (csv_path, "CSV")):
        if not p.is_file():
            print(f"{label} 없음: {p}", file=sys.stderr)
            return 1

    base = load_workflow(str(workflow_path))
    with open(csv_path, encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))

    rows = rows[args.start - 1:]
    total = len(rows)
    print(f"워크플로 {workflow_path.name}   CSV {csv_path.name}   {total}행   출력 {out_dir}")

    if args.dry_run:
        for i, row in enumerate(rows, args.start):
            rid = row_id(row, i)
            seed = row.get("seed") or "(random)"
            print(f"  [{i:>3}] {rid}  seed={seed}")
            print(f"        {build_prompt(row)}")
        return 0

    out_dir.mkdir(parents=True, exist_ok=True)
    manifest = out_dir / "manifest.jsonl"

    ok = 0
    with ComfyRunner(args.server, quiet=args.quiet, timeout=args.timeout) as runner, \
            open(manifest, "a", encoding="utf-8") as ledger:

        for i, row in enumerate(rows, args.start):
            rid = row_id(row, i)
            seed = int(row["seed"]) if (row.get("seed") or "").strip() else new_seed()
            prompt = build_prompt(row)
            name = f"{args.prefix}{rid}_{seed}.png"

            print(f"\n[{i}/{args.start + total - 1}] {rid}  seed={seed}")

            wf = set_seed(set_subject_prompt(clone(base), prompt), seed)
            record = {**row, "row": i, "seed": seed, "prompt": prompt, "file": name}
            try:
                res = runner.run(wf, save_to=out_dir / name)
                record.update(prompt_id=res["prompt_id"], status="ok")
                ok += 1
                print(f"    저장 {name}")
            except Exception as exc:
                record.update(prompt_id="", status=f"fail: {exc}")
                print(f"    실패 {exc}", file=sys.stderr)

            ledger.write(json.dumps(record, ensure_ascii=False) + "\n")
            ledger.flush()

    print(f"\n완료 {ok}/{total}   →  {out_dir}")
    print(f"매니페스트 {manifest}")
    return 0 if ok == total else 2


if __name__ == "__main__":
    sys.exit(main())
