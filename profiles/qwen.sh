# Qwen-Image-Edit 2511. 지시문 기반 편집(각도·표정·포즈 변경, 다중 참조 합성).
#
# 다른 프로필과 성격이 다르다. SDXL이 아니고, 체크포인트 한 덩어리도 아니다.
# diffusion model / text encoder / VAE 를 각각 따로 로드한다.
# Load Checkpoint 노드로는 열리지 않는다 — 로더 3개를 손으로 연결할 것.
#
# 단독 실행 가능하다. 이 세 파일 + LoRA 둘이면 편집 워크플로우는 자체 완결이고
# SDXL 체크포인트·ControlNet·IPAdapter 는 Qwen 자체엔 필요 없다.
#   ./setup.sh qwen           지시문 실험 단계. 볼륨을 Qwen 에 몰아준다 → fp8
#   ./setup.sh anime qwen     부트스트랩(LoRA v1 → 애니 모델 재생성)까지 갈 때 → GGUF
#
# 애니 프로필을 같이 쓰는 이유는 Qwen 의 요구사항이 아니라 실습 목표 때문이다.
# 편집 결과는 실사 쪽으로 끌려서 선이 뭉개진다. 그 컷을 그대로 캐릭터 시트에 넣으면
# 19번 시트 → 20번 LoRA 데이터셋이 화풍 섞인 채로 만들어진다.
# 즉 "단독으로는 안 돌아간다"가 아니라 "다음 단계에서 쓸 수 없다"에 가깝다.
#
# ── 2509 → 2511 로 올린 이유 (2025-12-23 릴리스) ──────
#   · image drift 완화. 지시한 부분 외를 건드리는 빈도가 눈에 띄게 줄었다.
#     2509 에서 "재킷만 빨갛게" 했더니 멜빵바지까지 물들던 문제의 직접적 개선.
#   · 캐릭터 아이덴티티 보존 강화. 다각도 데이터셋 뽑기에는 이게 전부다.
#   · 커뮤니티 LoRA 일부가 베이스에 통합됨. 시점 변경이 LoRA 없이도 어느 정도 된다.
#     (그래도 각도를 "축으로 스캔"하려면 아래 Multiple-Angles LoRA 가 낫다)
#   노드 구성은 2509 와 같다 — TextEncodeQwenImageEditPlus 그대로. 파일만 갈아끼우면 된다.
#   단, 2511 은 conditioning 에 FluxKontextMultiReferenceLatentMethod 를 하나 더 물려야 한다.

# ── 정밀도 선택 ────────────────────────────────────
# 50GB 볼륨 기준 (LoRA 2개 약 1.5GB 포함):
#   qwen 단독 + fp8   = 공통 6 + 20.5 + 9.3 + 1.5 = 37GB   ← 24GB GPU 에 fp8 이 딱 맞는 조합
#   qwen 단독 + GGUF  = 공통 6 + 15   + 9.3 + 1.5 = 32GB
#   anime qwen + GGUF = 공통 6 + 15 + 15 + 9.3 + 1.5 = 47GB
#   anime qwen + fp8  = 52GB → 볼륨 초과. 그래서 같이 쓰면 자동으로 GGUF 로 내린다.
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
  # 2511 의 fp8 은 fp8mixed 하나뿐이다. 2509 처럼 fp8_e4m3fn 단독 파일은 올라오지 않았다.
  # 민감한 레이어를 고정밀로 남기는 혼합 양자화라 순수 fp8 보다 품질이 낫다. 20.5GB.
  FILES+=(
    "$BASE/diffusion_models|qwen_image_edit_2511_fp8mixed.safetensors|https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors"
  )
else
  # Q5_K_M, 15GB. 로컬 16GB 와 RunPod 24GB 를 파일 하나로 커버한다.
  # 2509 는 QuantStack 이 유일했지만 2511 은 unsloth 판이 표준이 됐다(Dynamic 2.0, 중요 레이어 상향).
  # Q2~Q4 는 출력 아티팩트가 보고돼 있어 쓰지 않는다. 볼륨이 남으면 Q6_K(16.9GB) 가 다음 후보.
  FILES+=(
    "$BASE/unet|qwen-image-edit-2511-Q5_K_M.gguf|https://huggingface.co/unsloth/Qwen-Image-Edit-2511-GGUF/resolve/main/qwen-image-edit-2511-Q5_K_M.gguf"
  )
fi

# 정밀도와 무관하게 공유되는 파일들. fp8 <-> GGUF 를 오가도 다시 받지 않는다.
FILES+=(
  "$BASE/text_encoders|qwen_2.5_vl_7b_fp8_scaled.safetensors|https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"
  "$BASE/vae|qwen_image_vae.safetensors|https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"

  # ── Lightning 4-step LoRA (850MB) ────────────────
  # 이제 기본으로 받는다. 40스텝 → 4스텝, 장당 5분 → 1분 이하.
  # 데이터셋 작업은 "많이 뽑고 골라내는" 일이라 회전 속도가 곧 결과 품질이다.
  # 채택률 50% 면 40장 얻는 데 80장을 뽑아야 하는데, 장당 5분이면 이 경로는 성립하지 않는다.
  # 2509용 Qwen-Image-Lightning V2.0 과는 다른 파일이다. 반드시 2511 전용을 쓸 것.
  "$BASE/loras|Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors|https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"

  # ── Multiple-Angles LoRA (fal, 2511 전용) ────────
  # 4 elevation x 8 azimuth x 3 distance = 96 카메라 포즈. Gaussian Splatting 렌더 3000쌍으로 학습.
  # 이걸 쓰는 이유는 속도가 아니라 "각도를 축으로 스캔할 수 있게 된다"는 것이다.
  # 자연어로 "about 30 degrees" 를 매번 다르게 해석당하는 대신, 8방위를 균등하게 훑어서
  # 데이터셋의 각도 분포를 설계할 수 있다. LoRA 데이터셋에서는 이 균등성이 품질을 좌우한다.
  # 2511 베이스도 시점 변경을 어느 정도 하지만, 저앵글(-30도)과 정밀도는 이쪽이 확실히 낫다.
  "$BASE/loras|qwen-image-edit-2511-multiple-angles-lora.safetensors|https://huggingface.co/fal/Qwen-Image-Edit-2511-Multiple-Angles-LoRA/resolve/main/qwen-image-edit-2511-multiple-angles-lora.safetensors"
)

# GGUF 로더. 이 줄이 먹히려면 setup.sh 에서 NODE_REPOS 선언이 프로필 source 보다 위에 있어야 한다.
# fp8 모드에서도 같이 설치한다 — 노드 하나뿐이고, 나중에 GGUF 로 내려갈 때 재실행이 줄어든다.
NODE_REPOS+=(
  "ComfyUI-GGUF|https://github.com/city96/ComfyUI-GGUF.git|no"
)

if [ "$QWEN_MODE" = "fp8" ]; then
  QWEN_LOADER="Load Diffusion Model ← qwen_image_edit_2511_fp8mixed"
else
  QWEN_LOADER="Unet Loader (GGUF)   ← qwen-image-edit-2511-Q5_K_M.gguf"
fi

HINT="$HINT
[qwen] Qwen-Image-Edit 2511 ($QWEN_MODE) — SDXL 아님. Load Checkpoint 쓰지 말 것.

  ■ 로더 3개
      $QWEN_LOADER
      CLIPLoader           ← qwen_2.5_vl_7b_fp8_scaled, type: qwen_image
      Load VAE             ← qwen_image_vae
    CLIPLoader 의 type 기본값은 stable_diffusion 이다. 안 바꾸면 Qwen2.5-VL 가중치를
    SD1 토크나이저로 읽어 프롬프트가 전달되지 않는다. 에러 없이 조용히 실패한다.

  ■ LoRA 2개 (LoraLoaderModelOnly 를 직렬로)
      Lightning-4steps-V1.0-bf16          strength 1.0   — 항상 켠다
      multiple-angles-lora                strength 0.9   — 각도 컷에만 켠다
    각도 LoRA 를 켠 채로 표정·포즈를 지시하면 카메라 축으로 해석돼 끌려간다.
    표정/포즈/의상 컷을 뽑을 때는 반드시 bypass(Ctrl+B) 할 것.

  ■ 배선 (2509 에서 바뀐 곳 3군데)
      Load Image
        → ImageScaleToTotalPixels(1.0 megapixel)      ← FluxKontextImageScale 아님
        → TextEncodeQwenImageEditPlus(pos/neg).image1
      Unet/Diffusion Loader → LoRA → ModelSamplingAuraFlow(shift 3.0) → KSampler.model
      두 TextEncode → FluxKontextMultiReferenceLatentMethod → KSampler.positive/negative
        ↑ 2511 신규. 이거 없이 2509 워크플로우를 그대로 쓰면 다중 참조가 어긋난다.
      EmptySD3LatentImage → KSampler.latent_image      ← VAEEncode 아님

    VAEEncode 를 뺀 이유: denoise 1.0 이면 초기 latent 는 전부 노이즈로 덮인다.
    즉 VAEEncode 가 실제로 제공하는 건 내용이 아니라 캔버스 크기뿐이다.
    EmptySD3LatentImage 로 바꾸면 출력 비율을 자유롭게 정할 수 있다 —
    상반신 원본에서 전신 컷을 뽑으려면 세로로 긴 캔버스가 필요하고,
    전신 컷 없는 캐릭터 LoRA 는 반쪽이다.
      1024x1024  기본 / 상반신·얼굴
      832x1216   전신·서있는 포즈
      1216x832   와이드샷·앉은 포즈

  ■ KSampler
      steps 4 / cfg 1.0 / euler / simple / denoise 1.0 / seed fixed
    denoise 를 낮추면 안 된다. Qwen-Image-Edit 는 원본을 latent 가 아니라 참조 조건으로
    받기 때문에, img2img 감각으로 0.5 를 넣으면 지시가 반영되기 전에 샘플링이 끝난다.
    cfg 1.0 에서는 네거티브가 계산에 들어가지 않는다. 비워둘 것.
    seed 를 흔들면 지시문 때문에 달라진 건지 구분할 수 없다. 축 실험 내내 고정.

  ■ 지시문 — 영어 평서문. booru 태그와 quality 태그는 여기서 효과 없다.
    [각도] 각도 LoRA ON. 형식은 <sks> [방위] [앙각] [거리] 순서 고정.
      <sks> front-left quarter view eye-level shot medium shot
      방위 front / front-right quarter / right side / back-right quarter /
           back / back-left quarter / left side / front-left quarter
      앙각 low-angle(-30) / eye-level(0) / elevated(30) / high-angle(60)
      거리 close-up / medium shot / wide shot
    [표정] 각도 LoRA OFF
      change her expression to a wide smile, keep everything else unchanged
    [포즈] 각도 LoRA OFF + 캔버스 832x1216
      change her pose to arms crossed, full body, keep the same face and outfit
    [의상] 각도 LoRA OFF
      change her jacket to a white hoodie, keep everything else unchanged
    [합성] 참조 2장
      place the person from image 1 into the background of image 2
    '나머지는 그대로'를 매번 명시하는 게 아이덴티티 유지에 제일 크게 먹힌다.

  ■ 데이터셋 원칙 (여기서 어기면 20번에서 되돌릴 수 없다)
    · 모든 컷은 원본 1장에서 직접 파생시킬 것. 편집 결과를 다시 편집하면
      VAE 왕복마다 디테일이 깎이고 인물이 조금씩 표류한다.
    · 전 컷 'keep the same outfit' 은 금물. 의상이 캐릭터 특징으로 흡수돼
      나중에 옷을 갈아입힐 수 없는 LoRA 가 된다. 의상 변형 3~4장을 반드시 섞을 것.
    · 배경도 같은 이유로 일부는 바꿀 것. 단순 배경만 40장이면 배경까지 고착된다.
    · 저장 위치: $PROJ/dataset/raw → 선별 → $PROJ/dataset/keep
      파일명에 축을 박아둘 것. ang_315_eye_med / exp_smile / pose_arms_crossed

  ■ 정밀도를 바꿔 재실행했다면 안 쓰는 쪽을 지울 것. 둘 다 남기면 35GB 가 논다.
      rm $BASE/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors
      rm $BASE/unet/qwen-image-edit-2511-Q5_K_M.gguf
    2509 파일이 남아 있다면 같이 정리한다.
      rm -f $BASE/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors
      rm -f $BASE/unet/Qwen-Image-Edit-2509-Q5_K_M.gguf
      rm -f $BASE/loras/Qwen-Image-Lightning-4steps-V2.0.safetensors
"

# 애니 계열 프로필이 같이 지정된 경우에만 부트스트랩 안내를 붙인다.
case " $* " in
  *" anime "*|*" nsfw "*)
    HINT="$HINT
  ■ 부트스트랩 (컷마다 왕복 복원하지 말 것)
    Qwen 결과를 컷마다 img2img 로 되돌리는 건 40장 x 수작업인 데다
    컷마다 복원 강도가 달라져 일관성이 오히려 떨어진다. 2단계로 나눈다.
      1) qwen 2511 로 20~25장 → 화풍이 좀 흔들려도 OK, 각도·구도 다양성만 확보
      2) 그걸로 LoRA v1 을 러프하게 굽는다 (저에폭)
      3) v1 을 wai / Illustrious 에 얹어 in-domain 으로 80~100장 생성
      4) 60장 선별 → LoRA v2 ← 실전용
    v2 의 데이터셋은 애니 체크포인트 자신의 출력이라 화풍 오염이 원천적으로 없다.
    Qwen 은 v1 을 만들 씨앗만 제공하고 최종 결과물에서 빠진다.

    개별 컷 복구가 필요할 때만 (뒷모습처럼 새로 지어낸 면적이 큰 컷):
      qwen 결과 → Illustrious_lineart_anime ControlNet + img2img(denoise 0.35~0.5)
      → wai / Illustrious 로 통과
"
    ;;
  *)
    HINT="$HINT
  ■ 지금은 qwen 단독이다. LoRA v1 을 굽고 애니 모델로 재생성하는 부트스트랩
    단계로 넘어갈 때 anime 또는 nsfw 를 같이 지정할 것.
"
    ;;
esac
