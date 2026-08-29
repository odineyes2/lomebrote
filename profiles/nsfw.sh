# WAI-illustrious. ControlNet·업스케일러·태거는 anime 과 동일.

SDXL=1

FILES+=(
  "$BASE/checkpoints|WAI-illustrious-SDXL.safetensors|https://civitai.red/api/download/models/2883731?fileId=2763986"
  "$BASE/upscale_models|4x-AnimeSharp.pth|https://huggingface.co/Kim2091/AnimeSharp/resolve/main/4x-AnimeSharp.pth"
  "$BASE/controlnet|Illustrious_openpose.safetensors|https://huggingface.co/windsingai/openpose/resolve/main/openpose_s6000.safetensors"
  "$BASE/controlnet|NoobAI_depth_midas.safetensors|https://huggingface.co/Eugeoter/noob-sdxl-controlnet-depth_midas-v1-1/resolve/main/diffusion_pytorch_model.fp16.safetensors"
  "$BASE/controlnet|Illustrious_lineart_anime.safetensors|https://huggingface.co/Eugeoter/noob-sdxl-controlnet-lineart_anime/resolve/main/diffusion_pytorch_model.fp16.safetensors"
  "$BASE/wd14_tagger|wd-swinv2-tagger-v3.onnx|https://huggingface.co/SmilingWolf/wd-swinv2-tagger-v3/resolve/main/model.onnx"
  "$BASE/wd14_tagger|wd-swinv2-tagger-v3.csv|https://huggingface.co/SmilingWolf/wd-swinv2-tagger-v3/resolve/main/selected_tags.csv"
  "$BASE/loras|IFL_v1.0_IL.safetensors|https://civitai.red/api/download/models/2211883?fileId=2104890"
  "$BASE/loras|Deep_Kiss_V3_ToTo-000007.safetensors|https://civitai.red/api/download/models/2314955?fileId=2208182"
  "$BASE/loras|fern-s1-illustriousxl-lora-nochekaiser.safetensors|https://civitai.red/api/download/models/1626406?fileId=1527192"
  "$BASE/loras|mating-press-from-side-v5-illustriousxl-lora-nochekaiser.safetensors|https://civitai.red/api/download/models/2739911?fileId=2626221"
)
