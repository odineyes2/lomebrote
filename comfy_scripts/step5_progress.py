import json
from comfy_utils import load_workflow, generate_client_id, queue_prompt, SERVER
import websocket  # pip install websocket-client (requirements.txt에 이미 있음)

client_id = generate_client_id()
ws = websocket.WebSocket()
ws.connect(f"ws://127.0.0.1:8188/ws?clientId={client_id}")

workflow = load_workflow()
prompt_id = queue_prompt(workflow, client_id=client_id)
print("제출됨:", prompt_id)

while True:
    raw = ws.recv()
    if not isinstance(raw, str):
        continue  # 미리보기 이미지 바이너리는 지금 단계에서 무시

    message = json.loads(raw)
    msg_type = message.get("type")
    data = message.get("data", {})

    if msg_type == "progress":
        print(f"  진행률: {data['value']}/{data['max']}")

    elif msg_type == "executing":
        if data.get("prompt_id") != prompt_id:
            continue  # 다른 작업의 메시지는 무시
        node = data.get("node")
        if node is None:
            print("생성 완료!")
            break
        print(f"현재 실행 중인 노드: {node}")

ws.close()