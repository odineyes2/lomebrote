import json, sys
from comfy_utils import load_workflow, generate_client_id, queue_prompt, SERVER, get_node_title, print_progress_bar
import websocket
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--workflow", default="workflow_api.json", help="사용할 워크플로우 API JSON 파일명")
args = parser.parse_args()

workflow = load_workflow(args.workflow)

client_id = generate_client_id()
ws = websocket.WebSocket()
ws.connect(f"ws://127.0.0.1:8188/ws?clientId={client_id}")

# workflow = load_workflow()
prompt_id = queue_prompt(workflow, client_id=client_id)
print(f"제출됨: {prompt_id}\n")

current_node_title = None

while True:
    raw = ws.recv()
    if not isinstance(raw, str):
        continue

    message = json.loads(raw)
    msg_type = message.get("type")
    data = message.get("data", {})

    if msg_type == "progress":
        print_progress_bar(current_node_title or "실행 중", data["value"], data["max"])

    elif msg_type == "executing":
        if data.get("prompt_id") != prompt_id:
            continue
        node = data.get("node")
        if node is None:
            print("\n\n생성 완료!")
            break
        current_node_title = get_node_title(workflow, node)
        print(f"\n▶ {current_node_title} (노드 {node}) 시작")

ws.close()