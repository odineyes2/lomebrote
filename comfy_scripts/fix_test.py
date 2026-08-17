import requests, json, time

SERVER = "http://127.0.0.1:8188"

def find_node_by_title(workflow: dict, title: str) -> str:
    for node_id, node in workflow.items():
        if node.get("_meta", {}).get("title") == title:
            return node_id
    raise ValueError(f"title '{title}'인 노드를 찾을 수 없음")

def set_subject_prompt(workflow: dict, text: str) -> dict:
    node_id = find_node_by_title(workflow, "subject_prompt")
    workflow[node_id]["inputs"]["text"] = text
    return workflow

def queue_prompt(workflow: dict) -> str:
    resp = requests.post(f"{SERVER}/prompt", json={"prompt": workflow})
    resp.raise_for_status()
    return resp.json()["prompt_id"]

def wait_for_result(prompt_id: str, timeout_s: int = 120) -> dict:
    for _ in range(timeout_s // 2):
        resp = requests.get(f"{SERVER}/history/{prompt_id}")
        history = resp.json()
        if prompt_id in history:
            return history[prompt_id]["outputs"]
        time.sleep(2)
    raise TimeoutError("생성이 시간 내에 끝나지 않음")


# --- 실제 테스트 ---
with open("workflow_api.json") as f:
    workflow = json.load(f)

workflow = set_subject_prompt(
    workflow,
    "1girl, solo, sitting on a bench, reading a book, autumn park, warm sunlight"
)

prompt_id = queue_prompt(workflow)
print("제출됨:", prompt_id)

outputs = wait_for_result(prompt_id)
print("결과:", outputs)