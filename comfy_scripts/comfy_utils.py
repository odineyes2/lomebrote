import requests, json, time
from pathlib import Path

SERVER = "http://127.0.0.1:8188"
WORKFLOW_PATH = Path(__file__).parent / "workflow_api.json"


def load_workflow() -> dict:
    with open(WORKFLOW_PATH) as f:
        return json.load(f)


def find_node_by_title(workflow: dict, title: str) -> str:
    for node_id, node in workflow.items():
        if node.get("_meta", {}).get("title") == title:
            return node_id
    raise ValueError(f"title '{title}'인 노드를 찾을 수 없음")


def set_subject_prompt(workflow: dict, text: str) -> dict:
    node_id = find_node_by_title(workflow, "subject_prompt")
    workflow[node_id]["inputs"]["text"] = text
    return workflow


def set_seed(workflow: dict, seed: int) -> dict:
    for node in workflow.values():
        if node["class_type"] == "KSampler":
            node["inputs"]["seed"] = seed
    return workflow


def set_framing(workflow: dict, preset_name: str) -> dict:
    presets = {
        "전신": (832, 1216),
        "얼굴클로즈업": (1024, 1024),
        "상반신무릎위": (896, 1152),
        "와이드샷": (1216, 832),
    }
    w, h = presets[preset_name]
    node_id = find_node_by_title(workflow, "output_resolution")
    workflow[node_id]["inputs"]["width"] = w
    workflow[node_id]["inputs"]["height"] = h
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