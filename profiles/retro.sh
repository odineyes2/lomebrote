# Retrordinary (Illustrious 계열). ControlNet·업스케일러·태거는 anime 과 동일.
#
# civitai.com 직링크는 b2.civitai.com 으로 리다이렉트되면 403 이 난다(civitai #2113).
# R2 로 배정되면 되고 B2 면 안 되는데 어느 쪽일지는 서버가 정한다. 재시도로는 못 뚫는다.
# 그래서 nsfw 와 같이 civitai.red 미러를 쓴다. 미러는 토큰이 필요 없다.

SDXL=1

FILES+=(
  "$BASE/checkpoints|TC-RetrordinaryFinalVAELiq.safetensors|https://civitai.red/api/download/models/3113078?fileId=3010428"
  "$BASE/upscale_models|4x-AnimeSharp.pth|https://huggingface.co/Kim2091/AnimeSharp/resolve/main/4x-AnimeSharp.pth"
  "$BASE/controlnet|Illustrious_openpose.safetensors|https://huggingface.co/windsingai/openpose/resolve/main/openpose_s6000.safetensors"
  "$BASE/controlnet|NoobAI_depth_midas.safetensors|https://huggingface.co/Eugeoter/noob-sdxl-controlnet-depth_midas-v1-1/resolve/main/diffusion_pytorch_model.fp16.safetensors"
  "$BASE/controlnet|Illustrious_lineart_anime.safetensors|https://huggingface.co/Eugeoter/noob-sdxl-controlnet-lineart_anime/resolve/main/diffusion_pytorch_model.fp16.safetensors"
  "$BASE/wd14_tagger|wd-swinv2-tagger-v3.onnx|https://huggingface.co/SmilingWolf/wd-swinv2-tagger-v3/resolve/main/model.onnx"
  "$BASE/wd14_tagger|wd-swinv2-tagger-v3.csv|https://huggingface.co/SmilingWolf/wd-swinv2-tagger-v3/resolve/main/selected_tags.csv"
)
