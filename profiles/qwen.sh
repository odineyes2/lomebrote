# Qwen-Image-Edit 2511. SDXL 아님 — 로더 3개를 손으로 연결한다. 배선은 docs/qwen.md.
# 단독 실행 가능. anime/nsfw/retro 를 같이 지정하는 건 Qwen 의 요구사항이 아니라
# LoRA 부트스트랩 때문이다.
#
# 볼륨 50GB 기준:
#   qwen + fp8        37GB   ← 24GB GPU 에 맞는 조합
#   qwen + GGUF       32GB
#   anime qwen + GGUF 47GB
#   anime qwen + fp8  52GB → 초과. 그래서 같이 쓰면 자동으로 GGUF.
#
# 강제 지정: QWEN=fp8|gguf ./setup.sh qwen

QWEN_MODE="${QWEN:-}"
if [ -z "$QWEN_MODE" ]; then
  QWEN_MODE=fp8
  for _a in "$@"; do
    case "$_a" in anime|nsfw|real|retro) QWEN_MODE=gguf ;; esac
  done
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
