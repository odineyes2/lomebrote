import csv, json, random
from pathlib import Path
from comfy_utils import (
    load_workflow, set_subject_prompt, set_seed,
    queue_prompt, wait_for_result, download_image
)

CSV_PATH = Path(__file__).parent / "batch_list.csv"
OUTPUT_DIR = Path(__file__).parent / "results"
OUTPUT_DIR.mkdir(exist_ok=True)

base_workflow = load_workflow()

with open(CSV_PATH, encoding="utf-8") as f:
    reader = csv.DictReader(f)
    rows = list(reader)

print(f"총 {len(rows)}개 항목 처리 시작")

for i, row in enumerate(rows, 1):
    page_id = row["page_id"].strip()
    prompt_text = row["prompt"].strip()
    seed = int(row["seed"]) if row.get("seed", "").strip() else random.randint(0, 2**32 - 1)

    workflow = json.loads(json.dumps(base_workflow))
    workflow = set_subject_prompt(workflow, prompt_text)
    workflow = set_seed(workflow, seed)

    print(f"[{i}/{len(rows)}] {page_id} (seed={seed}) 제출 중...")
    prompt_id = queue_prompt(workflow)
    outputs = wait_for_result(prompt_id)

    img_info = outputs["11"]["images"][0]
    img_bytes = download_image(img_info["filename"], img_info.get("subfolder", ""))

    save_path = OUTPUT_DIR / f"{page_id}_{seed}.png"
    save_path.write_bytes(img_bytes)
    print(f"   저장됨: {save_path.name}")

print("배치 완료.")