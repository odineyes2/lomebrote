import requests, json, time, uuid  
from pathlib import Path

SERVER = "http://127.0.0.1:8188"
# WORKFLOW_PATH = Path(__file__).parent / "workflow_api.json"


# def load_workflow() -> dict:
#     with open(WORKFLOW_PATH) as f:
#         return json.load(f)

def load_workflow(filename: str = "workflow_api.json") -> dict:
    path = Path(__file__).parent / filename
    with open(path) as f:
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


# def queue_prompt(workflow: dict) -> str:
#     resp = requests.post(f"{SERVER}/prompt", json={"prompt": workflow})
#     resp.raise_for_status()
#     return resp.json()["prompt_id"]


def wait_for_result(prompt_id: str, timeout_s: int = 120) -> dict:
    for _ in range(timeout_s // 2):
        resp = requests.get(f"{SERVER}/history/{prompt_id}")
        history = resp.json()
        if prompt_id in history:
            return history[prompt_id]["outputs"]
        time.sleep(2)
    raise TimeoutError("생성이 시간 내에 끝나지 않음")

def generate_client_id() -> str:
    return str(uuid.uuid4())


def queue_prompt(workflow: dict, client_id: str = None) -> str:
    payload = {"prompt": workflow}
    if client_id:
        payload["client_id"] = client_id
    resp = requests.post(f"{SERVER}/prompt", json=payload)
    resp.raise_for_status()
    return resp.json()["prompt_id"]

def download_image(filename: str, subfolder: str = "", img_type: str = "output") -> bytes:
    params = {"filename": filename, "subfolder": subfolder, "type": img_type}
    resp = requests.get(f"{SERVER}/view", params=params)
    resp.raise_for_status()
    return resp.content

def get_node_title(workflow: dict, node_id: str) -> str:
    node = workflow.get(node_id, {})
    return node.get("_meta", {}).get("title", f"노드 {node_id}")


def print_progress_bar(label: str, current: int, total: int, bar_width: int = 30):
    import sys
    ratio = current / total if total else 0
    filled = int(bar_width * ratio)
    bar = "█" * filled + "░" * (bar_width - filled)
    percent = ratio * 100
    sys.stdout.write(f"\r    {label:<12} |{bar}| {current}/{total} ({percent:5.1f}%)")
    sys.stdout.flush()

def get_output_image_info(workflow: dict, outputs: dict, title: str = "final_output") -> dict:
    node_id = find_node_by_title(workflow, title)
    return outputs[node_id]["images"][0]