import requests, json

SERVER = "http://127.0.0.1:8188"

def queue_prompt(prompt_json: dict) -> str:
    resp = requests.post(f"{SERVER}/prompt", json={"prompt": prompt_json})
    resp.raise_for_status()
    return resp.json()["prompt_id"]

with open("workflow_api.json") as f:
    prompt = json.load(f)

prompt_id = queue_prompt(prompt)
print(prompt_id)