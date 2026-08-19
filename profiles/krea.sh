# Krea 2 — t2i. 
#
# 배선은 손으로 하지 않는다. 템플릿 패널에서 "Krea-2" 를 검색해 공식 워크플로를 로드하는 게
# 표준 진입로다. 서브그래프로 묶여 있어서 노드를 펼칠 일도 거의 없다.
#
# ⚠ 파일명. 공식 파일은 krea2_turbo_fp8_scaled.safetensors 다.
#
# ⚠ 세 파일이 다 있어야 한다. 하나라도 빠지면 드롭다운이 빈 채로 뜬다.
#     diffusion_models/krea2_*.safetensors
#     text_encoders/qwen3vl_4b_fp8_scaled.safetensors   ← CLIPLoader 의 type 을 krea2 로
#     vae/qwen_image_vae.safetensors
#
#   KREA=turbo (기본) 증류판. 8스텝, CFG 1.0. 실습 반복은 이걸로.
#                     CFG 를 2.0 위로 올리면 색이 떠서 납작해진다. 올리는 값이 아니다.
#   KREA=int8         turbo 의 int8_convrot 변형. 공식 "Style Reference" 템플릿이
#                     이 파일을 지정한다. 스타일 레퍼런스 LoRA 도 같이 받는다.
#   KREA=raw          베이스. 52스텝, CFG 3.5. 느리지만 LoRA 를 학습시키는 쪽은 이것이다.
#                     RAW 로 학습한 LoRA 는 Turbo 에 그대로 얹힌다(공식 권장 경로).
#
# 볼륨 100GB 기준 (누계):
#   krea 단독                                19GB
#
# 강제 지정: KREA=raw ./setup.sh krea
# 스타일 LoRA 9종까지: KREA_LORAS=1 ./setup.sh krea

KREA_MODE="${KREA:-turbo}"

# Comfy-Org 미러는 게이트가 아니다. 401 이 나면 원본(krea/Krea-2-Turbo) 약관 동의가
# 미러에도 걸린 것이므로 그때만 HF_TOKEN 을 붙인다.
KREA_REPO="https://huggingface.co/Comfy-Org/Krea-2/resolve/main"

case "$KREA_MODE" in
  int8)
    FILES+=(
      "$BASE/diffusion_models|krea2_turbo_int8_convrot.safetensors|$KREA_REPO/diffusion_models/krea2_turbo_int8_convrot.safetensors"
      # 스타일 레퍼런스 템플릿 전용. 이 LoRA 없이 참조 이미지를 물리면 그냥 무시된다.
      "$BASE/loras|krea2_style_reference.safetensors|$KREA_REPO/loras/krea2_style_reference.safetensors"
    )
    ;;
  raw)
    FILES+=(
      "$BASE/diffusion_models|krea2_raw_fp8_scaled.safetensors|$KREA_REPO/diffusion_models/krea2_raw_fp8_scaled.safetensors"
      # raw 에 얹으면 8스텝 스케줄로 내려온다. 학습은 raw 로, 확인 렌더는 이걸 물려서.
      "$BASE/loras|krea2_turbo_lora_rank_64_bf16.safetensors|$KREA_REPO/loras/krea2_turbo_lora_rank_64_bf16.safetensors"
    )
    ;;
  *)
    FILES+=(
      "$BASE/diffusion_models|krea2_turbo_fp8_scaled.safetensors|$KREA_REPO/diffusion_models/krea2_turbo_fp8_scaled.safetensors"
    )
    ;;
esac

# 모드와 무관하게 공유. turbo <-> raw 를 오가도 다시 받지 않는다.
FILES+=(  
  "$BASE/text_encoders|qwen3vl_4b_fp8_scaled.safetensors|$KREA_REPO/text_encoders/qwen3vl_4b_fp8_scaled.safetensors"  
  "$BASE/vae|qwen_image_vae.safetensors|$KREA_REPO/vae/qwen_image_vae.safetensors"
  "$BASE/loras|Krea2MythD4rkL1nes.safetensors|https://civitai.com/api/download/models/3165227?fileId=3045636"
  "$BASE/loras|Niji_Sweet_Spot_Krea2_v2A.safetensors|https://civitai.com/api/download/models/3210573?fileId=3092284"
)

# 공식 스타일 LoRA 9종. 각각 트리거 워드를 프롬프트 맨 앞에 넣어야 걸린다(강도 1.0 기준).
#   darkbrush      monochrome ink wash style
#   dotmatrix      monochrome stippling style
#   kidsdrawing    naive expressive sketch style
#   neondrip       textured abstract style
#   rainywindow    rainy window style
#   retroanime     purple retro anime style
#   softwatercolor art deco watercolor style
#   sunsetblur     ethereal motion blur style
#   vintagetarot   vintage tarot style
if [ -n "${KREA_LORAS:-}" ]; then
  for _l in darkbrush dotmatrix kidsdrawing neondrip rainywindow \
            retroanime softwatercolor sunsetblur vintagetarot; do
    FILES+=("$BASE/loras|krea2_${_l}.safetensors|$KREA_REPO/loras/krea2_${_l}.safetensors")
  done
fi

