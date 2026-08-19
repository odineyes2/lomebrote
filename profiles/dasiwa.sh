# dasiwa
#
# 
# 
#
# MoE. high 가 구도·큰 모션, low 가 디테일을 맡는다. 하나만 받으면 워크플로가 안 돈다.
FILES+=(
    "$BASE/diffusion_models|Wan2_2-I2V-High-DaSiWa-TastySin-q8.gguf.safetensors|https://civitai.red/api/download/models/2466604?fileId=2355406"
    "$BASE/diffusion_models|Wan2_2-I2V-Low-DaSiWa-TastySin-q8.gguf.safetensors|https://civitai.red/api/download/models/2466822?fileId=2355529"
    "$BASE/vae|wan_2.1_vae.safetensors|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
# WAN General NSFW model
    "$BASE/loras|NSFW-22-H-e8.safetensors|https://civitai.red/api/download/models/2073605?fileId=1969798"
    "$BASE/loras|bounce_test_HighNoise-000005.safetensors|https://civitai.red/api/download/models/2209354?fileId=2102358"
    "$BASE/loras|bounce_test_LowNoise-000005.safetensors|https://civitai.red/api/download/models/2209344?fileId=2102313"
    "$BASE/loras|DR34ML4Y_I2V_14B_HIGH_V2.safetensors|https://civitai.red/api/download/models/2553151?fileId=2441563"
    "$BASE/loras|DR34ML4Y_I2V_14B_LOW_V2.safetensors|https://civitai.red/api/download/models/2303113?fileId=2194029"    
)

# 텍스트 인코더는 두 모드 공유. 2.1 저장소에 있다(2.2 리포에 중복 배치 안 함). 약 6.7GB.
FILES+=(
  "$BASE/text_encoders|umt5_xxl_fp8_e4m3fn_scaled.safetensors|https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
)

# mp4 저장 자체는 코어 SaveVideo 노드로 된다(VHS_VideoCombine 필요 없음).
# VideoHelperSuite 는 영상 "로드"와 프레임 시퀀스 조작 때문에 넣는다.
# 실사 영상에서 포즈를 뽑는 절차(본문 5번)에 Load Video 가 필요하다.
NODE_REPOS+=(
  "ComfyUI-VideoHelperSuite|https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git|no"
)
