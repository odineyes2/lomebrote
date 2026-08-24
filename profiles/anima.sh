# Anima — t2i. SDXL 아님, CircleStone Labs / Comfy Org 의 20억 파라미터 독립 베이스(Cosmos-Predict2-2B 파인튜닝).
# 애니메이션·비사실적 일러스트 특화. 사실적 렌더링은 범위 밖.
#
# 2026-01 Preview 공개 → 02-04 Comfy Org 의 $1M "Open AI" Grant 1호 지원 모델로 발표
# → 05-15 Anima-Base 정식 릴리스. ComfyUI 코어 네이티브 지원은 v0.11.1 부터
# (zimage omni 와 같은 릴리스에 묶여 들어갔다. 그 아래 버전은 노드 자체가 없다).
# 이후 Aesthetic v1.0 → v1.0b → v1.1(현재 최신, 약 1개월 전), Turbo LoRA v0.1 → v0.2 로
# 이어지는 중이라 SDXL/Illustrious 계열처럼 체크포인트가 굳어진 상태는 아니다.
# 커뮤니티는 실습용으로 Turbo, 결과물 품질 위주면 Aesthetic 최신판(v1.1)을 쓰는 쪽으로 수렴해 있고,
# Base 단독은 거의 LoRA 학습용으로만 쓴다.
#
# 배선은 손으로 하지 않는다. 템플릿 패널에서 "Anima" 검색해 공식 워크플로(Subgraph 구성)를
# 로드하는 게 표준 진입로다. 템플릿에서 안 보이면 ComfyUI 버전이 낮은 것이다(위 v0.11.1 참고).
#
# ⚠ "Turbo" 는 독립 체크포인트가 아니라 Base 위에 얹는 공식 LoRA다.
#   서드파티가 base+lora 를 미리 합쳐 놓은 GGUF/AIO 배포본이 몇 개 돌아다니는데(HF 검색 시 나옴),
#   이 프로필은 공식 조합(Base + 공식 Turbo LoRA)만 받는다.
#
# ⚠ 세 파일이 다 있어야 한다(모드 공통 diffusion 모델 제외). 하나라도 빠지면 로더 드롭다운이 빈다.
#     diffusion_models/anima-*.safetensors
#     text_encoders/qwen_3_06b_base.safetensors
#     vae/qwen_image_vae.safetensors            ← Qwen-Image 와 동일 파일. krea/qwen 프로필과 겹치면
#                                                   setup.sh 가 이미 있는 걸 보고 다시 받지 않는다.
#
# ⚠ 라이선스: CircleStone Labs Non-Commercial License. Apache 2.0(Wan 2.2) 도
#   Krea 2 Community License 도 아니다. 모델 본체·파생 체크포인트·LoRA 는 전부 비상업 전용이고
#   예외 매출 구간이 없다(Krea 2 처럼 "연매출 100만불 미만이면 상업 허용" 같은 조항이 없음).
#   다만 "생성된 이미지 자체"는 상업적으로 써도 된다고 모델 카드에 명시돼 있다.
#   Cosmos-Predict2-2B 의 파생 모델이라 NVIDIA Open Model License Agreement 도 겹쳐 걸린다.
#   모델/LoRA 를 재배포하거나 파인튜닝해서 팔 계획이면 원문을 읽을 것.
#   https://huggingface.co/circlestone-labs/Anima/blob/main/LICENSE.md
#
# 모드:
#   ANIMA=aesthetic (기본) Aesthetic v1.1. 별도 LoRA 없이 그 자체로 고품질 기본값.
#                          30-50 스텝, CFG 4-5(더 내려서 3 근처도 잘 받는다).
#                          score_* 태그는 쓰지 말 것 — 이미 튜닝돼 있어서 오히려 과하게 밀린다.
#   ANIMA=turbo            Base + 공식 Turbo LoRA(v0.2). 8-12 스텝, CFG 1, sampler=euler 권장.
#                          Aesthetic 대비 품질은 근소하게 낮지만 반복 실습엔 이쪽이 견딘다.
#   ANIMA=base             Base v1.0 단독. LoRA 학습은 반드시 이 버전 기준으로.
#
# 프롬프트: Danbooru 태그 + 자연어 혼용 가능(Qwen-3 텍스트 인코더라 문장으로 써도 읽는다).
#   기본 포지티브: masterpiece, best quality, score_7, safe,  (Aesthetic 은 score_* 빼는 게 낫다)
#   가중치 문법은 통하되 SDXL 보다 세게 줘야 체감된다: (chibi:2) 정도.
#
# 볼륨 (모드별 단독, 텍스트 인코더 1.14GB + VAE 0.24GB 포함):
#   anima(aesthetic) 단독                     5.6GB
#   anima(turbo) 단독                         5.7GB   ← base(4.18) + turbo lora(0.15) + enc/vae
#   anima(base) 단독                          5.6GB
#   krea 또는 qwen 프로필과 같이 쓰면 VAE 0.24GB 는 중복으로 받지 않는다(파일명 동일, 경로도 동일).
#
# 강제 지정: ANIMA=turbo ./setup.sh anima
# LoRA 학습용 베이스만: ANIMA=base ./setup.sh anima

ANIMA_MODE="${ANIMA:-aesthetic}"
ANIMA_REPO="https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files"
ANIMA_LORA_REPO="https://huggingface.co/circlestone-labs/Anima-Official-LoRAs/resolve/main"

case "$ANIMA_MODE" in
  turbo)
    FILES+=(
      "$BASE/diffusion_models|anima-base-v1.0.safetensors|$ANIMA_REPO/diffusion_models/anima-base-v1.0.safetensors"
      # v0.1 은 Preview3 기준 학습이라 v1.0 에서는 품질이 오히려 떨어진다. 반드시 v0.2.
      "$BASE/loras|anima-turbo-lora-v0.2.safetensors|$ANIMA_LORA_REPO/anima-turbo-lora-v0.2.safetensors"
    )
    ;;
  base)
    FILES+=(
      "$BASE/diffusion_models|anima-base-v1.0.safetensors|$ANIMA_REPO/diffusion_models/anima-base-v1.0.safetensors"
    )
    ;;
  *)
    FILES+=(
      "$BASE/diffusion_models|anima-aesthetic-v1.1.safetensors|$ANIMA_REPO/diffusion_models/anima-aesthetic-v1.1.safetensors"
    )
    ;;
esac

# 모드와 무관하게 공유. 모드를 바꿔도 다시 받지 않는다.
FILES+=(
  # Qwen-3 0.6B. T5 도 CLIP 도 아니라서 (word:1.5) 류의 CLIP 전용 강조 문법이 그대로는 안 통한다.
  "$BASE/text_encoders|qwen_3_06b_base.safetensors|$ANIMA_REPO/text_encoders/qwen_3_06b_base.safetensors"
  # Qwen-Image 와 동일 VAE. krea/qwen 프로필과 파일명이 같아 중복 다운로드는 안 일어난다.
  "$BASE/vae|qwen_image_vae.safetensors|$ANIMA_REPO/vae/qwen_image_vae.safetensors"
)

# 커스텀 노드는 넣지 않는다. UNETLoader/CLIPLoader/VAELoader 코어 노드만으로 돈다.
# ControlNet 격인 "Anima LLLite" 가중치가 커뮤니티에 돌아다니지만 아직 core 지원이 갓 들어간
# 실험 단계라(AnimaLLLiteApply 노드) 이 프로필에서는 받지 않는다. 필요해지면 그때 따로 추가.
#
# ※ 템플릿에서 "Anima" 가 아예 안 보이면 ComfyUI 버전 문제다. setup.sh 실행 로그의
#   "ComfyUI: ..." 줄에서 태그/날짜를 확인하고, v0.11.1 미만이면 $COMFY 에서 git pull 후 재기동.
