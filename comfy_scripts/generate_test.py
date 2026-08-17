import requests, time

SERVER = "http://127.0.0.1:8188"
prompt_id = "f6bc8c11-6ce9-4787-9948-6ca80fe8d5be"

for _ in range(30):  # 최대 30번, 2초 간격 = 1분 대기
    resp = requests.get(f"{SERVER}/history/{prompt_id}")
    history = resp.json()
    if prompt_id in history:
        print("완료!")
        outputs = history[prompt_id]["outputs"]
        print(outputs)
        break
    time.sleep(2)
else:
    print("1분 내에 안 끝남 — 아직 큐에서 돌고 있을 수 있음")