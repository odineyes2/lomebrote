import json, random, argparse
from pathlib import Path
from comfy_utils import (
    load_workflow, set_seed, queue_prompt, wait_for_result,
    get_output_image_info, download_image
)

parser = argparse.ArgumentParser()
parser.add_argument("--workflow", default="workflow_api.json", help="사용할 워크플로우 API JSON 파일명")
parser.add_argument("--count", type=int, default=10, help="생성할 장수")
args = parser.parse_args()

base_workflow = load_workflow(args.workflow)
COUNT = args.count

OUTPUT_DIR = Path(__file__).parent / "results"
OUTPUT_DIR.mkdir(exist_ok=True)

results = []
for i in range(COUNT):
    workflow = json.loads(json.dumps(base_workflow))
    seed = random.randint(0, 2**32 - 1)
    workflow = set_seed(workflow, seed)
    prompt_id = queue_prompt(workflow)
    print(f"[{i+1}/{COUNT}] 제출됨 (seed={seed}) → {prompt_id}")
    outputs = wait_for_result(prompt_id)

    img_info = get_output_image_info(workflow, outputs)
    filename = img_info["filename"]

    img_bytes = download_image(filename, img_info.get("subfolder", ""))
    save_path = OUTPUT_DIR / filename
    save_path.write_bytes(img_bytes)

    print(f"   완료: {filename}  →  {save_path}")
    results.append({"seed": seed, "filename": filename})

print(f"\n=== {COUNT}장 결과 ===")
for r in results:
    print(r)