# Qwen-Image-Edit 2509. 지시문 기반 편집(각도·표정 변경, 다중 참조 합성).
#
# 다른 프로필과 성격이 다르다. SDXL이 아니고, 체크포인트 한 덩어리도 아니다.
# diffusion model / text encoder / VAE 를 각각 따로 로드한다.
# Load Checkpoint 노드로는 열리지 않는다 — 로더 3개를 손으로 연결할 것.
#
# 단독 실행 가능하다. 이 세 파일이면 편집 워크플로우는 자체 완결이고
# SDXL 체크포인트·ControlNet·IPAdapter 는 Qwen 자체엔 필요 없다.
#   ./setup.sh qwen           지시문 실험 단계. 볼륨을 Qwen 에 몰아준다 → fp8
#   ./setup.sh anime qwen     화풍 복원 왕복까지 갈 때 → GGUF
#
# 애니 프로필을 같이 쓰는 이유는 Qwen 의 요구사항이 아니라 실습 목표 때문이다.
# 편집 결과는 실사 쪽으로 끌려서 선이 뭉개진다. 그 컷을 그대로 캐릭터 시트에 넣으면
# 19번 시트 → 20번 LoRA 데이터셋이 화풍 섞인 채로 만들어진다.
# 즉 "단독으로는 안 돌아간다"가 아니라 "다음 단계에서 쓸 수 없다"에 가깝다.

# ── 정밀도 선택 ────────────────────────────────────
# 50GB 볼륨 기준:
#   qwen 단독 + fp8   = 공통 6 + 30 = 36GB   ← 24GB GPU 에 fp8 이 딱 맞는 조합
#   qwen 단독 + GGUF  = 공통 6 + 24 = 30GB
#   anime qwen + GGUF = 공통 6 + 15 + 24 = 45GB
#   anime qwen + fp8  = 51GB → 볼륨 초과. 그래서 같이 쓰면 자동으로 GGUF 로 내린다.
#
# 강제 지정: QWEN=fp8 ./setup.sh qwen   /   QWEN=gguf ./setup.sh qwen
QWEN_MODE="${QWEN:-}"
if [ -z "$QWEN_MODE" ]; then
  QWEN_MODE=fp8
  for _a in "$@"; do
    case "$_a" in anime|nsfw|real) QWEN_MODE=gguf ;; esac
  done
fi

if [ "$QWEN_MODE" = "fp8" ]; then
  # 원본 fp8, 20.4GB. 24GB GPU 권장. 16GB 로컬에서는 램으로 밀려 많이 느리다.
  FILES+=(
    "$BASE/diffusion_models|qwen_image_edit_2509_fp8_e4m3fn.safetensors|https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors"
  )
else
  # Q5_K_M, 14.9GB. 로컬 16GB 와 RunPod 24GB 를 파일 하나로 커버한다.
  # Q2~Q4 는 출력에 아티팩트가 보고돼 있어 쓰지 않는다. 24GB 전용이면 Q8_0(21.8GB).
  FILES+=(
    "$BASE/unet|Qwen-Image-Edit-2509-Q5_K_M.gguf|https://huggingface.co/QuantStack/Qwen-Image-Edit-2509-GGUF/resolve/main/Qwen-Image-Edit-2509-Q5_K_M.gguf"
  )
fi

# 정밀도와 무관하게 공유되는 두 파일. fp8 <-> GGUF 를 오가도 다시 받지 않는다.
FILES+=(
  "$BASE/text_encoders|qwen_2.5_vl_7b_fp8_scaled.safetensors|https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"
  "$BASE/vae|qwen_image_vae.safetensors|https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"

  # Lightning 4-step LoRA. GGUF 와 함께 쓰면 잔상이 생긴다는 보고가 있어 기본은 받지 않는다.
  # 배치로 30~40장 뽑는 단계에서 속도가 문제되면 그때 켤 것.
  # "$BASE/loras|Qwen-Image-Lightning-4steps-V2.0.safetensors|https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Lightning-4steps-V2.0.safetensors"
)

# GGUF 로더. 이 줄이 먹히려면 setup.sh 에서 NODE_REPOS 선언이 프로필 source 보다 위에 있어야 한다.
# fp8 모드에서도 같이 설치한다 — 노드 하나뿐이고, 나중에 GGUF 로 내려갈 때 재실행이 줄어든다.
NODE_REPOS+=(
  "ComfyUI-GGUF|https://github.com/city96/ComfyUI-GGUF.git|no"
)

if [ "$QWEN_MODE" = "fp8" ]; then
  QWEN_LOADER="Load Diffusion Model ← qwen_image_edit_2509_fp8_e4m3fn"
else
  QWEN_LOADER="Unet Loader (GGUF)   ← Qwen-Image-Edit-2509-Q5_K_M.gguf"
fi

HINT="$HINT
[qwen] Qwen-Image-Edit 2509 ($QWEN_MODE) — SDXL 아님. Load Checkpoint 쓰지 말 것.
       노드 3개를 따로 연결한다:
         $QWEN_LOADER
         CLIPLoader           ← qwen_2.5_vl_7b_fp8_scaled, type: qwen_image
         Load VAE             ← qwen_image_vae
       프롬프트 노드는 TextEncodeQwenImageEditPlus (2509 전용, 참조 이미지 3장까지).
       구버전 TextEncodeQwenImageEdit 를 쓰면 다중 참조가 안 붙는다.

       CFG 2.5~4 / steps 20~30 / euler + simple 부터.
       지시문은 영어 평서문. booru 태그와 quality 태그는 여기서 효과 없다.
         각도  turn the character to a 3/4 side view, keep the same face and outfit
         표정  change her expression to a faint smile, keep everything else unchanged
         합성  place the person from image 1 into the background of image 2
       '나머지는 그대로'를 매번 명시하는 게 아이덴티티 유지에 제일 크게 먹힌다.

       정밀도를 바꿔 재실행했다면 안 쓰는 쪽을 지울 것. 둘 다 남기면 35GB 가 논다.
         rm $BASE/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors
         rm $BASE/unet/Qwen-Image-Edit-2509-Q5_K_M.gguf
"

# 애니 계열 프로필이 같이 지정된 경우에만 왕복 안내를 붙인다.
case " $* " in
  *" anime "*|*" nsfw "*)
    HINT="$HINT       화풍 복원 왕복:
         qwen 편집 결과 → Illustrious_lineart_anime ControlNet + img2img(denoise 0.35~0.5)
         → wai / Illustrious 로 통과 → 원본과 나란히 비교
"
    ;;
  *)
    HINT="$HINT       지금은 qwen 단독이다. 화풍 복원이 필요해지면 anime 또는 nsfw 를 같이 지정할 것.
"
    ;;
esac
