# Qwen-Image-Edit 2511. SDXL 아님 — 로더 3개를 손으로 연결한다. 배선은 docs/qwen.md.
# 단독 실행 가능. anime/nsfw/retro 를 같이 지정하는 건 Qwen 의 요구사항이 아니라
# LoRA 부트스트랩 때문이다.
#
# 볼륨 100GB 기준 (50GB 시절 계산은 폐기):
#   qwen + fp8                       37GB   ← 24GB GPU 에 맞는 조합
#   qwen + GGUF                      32GB
#   anime qwen + fp8                 52GB
#   anime qwen(fp8) + video(5b)      70GB   ← 권장 조합
#   anime qwen(fp8) + video(14b)     83GB
#
# 볼륨이 100GB 로 늘어서 anime + fp8 조합이 이제 들어간다. 예전엔 52GB 라
# 초과였기 때문에 같이 쓰면 자동으로 GGUF 로 내렸는데, 그 강등은 이제 필요 없다.
# 다만 video(14b) 나 ltx 를 같이 물리면 다시 빠듯해지므로 그때만 GGUF 로 내린다.
#
# 강제 지정: QWEN=fp8|gguf ./setup.sh qwen

QWEN_MODE="${QWEN:-}"
if [ -z "$QWEN_MODE" ]; then
  QWEN_MODE=fp8
  for _a in "$@"; do
    case "$_a" in ltx) QWEN_MODE=gguf ;; esac
  done
  # video 는 14b 일 때만 무겁다. 5b(기본)면 fp8 을 유지해도 된다.
  case " $* " in
    *" video "*) [ "${VIDEO:-}" = "14b" ] && QWEN_MODE=gguf ;;
  esac
fi

if [ "$QWEN_MODE" = "fp8" ]; then
  # 2511 의 fp8 은 fp8mixed 하나뿐. 민감한 레이어를 고정밀로 남기는 혼합 양자화. 20.5GB.
  FILES+=(
    "$BASE/diffusion_models|qwen_image_edit_2511_fp8mixed.safetensors|https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors"
  )
else
  # Q5_K_M, 15GB. 로컬 16GB 와 RunPod 24GB 를 파일 하나로 커버.
  # Q2~Q4 는 출력 아티팩트가 보고돼 있어 쓰지 않는다. 볼륨이 남으면 Q6_K(16.9GB).
  FILES+=(
    "$BASE/unet|qwen-image-edit-2511-Q5_K_M.gguf|https://huggingface.co/unsloth/Qwen-Image-Edit-2511-GGUF/resolve/main/qwen-image-edit-2511-Q5_K_M.gguf"
  )
fi

# 정밀도와 무관하게 공유. fp8 <-> GGUF 를 오가도 다시 받지 않는다.
FILES+=(
  "$BASE/text_encoders|qwen_2.5_vl_7b_fp8_scaled.safetensors|https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"
  "$BASE/vae|qwen_image_vae.safetensors|https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"
  # 2509용 V2.0 과 다른 파일이다. 반드시 2511 전용을 쓸 것.
  "$BASE/loras|Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors|https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"
  "$BASE/loras|qwen-image-edit-2511-multiple-angles-lora.safetensors|https://huggingface.co/fal/Qwen-Image-Edit-2511-Multiple-Angles-LoRA/resolve/main/qwen-image-edit-2511-multiple-angles-lora.safetensors"
)

# fp8 모드에서도 설치한다 — 노드 하나뿐이고 나중에 GGUF 로 내려갈 때 재실행이 줄어든다.
NODE_REPOS+=(
  "ComfyUI-GGUF|https://github.com/city96/ComfyUI-GGUF.git|no"
)
