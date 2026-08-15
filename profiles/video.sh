# Wan 2.2 — i2v. SDXL 아님, 독립 베이스 모델이다.
#
# 왜 2.2 인가: 2.2 가 마지막 오픈웨이트다(2025-07-28, Apache 2.0).
# 2.5 / 2.6 / 2.7 은 API 전용으로만 나왔고, 3.0(2026-08-06 베타)은 공식 모델 페이지가
# 오픈웨이트 여부에 명시적으로 "아니오"라고 답했다. 로컬은 2.2 에 고정이고,
# 커뮤니티 LoRA·파인튜닝도 전부 2.2 기준이다. 최신 버전을 찾다가 시간 버리지 말 것.
#
# 배선은 손으로 하지 않는다. ComfyUI 템플릿 패널 → Video → Wan2.2 에서 공식
# 워크플로를 로드하는 게 현재 표준 진입로다. 커스텀 노드 래퍼(Kijai WanVideoWrapper)는
# 저자 본인이 "네이티브에 없는 기능이 아니면 쓰지 말라"고 README 에 적어 뒀다.
#
# 모드:
#   VIDEO=5b   (기본) TI2V-5B. t2v/i2v 겸용 단일 파일. 24GB 에서 720p/24fps 여유.
#              시간압축 16x16x4 고압축 VAE 라 5B 만으로 두 작업을 다 한다.
#   VIDEO=14b  I2V-A14B fp8. MoE 라 high_noise / low_noise 두 파일을 다 받아
#              Load Diffusion Model 노드 2개에 각각 물린다. 모션 품질은 확실히 낫다.
#
# ⚠ VAE 가 모드별로 다르다. 바꿔 넣으면 디코딩이 깨진다.
#     5b  → wan2.2_vae.safetensors      (1.4GB)
#     14b → wan_2.1_vae.safetensors     (254MB, 2.2 와 호환되는 2.1 VAE)
#
# 볼륨 100GB 기준 (누계):
#   video(5b) 단독                     18GB
#   video(14b) 단독                    32GB
#   anime + qwen(fp8) + video(5b)      70GB   ← 권장 조합
#   anime + qwen(gguf) + video(14b)    78GB
#   anime + qwen(fp8) + video(14b)     83GB
#
# 다른 프로필과 같이 지정하면 자동으로 5b 로 내려간다.
# 강제 지정: VIDEO=14b ./setup.sh video

VIDEO_MODE="${VIDEO:-}"
if [ -z "$VIDEO_MODE" ]; then
  VIDEO_MODE=14b
  for _a in "$@"; do
    case "$_a" in anime|nsfw|real|retro|qwen|ltx) VIDEO_MODE=5b ;; esac
  done
fi

if [ "$VIDEO_MODE" = "5b" ]; then
  FILES+=(
    "$BASE/diffusion_models|wan2.2_ti2v_5B_fp16.safetensors|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors"
    "$BASE/vae|wan2.2_vae.safetensors|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors"
  )
else
  # MoE. high 가 구도·큰 모션, low 가 디테일을 맡는다. 하나만 받으면 워크플로가 안 돈다.
  FILES+=(
    "$BASE/diffusion_models|wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors"
    "$BASE/diffusion_models|wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors"
    "$BASE/vae|wan_2.1_vae.safetensors|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
    # 4-step 증류 LoRA. 20+ 스텝을 4 로 줄인다. 실습 반복에는 이게 있어야 견딘다.
    # high/low 각각에 짝을 맞춰 물릴 것. 섞으면 모션이 뭉갠다.
    "$BASE/loras|wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors"
    "$BASE/loras|wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors"
  )
fi

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
