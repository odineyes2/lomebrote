"""ComfyUI API 유틸.

핵심은 ComfyRunner — 큐잉 / 웹소켓 진행률 / 결과 회수를 한 덩어리로 묶는다.
기존 step5_progress.py 의 역할이 여기로 흡수됐다.
"""
import json
import random
import sys
import time
import uuid
from pathlib import Path

import requests
import websocket

SERVER = "http://127.0.0.1:8188"

# 시드를 주입할 노드 타입. FaceDetailer 도 자체 seed 를 갖는다.
SEED_CLASS_TYPES = ("KSampler", "KSamplerAdvanced", "FaceDetailer")


# ---------------------------------------------------------------- 워크플로 조작

def load_workflow(filename: str = "wf_api.json") -> dict:
    path = Path(filename)
    if not path.is_absolute():
        path = Path(__file__).parent / path
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def clone(workflow: dict) -> dict:
    """행마다 원본을 건드리지 않도록 깊은 복사."""
    return json.loads(json.dumps(workflow))


def find_node_by_title(workflow: dict, title: str) -> str:
    for node_id, node in workflow.items():
        if node.get("_meta", {}).get("title") == title:
            return node_id
    raise ValueError(f"title '{title}'인 노드를 찾을 수 없음")


def get_node_title(workflow: dict, node_id: str) -> str:
    return workflow.get(node_id, {}).get("_meta", {}).get("title", f"노드 {node_id}")


def set_text(workflow: dict, title: str, text: str) -> dict:
    """제목으로 CLIPTextEncode 노드를 찾아 text 를 갈아끼운다."""
    workflow[find_node_by_title(workflow, title)]["inputs"]["text"] = text
    return workflow


def set_subject_prompt(workflow: dict, text: str) -> dict:
    return set_text(workflow, "subject_prompt", text)


def set_seed(workflow: dict, seed: int, *, offset_per_node: bool = True) -> dict:
    """시드를 주입한다.

    offset_per_node=True 면 노드마다 seed+0, +1, +2 … 로 어긋나게 넣는다.
    모든 샘플러에 같은 값을 넣으면 hires 패스가 base 와 같은 노이즈를 쓰게 되어
    디테일이 덜 붙는 경우가 있어서, 기본값을 어긋나게 잡았다.
    같은 값을 원하면 False.
    """
    i = 0
    for node in workflow.values():
        if node.get("class_type") in SEED_CLASS_TYPES:
            node["inputs"]["seed"] = (seed + i) % (2 ** 32) if offset_per_node else seed
            i += 1
    return workflow


def get_seed(workflow: dict) -> int | None:
    """워크플로에 저장된 시드를 읽는다. 첫 샘플러 기준."""
    for node in workflow.values():
        if node.get("class_type") in SEED_CLASS_TYPES:
            return node["inputs"].get("seed")
    return None


def set_framing(workflow: dict, preset_name: str) -> dict:
    presets = {
        "전신": (832, 1216),
        "얼굴클로즈업": (1024, 1024),
        "상반신무릎위": (896, 1152),
        "와이드샷": (1216, 832),
    }
    w, h = presets[preset_name]
    node_id = find_node_by_title(workflow, "output_resolution")
    workflow[node_id]["inputs"].update(width=w, height=h)
    return workflow


def new_seed() -> int:
    return random.randint(0, 2 ** 32 - 1)


# ---------------------------------------------------------------- 표시

def print_progress_bar(label: str, current: int, total: int, bar_width: int = 30):
    ratio = current / total if total else 0
    bar = "█" * int(bar_width * ratio) + "░" * (bar_width - int(bar_width * ratio))
    sys.stdout.write(f"\r    {label:<14} |{bar}| {current}/{total} ({ratio * 100:5.1f}%)")
    sys.stdout.flush()


# ---------------------------------------------------------------- 실행 엔진

class ComfyRunner:
    """큐잉 → 진행률 수신 → 결과 회수를 담당.

        with ComfyRunner() as runner:
            for row in rows:
                runner.run(wf, save_to=Path("results/a.png"))

    웹소켓을 한 번만 열고 재사용하므로, 배치에서 항목마다 재접속하지 않는다.
    """

    def __init__(self, server: str = SERVER, *, quiet: bool = False,
                 timeout: int = 900):
        self.server = server.rstrip("/")
        self.ws_url = self.server.replace("http://", "ws://").replace("https://", "wss://")
        self.client_id = str(uuid.uuid4())
        self.quiet = quiet
        self.timeout = timeout
        self.ws: websocket.WebSocket | None = None

    # -- 컨텍스트 매니저 -------------------------------------------------
    def __enter__(self) -> "ComfyRunner":
        self.ws = websocket.WebSocket()
        self.ws.connect(f"{self.ws_url}/ws?clientId={self.client_id}")
        return self

    def __exit__(self, *exc) -> bool:
        if self.ws:
            try:
                self.ws.close()
            except Exception:
                pass
        return False

    # -- 개별 단계 -------------------------------------------------------
    def submit(self, workflow: dict) -> str:
        resp = requests.post(f"{self.server}/prompt",
                             json={"prompt": workflow, "client_id": self.client_id},
                             timeout=30)
        if resp.status_code >= 400:
            raise RuntimeError(f"큐잉 거부 ({resp.status_code}): {resp.text[:400]}")
        return resp.json()["prompt_id"]

    def monitor(self, workflow: dict, prompt_id: str) -> None:
        """이 prompt_id 가 끝날 때까지 진행률을 표시한다."""
        deadline = time.time() + self.timeout
        label = "실행 중"

        while True:
            remaining = deadline - time.time()
            if remaining <= 0:
                raise TimeoutError(f"{prompt_id} 가 {self.timeout}초 안에 끝나지 않음")

            self.ws.settimeout(min(30, max(1, remaining)))
            try:
                raw = self.ws.recv()
            except websocket.WebSocketTimeoutException:
                continue          # 조용한 구간일 뿐, deadline 으로만 판정
            if not isinstance(raw, str):
                continue           # 바이너리 프리뷰 프레임

            msg = json.loads(raw)
            mtype, data = msg.get("type"), msg.get("data", {})
            pid = data.get("prompt_id")

            # prompt_id 가 실린 메시지는 내 것만 본다.
            # progress 메시지에 prompt_id 가 없는 구버전에서는 그대로 통과시킨다.
            if pid is not None and pid != prompt_id:
                continue

            if mtype == "executing":
                node = data.get("node")
                if node is None:
                    if not self.quiet:
                        print()
                    return
                label = get_node_title(workflow, node)
                if not self.quiet:
                    print(f"\n    ▶ {label}")

            elif mtype == "progress" and not self.quiet:
                print_progress_bar(label, data.get("value", 0), data.get("max", 1))

            elif mtype == "execution_error":
                raise RuntimeError(
                    f"실행 오류: {data.get('exception_type')} / "
                    f"{data.get('exception_message')} (노드 {data.get('node_id')})")

            elif mtype == "execution_interrupted":
                raise RuntimeError("실행이 중단됨 (ComfyUI 에서 취소)")

    def history(self, prompt_id: str) -> dict:
        resp = requests.get(f"{self.server}/history/{prompt_id}", timeout=30)
        resp.raise_for_status()
        entry = resp.json().get(prompt_id)
        if entry is None:
            raise RuntimeError(f"history 에 {prompt_id} 가 없음")
        return entry["outputs"]

    def download(self, info: dict) -> bytes:
        params = {"filename": info["filename"],
                  "subfolder": info.get("subfolder", ""),
                  "type": info.get("type", "output")}
        resp = requests.get(f"{self.server}/view", params=params, timeout=120)
        resp.raise_for_status()
        return resp.content

    # -- 한 방에 --------------------------------------------------------
    def run(self, workflow: dict, *, save_to: Path | None = None,
            output_title: str = "final_output") -> dict:
        """제출 → 대기 → 회수. save_to 를 주면 파일로 저장한다.

        반환: {"prompt_id", "filename", "path", "bytes"}
        """
        prompt_id = self.submit(workflow)
        self.monitor(workflow, prompt_id)
        outputs = self.history(prompt_id)

        info = get_output_image_info(workflow, outputs, output_title)
        blob = self.download(info)

        path = None
        if save_to is not None:
            save_to.parent.mkdir(parents=True, exist_ok=True)
            save_to.write_bytes(blob)
            path = save_to

        return {"prompt_id": prompt_id, "filename": info["filename"],
                "path": path, "bytes": blob}


def get_output_image_info(workflow: dict, outputs: dict,
                          title: str = "final_output") -> dict:
    """지정한 SaveImage 노드의 첫 이미지 정보.

    해당 제목이 없거나 이미지가 비어 있으면 아무 SaveImage 결과나 집어온다.
    """
    try:
        node_id = find_node_by_title(workflow, title)
        images = outputs.get(node_id, {}).get("images", [])
        if images:
            return images[0]
    except ValueError:
        pass

    for node_out in outputs.values():
        if node_out.get("images"):
            return node_out["images"][0]
    raise RuntimeError("출력 이미지를 찾을 수 없음")


# ---------------------------------------------------------------- 하위 호환

def generate_client_id() -> str:
    return str(uuid.uuid4())


def queue_prompt(workflow: dict, client_id: str | None = None) -> str:
    payload = {"prompt": workflow}
    if client_id:
        payload["client_id"] = client_id
    resp = requests.post(f"{SERVER}/prompt", json=payload, timeout=30)
    resp.raise_for_status()
    return resp.json()["prompt_id"]


def wait_for_result(prompt_id: str, timeout_s: int = 120) -> dict:
    """폴링 방식. 새 코드에서는 ComfyRunner 를 쓸 것."""
    for _ in range(max(1, timeout_s // 2)):
        history = requests.get(f"{SERVER}/history/{prompt_id}", timeout=30).json()
        if prompt_id in history:
            return history[prompt_id]["outputs"]
        time.sleep(2)
    raise TimeoutError("생성이 시간 내에 끝나지 않음")


def download_image(filename: str, subfolder: str = "", img_type: str = "output") -> bytes:
    params = {"filename": filename, "subfolder": subfolder, "type": img_type}
    resp = requests.get(f"{SERVER}/view", params=params, timeout=120)
    resp.raise_for_status()
    return resp.content
