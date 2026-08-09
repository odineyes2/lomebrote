# 애니 (Illustrious 공식 베이스). 편향이 덜해 프롬프트 반응을 보기 좋다.
# 화풍은 밋밋한 편. 그림체 완성도가 필요하면 nsfw 프로필(WAI)과 비교할 것.

FILES+=(
  "$BASE/checkpoints|Illustrious-XL-v1.1.safetensors|https://huggingface.co/OnomaAIResearch/Illustrious-XL-v1.1/resolve/main/Illustrious-XL-v1.1.safetensors"
  "$BASE/upscale_models|4x-AnimeSharp.pth|https://huggingface.co/Kim2091/AnimeSharp/resolve/main/4x-AnimeSharp.pth"
  # 계열을 맞춰야 색이 안 탁해진다. 범용 SDXL(xinsir) 쓰지 말 것.
  "$BASE/controlnet|Illustrious_openpose.safetensors|https://huggingface.co/windsingai/openpose/resolve/main/openpose_s6000.safetensors"
  "$BASE/controlnet|NoobAI_depth_midas.safetensors|https://huggingface.co/Eugeoter/noob-sdxl-controlnet-depth_midas-v1-1/resolve/main/diffusion_pytorch_model.fp16.safetensors"
  # 태거는 .onnx/.csv 파일명이 모델명과 같아야 노드가 로컬 파일로 인식한다.
  "$BASE/wd14_tagger|wd-swinv2-tagger-v3.onnx|https://huggingface.co/SmilingWolf/wd-swinv2-tagger-v3/resolve/main/model.onnx"
  "$BASE/wd14_tagger|wd-swinv2-tagger-v3.csv|https://huggingface.co/SmilingWolf/wd-swinv2-tagger-v3/resolve/main/selected_tags.csv"
  "$BASE/controlnet|Illustrious_lineart_anime.safetensors|https://huggingface.co/Eugeoter/noob-sdxl-controlnet-lineart_anime/resolve/main/diffusion_pytorch_model.fp16.safetensors"
)

HINT="$HINT
[anime] Illustrious XL v1.1 / CFG 4~7 / steps 28~32 / Euler a
        ControlNet: Illustrious_openpose(end 0.4), NoobAI_depth_midas(end 0.8 근처)
        업스케일: 4x-AnimeSharp / 태거: wd-swinv2-tagger-v3
        LoRA 대부분은 v0.1 기반이라 강도가 약해질 수 있다. strength +0.2 정도로 보정.
"
