# Smooth Mix Wan 2.2 14B (I2V)
#
# 'SmoothMixAnime' - Will make the video have the style of SmoothMix Illustrious/NoobAI/Illustrious2+NoobAI;
# 'SmoothMixRealism' - Will make the video have the style of SmoothMix Realism
#
# MoE. high 가 구도·큰 모션, low 가 디테일을 맡는다. 하나만 받으면 워크플로가 안 돈다.
FILES+=(
    "$BASE/diffusion_models|SmoothMix_I2V_High_v2.safetensors|https://civitai.red/api/download/models/2513182?fileId=2460270"
    "$BASE/diffusion_models|SmoothMix_I2V_Low_v2.safetensors|https://civitai.red/api/download/models/2513186?fileId=2460676"
    "$BASE/vae|wan_2.1_vae.safetensors|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"    
    "$BASE/loras|SmoothXXXAnimation_High.safetensors|https://civitai.red/api/download/models/2376136?fileId=2266910"
    "$BASE/loras|SmoothXXXAnimation_Low.safetensors|https://civitai.red/api/download/models/2376143?fileId=2266915"
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
