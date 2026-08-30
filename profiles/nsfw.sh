# WAI-illustrious. ControlNet·업스케일러·태거는 anime 과 동일.

SDXL=1

FILES+=(
  # Checkpoint
  "$BASE/checkpoints|WAI-illustrious-SDXL.safetensors|https://civitai.red/api/download/models/2883731?fileId=2763986"
  
  # Upscale Model
  "$BASE/upscale_models|4x-AnimeSharp.pth|https://huggingface.co/Kim2091/AnimeSharp/resolve/main/4x-AnimeSharp.pth"
  "$BASE/upscale_models|4x_foolhardy_Remacri.safetensors|https://civitai.red/api/download/models/164821?fileId=2037845"

  # controlNet
  "$BASE/controlnet|Illustrious_openpose.safetensors|https://huggingface.co/windsingai/openpose/resolve/main/openpose_s6000.safetensors"
  "$BASE/controlnet|NoobAI_depth_midas.safetensors|https://huggingface.co/Eugeoter/noob-sdxl-controlnet-depth_midas-v1-1/resolve/main/diffusion_pytorch_model.fp16.safetensors"
  "$BASE/controlnet|Illustrious_lineart_anime.safetensors|https://huggingface.co/Eugeoter/noob-sdxl-controlnet-lineart_anime/resolve/main/diffusion_pytorch_model.fp16.safetensors"
  "$BASE/wd14_tagger|wd-swinv2-tagger-v3.onnx|https://huggingface.co/SmilingWolf/wd-swinv2-tagger-v3/resolve/main/model.onnx"
  "$BASE/wd14_tagger|wd-swinv2-tagger-v3.csv|https://huggingface.co/SmilingWolf/wd-swinv2-tagger-v3/resolve/main/selected_tags.csv"

  # General LoRA
  "$BASE/loras|IFL_v1.0_IL.safetensors|https://civitai.red/api/download/models/2211883?fileId=2104890"
  "$BASE/loras|DynamicPoseIL2att_alpha1.0_rank4_noxattn_900steps.safetensors|https://civitai.red/api/download/models/1607510?fileId=1507569"
  "$BASE/loras|S1 Dramatic Lighting Illustrious_V2.safetensors|https://civitai.red/api/download/models/2209882?fileId=2102847"
  "$BASE/loras|748cm_c_illu.safetensors|https://civitai.red/api/download/models/2367109?fileId=2257920"
  "$BASE/loras|4kiak4ne.safetensors|https://civitai.red/api/download/models/1394295?fileId=1296714"
  "$BASE/loras|StS-Illustrious-Detail-Slider-v1.0.safetensors|https://civitai.red/api/download/models/1122976?fileId=1027785"
  "$BASE/loras|illustrious_noobai_epsilon_pred_1_best_quality_v1.safetensors|https://civitai.red/api/download/models/1094296?fileId=999328"
  "$BASE/loras|Niji_Semi_realism_F_N_R_epoch_10.safetensors|https://civitai.red/api/download/models/2854725?fileId=2740836"
  "$BASE/loras|ponyv6_noobE11_2_adamW-000017.safetensors|https://civitai.red/api/download/models/1240413?fileId=1145680"
  "$BASE/loras|xmc_v0.3_noobai_cwhj.safetensors|https://civitai.red/api/download/models/1041204?fileId=946906"
   
  # Character LoRA
  "$BASE/loras|fern-s1-illustriousxl-lora-nochekaiser.safetensors|https://civitai.red/api/download/models/1626406?fileId=1527192"

   # NSFW Body Position
  "$BASE/loras|Deep_Kiss_V3_ToTo-000007.safetensors|https://civitai.red/api/download/models/2314955?fileId=2208182"
  "$BASE/loras|mating-press-from-side-v5-illustriousxl-lora-nochekaiser.safetensors|https://civitai.red/api/download/models/2739911?fileId=2626221"
  "$BASE/loras|mating-press-from-above-v4-illustriousxl-lora-nochekaiser.safetensors|https://civitai.red/api/download/models/2580089?fileId=2467294"
  "$BASE/loras|on-side-missionary-v9-illustriousxl-lora-nochekaiser.safetensors|https://civitai.red/api/download/models/3169975?fileId=3050405"
  "$BASE/loras|ATRex_style-12V2Rev.safetensors|https://civitai.red/api/download/models/1804885?fileId=1705538"
  "$BASE/loras|xray.safetensors|https://civitai.red/api/download/models/1307519?fileId=1211680"
  "$BASE/loras|BallsDeep-Anima-V1F-Re.safetensors|https://civitai.red/api/download/models/2885588?fileId=2765348"
)
