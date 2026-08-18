import json, random
from comfy_utils import load_workflow, set_seed, queue_prompt, wait_for_result,get_output_image_info

base_workflow = load_workflow()

results = []
for i in range(10):
    workflow = json.loads(json.dumps(base_workflow))  # 깊은 복사
    seed = random.randint(0, 2**32 - 1)
    workflow = set_seed(workflow, seed)

    prompt_id = queue_prompt(workflow)
    print(f"[{i+1}/10] 제출됨 (seed={seed}) → {prompt_id}")

    outputs = wait_for_result(prompt_id)
    
    img_info = get_output_image_info(workflow, outputs)
    filename = img_info["filename"]
    print(f"   완료: {filename}")
    results.append({"seed": seed, "filename": filename})

print("\n=== 10장 결과 ===")
for r in results:
    print(r)