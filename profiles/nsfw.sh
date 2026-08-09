# WAI-illustrious. 그림체 완성도는 높지만 미소녀/선정성 방향으로 프롬프트를 자주 덮어쓴다.
# ControlNet·업스케일러·태거는 anime 프로필과 같은 것을 쓴다(같이 지정하면 한 번만 받는다).

FILES+=(
  "$BASE/checkpoints|WAI-illustrious-SDXL.safetensors|https://civitai.red/api/download/models/2883731?fileId=2763986"
  "$BASE/upscale_models|4x-AnimeSharp.pth|https://huggingface.co/Kim2091/AnimeSharp/resolve/main/4x-AnimeSharp.pth"
  "$BASE/controlnet|Illustrious_openpose.safetensors|https://huggingface.co/windsingai/openpose/resolve/main/openpose_s6000.safetensors"
  "$BASE/controlnet|NoobAI_depth_midas.safetensors|https://huggingface.co/Eugeoter/noob-sdxl-controlnet-depth_midas-v1-1/resolve/main/diffusion_pytorch_model.fp16.safetensors"
  "$BASE/wd14_tagger|wd-swinv2-tagger-v3.onnx|https://huggingface.co/SmilingWolf/wd-swinv2-tagger-v3/resolve/main/model.onnx"
  "$BASE/wd14_tagger|wd-swinv2-tagger-v3.csv|https://huggingface.co/SmilingWolf/wd-swinv2-tagger-v3/resolve/main/selected_tags.csv"
)

HINT="$HINT
[nsfw] WAI-illustrious-SDXL / CFG 4~7 / steps 28~32 / Euler a
       ControlNet·업스케일러·태거는 anime 프로필과 동일.
       인물 비중을 줄이려면 full body / wide shot, 그리고
       looking at viewer 와 from below 를 네거티브에 넣는 게 효과가 크다.
"
