# WAI-illustrious (SDXL / Illustrious 계열).
#
# 공용 도구(FaceDetailer·전처리기·태거·USDU 등)는 tools 프로필에서 함께 로드한다.
# 여기에는 SDXL 체크포인트에만 묶이는 노드·가중치(IPAdapter, XY Plot)를 둔다.

load_profile tools

NODE_REPOS+=(
  # 원저작자(LucianoCirino) 저장소는 관리 중단. jags111 포크가 유지판이다.
  "efficiency-nodes-comfyui|https://github.com/jags111/efficiency-nodes-comfyui.git|no"
  "ComfyUI_IPAdapter_plus|https://github.com/cubiq/ComfyUI_IPAdapter_plus.git|no"
)

FILES+=(
  # IPAdapter 가중치(약 4GB).
  # 파일명 규칙: 앞의 sdxl = 체크포인트 계열, 뒤의 vit-h = clip_vision 인코더(bigG 아님).
  # 원본이 model.safetensors 라 리네임 필수. Unified Loader 는 아래 이름과 글자 하나까지 같아야 인식한다.
  "$BASE/clip_vision|CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors|https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors"
  "$BASE/ipadapter|ip-adapter_sdxl_vit-h.safetensors|https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl_vit-h.safetensors"
  "$BASE/ipadapter|ip-adapter-plus_sdxl_vit-h.safetensors|https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors"

  # Checkpoint
  "$BASE/checkpoints|WAI-illustrious-SDXL.safetensors|https://civitai.red/api/download/models/2883731?fileId=2763986"
  
  # Upscale Model
  "$BASE/upscale_models|4x-AnimeSharp.pth|https://huggingface.co/Kim2091/AnimeSharp/resolve/main/4x-AnimeSharp.pth"
  "$BASE/upscale_models|4x_foolhardy_Remacri.safetensors|https://civitai.red/api/download/models/164821?fileId=2037845"

  # controlNet
  "$BASE/controlnet|Illustrious_openpose.safetensors|https://huggingface.co/windsingai/openpose/resolve/main/openpose_s6000.safetensors"
  "$BASE/controlnet|NoobAI_depth_midas.safetensors|https://huggingface.co/Eugeoter/noob-sdxl-controlnet-depth_midas-v1-1/resolve/main/diffusion_pytorch_model.fp16.safetensors"
  "$BASE/controlnet|Illustrious_lineart_anime.safetensors|https://huggingface.co/Eugeoter/noob-sdxl-controlnet-lineart_anime/resolve/main/diffusion_pytorch_model.fp16.safetensors"

  # General LoRA
  "$BASE/loras/illustrious|IFL_v1.0_IL.safetensors|https://civitai.red/api/download/models/2211883?fileId=2104890"
  "$BASE/loras/illustrious|DynamicPoseIL2att_alpha1.0_rank4_noxattn_900steps.safetensors|https://civitai.red/api/download/models/1607510?fileId=1507569"
  "$BASE/loras/illustrious|S1 Dramatic Lighting Illustrious_V2.safetensors|https://civitai.red/api/download/models/2209882?fileId=2102847"
  "$BASE/loras/illustrious|748cm_c_illu.safetensors|https://civitai.red/api/download/models/2367109?fileId=2257920"
  "$BASE/loras/illustrious|4kiak4ne.safetensors|https://civitai.red/api/download/models/1394295?fileId=1296714"
  "$BASE/loras/illustrious|StS-Illustrious-Detail-Slider-v1.0.safetensors|https://civitai.red/api/download/models/1122976?fileId=1027785"
  "$BASE/loras/illustrious|illustrious_noobai_epsilon_pred_1_best_quality_v1.safetensors|https://civitai.red/api/download/models/1094296?fileId=999328"
  "$BASE/loras/illustrious|Niji_Semi_realism_F_N_R_epoch_10.safetensors|https://civitai.red/api/download/models/2854725?fileId=2740836"
  "$BASE/loras/illustrious|ponyv6_noobE11_2_adamW-000017.safetensors|https://civitai.red/api/download/models/1240413?fileId=1145680"
  "$BASE/loras/illustrious|xmc_v0.3_noobai_cwhj.safetensors|https://civitai.red/api/download/models/1041204?fileId=946906"
  "$BASE/loras/illustrious|ATRex_style-12V2Rev.safetensors|https://civitai.red/api/download/models/1804885?fileId=1705538"
   
  # Character LoRA
  #"$BASE/loras/illustrious|SwordMaiden-IL-v2-08.safetensors|https://civitai.red/api/download/models/1759607?fileId=1660331"
  #"$BASE/loras/illustrious|Cow_Girl.safetensors|https://civitai.red/api/download/models/2294136?fileId=2185137"
  #"$BASE/loras/illustrious|Priestess.safetensors|https://civitai.red/api/download/models/2294142?fileId=2185148"
  #"$BASE/loras/illustrious|goblin_slayer.safetensors|https://civitai.red/api/download/models/1348156?fileId=1304455"
  #"$BASE/loras/illustrious|fern-s1-illustriousxl-lora-nochekaiser.safetensors|https://civitai.red/api/download/models/1626406?fileId=1527192"

   # NSFW Body Position
  #"$BASE/loras/illustrious|Deep_Kiss_V3_ToTo-000007.safetensors|https://civitai.red/api/download/models/2314955?fileId=2208182"
  #"$BASE/loras/illustrious|mating-press-from-side-v5-illustriousxl-lora-nochekaiser.safetensors|https://civitai.red/api/download/models/2739911?fileId=2626221"
  #"$BASE/loras/illustrious|mating-press-from-above-v4-illustriousxl-lora-nochekaiser.safetensors|https://civitai.red/api/download/models/2580089?fileId=2467294"
  #"$BASE/loras/illustrious|on-side-missionary-v9-illustriousxl-lora-nochekaiser.safetensors|https://civitai.red/api/download/models/3169975?fileId=3050405"  
  #"$BASE/loras/illustrious|xray.safetensors|https://civitai.red/api/download/models/1307519?fileId=1211680"
  #"$BASE/loras/illustrious|BallsDeep-Anima-V1F-Re.safetensors|https://civitai.red/api/download/models/2885588?fileId=2765348"

  # 
  "$BASE/loras/illustrious|CharacterDesignIllustrious_Concept-10V2.safetensors|https://civitai.red/api/download/models/1096293?fileId=1001272"
)
