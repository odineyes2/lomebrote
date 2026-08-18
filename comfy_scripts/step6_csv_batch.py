import csv, json, random
from pathlib import Path
import websocket
from comfy_utils import (
    load_workflow, set_subject_prompt, set_seed,
    queue_prompt, download_image, generate_client_id,
    get_node_title, print_progress_bar
)

CSV_PATH = Path(__file__).parent / "batch_list.csv"
OUTPUT_DIR = Path(__file__).parent / "results"
OUTPUT_DIR.mkdir(exist_ok=True)

base_workflow = load_workflow()

with open(CSV_PATH, encoding="utf-8") as f:
    rows = list(csv.DictReader(f))

total = len(rows)
print(f"총 {total}개 항목 처리 시작\n")

client_id = generate_client_id()
ws = websocket.WebSocket()
ws.connect(f"ws://127.0.0.1:8188/ws?clientId={client_id}")

for i, row in enumerate(rows, 1):
    page_id = row["page_id"].strip()
    prompt_text = row["prompt"].strip()
    seed = int(row["seed"]) if row.get("seed", "").strip() else random.randint(0, 2**32 - 1)

    workflow = json.loads(json.dumps(base_workflow))
    workflow = set_subject_prompt(workflow, prompt_text)
    workflow = set_seed(workflow, seed)

    print(f"[{i}/{total}] {page_id} (seed={seed}) 제출 중...")
    prompt_id = queue_prompt(workflow, client_id=client_id)

    # 이 항목이 끝날 때까지 진행률만 수신
    while True:
        raw = ws.recv()
        if not isinstance(raw, str):
            continue
        message = json.loads(raw)
        msg_type = message.get("type")
        data = message.get("data", {})

        if data.get("prompt_id") not in (None, prompt_id):
            continue  # 다른 prompt_id의 메시지는 무시

        if msg_type == "progress":
            print_progress_bar("진행률", data["value"], data["max"])

        elif msg_type == "executing":
            node = data.get("node")
            if node is None:
                print()  # 진행바 줄바꿈
                break
            title = get_node_title(workflow, node)
            print(f"\n    ▶ {title}")

    outputs_resp = None
    import requests
    from comfy_utils import SERVER
    outputs_resp = requests.get(f"{SERVER}/history/{prompt_id}").json()
    img_info = outputs_resp[prompt_id]["outputs"]["11"]["images"][0]
    img_bytes = download_image(img_info["filename"], img_info.get("subfolder", ""))

    save_path = OUTPUT_DIR / f"{page_id}_{seed}.png"
    save_path.write_bytes(img_bytes)
    print(f"   저장됨: {save_path.name}\n")

ws.close()
print(f"배치 완료. 총 {total}개 저장됨 → {OUTPUT_DIR}")