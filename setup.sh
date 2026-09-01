#!/bin/bash
set -e

# RunPod ComfyUI (runpod-slim).
#
#   ./setup.sh real            실사 (RealVisXL)
#   ./setup.sh anime           애니 (Illustrious 공식 베이스)
#   ./setup.sh nsfw            애니 (WAI)
#   ./setup.sh retro           레트로/반실사 (Retrordinary)
#   ./setup.sh qwen            Qwen-Image-Edit 2511 (SDXL 아님, 단독 실행 가능)
#   ./setup.sh video           Wan 2.2 i2v (SDXL 아님, 단독 실행 가능)
#   ./setup.sh ltx             LTX-2.5 (실험적, HF 토큰 필요)
#   ./setup.sh anime qwen      부트스트랩. qwen 은 자동으로 GGUF.
#   ./setup.sh anime video     부트스트랩. video 는 자동으로 5B.
#   ./setup.sh krea            Krea 2 Turbo t2i (SDXL 아님, 단독 실행 가능)
#   ./setup.sh smooth
#   ./setup.sh dasiwa
#
# ── 보충 실습(레이어합성·ESRGAN·립싱크·LTXV, SVD/AnimateDiff 대체) ──
#   ./setup.sh layerstyle      레이어 합성 (모델 다운로드 없음, 노드만)
#   ./setup.sh esrgan          ESRGAN 업스케일러 (커스텀 노드 불필요)
#   ./setup.sh latentsync      립싱크 — LatentSync (SVD 기반 Sonic 대체)
#   ./setup.sh ltxv            LTXV 경량판 (0.9.8 distilled-fp8, ltx 프로필과 별도 — HF 토큰 불필요)
#   ./setup.sh anime layerstyle esrgan latentsync ltxv   보충 실습 한번에 부트스트랩
#
# 볼륨 100GB 기준 조합별 누계는 각 프로필 파일 상단 주석에 있다.
# 권장: anime + qwen(fp8) + video(5b) = 70GB.
# 보충 실습 4종 추가 누계: layerstyle(+0) + esrgan(+0.13GB) + latentsync(+3.5GB) + ltxv(+9.6GB) ≈ +13GB.
#
# 20GB 급 파일이 섞이면 tmux 안에서 돌릴 것.
#   tmux new -s dl  →  ./setup.sh anime video  →  Ctrl+b, d
# 중단되어도 .part 를 남기므로 재실행하면 이어받는다.

COMFY=/workspace/runpod-slim/ComfyUI
BASE=/workspace/shared_models
PROJ=/workspace/project_lomebrote
NODES=$COMFY/custom_nodes
SELF="$(cd "$(dirname "$0")" && pwd)"
# 예전엔 /workspace/lomebrote 를 박아 뒀는데, 클론 위치를 옮기면 조용히 깨졌다.
# 스크립트가 있는 곳을 저장소로 본다.
REPO="$SELF"

DL_RETRIES=${DL_RETRIES:-5}

# 토큰. 파드는 매번 새로 만들지만 /workspace 는 볼륨이라 살아남는다.
#   printf '%s' '<키>' > /workspace/.civitai_token && chmod 600 /workspace/.civitai_token
#   printf '%s' '<키>' > /workspace/.hf_token      && chmod 600 /workspace/.hf_token
# 환경변수가 우선이므로 한 번만 다르게 쓰려면 CIVITAI_TOKEN=... 을 앞에 붙이면 된다.
if [ -z "$CIVITAI_TOKEN" ] && [ -r /workspace/.civitai_token ]; then
  CIVITAI_TOKEN="$(tr -d ' \t\r\n' < /workspace/.civitai_token)"
fi
# HF 토큰은 게이트 저장소(LTX-2.5 등)용. Comfy-Org / Wan 계열은 없어도 받아진다.
if [ -z "$HF_TOKEN" ] && [ -r /workspace/.hf_token ]; then
  HF_TOKEN="$(tr -d ' \t\r\n' < /workspace/.hf_token)"
fi

PY=""
for c in /workspace/runpod-slim/venv/bin/python /workspace/venv/bin/python $COMFY/venv/bin/python; do
  [ -x "$c" ] && PY="$c" && break
done
[ -z "$PY" ] && PY="$(command -v python3)"

if [ $# -eq 0 ]; then
  echo "사용법: ./setup.sh <프로필...>"
  for f in "$SELF"/profiles/*.sh; do
    [ -f "$f" ] && echo "  $(basename "${f%.sh}")"
  done
  exit 1
fi

# ── 프로필 계약 ────────────────────────────────────
# 프로필은 FILES / NODE_REPOS 에 항목을 덧붙인다.
# SDXL 계열 프로필은 SDXL=1 을 선언한다 (IPAdapter 블록의 조건).
# HF 게이트 파일을 받는 프로필은 NEED_HF_TOKEN=1 을 선언한다.

# 공통 전처리기 가중치. 폴더가 <HF 저장소명> 구조여야 노드가 찾는다.
FILES=(
  "$BASE/controlnet_aux/hr16/yolox-onnx|yolox_l.torchscript.pt|https://huggingface.co/hr16/yolox-onnx/resolve/main/yolox_l.torchscript.pt"
  "$BASE/controlnet_aux/hr16/DWPose-TorchScript-BatchSize5|dw-ll_ucoco_384_bs5.torchscript.pt|https://huggingface.co/hr16/DWPose-TorchScript-BatchSize5/resolve/main/dw-ll_ucoco_384_bs5.torchscript.pt"
  "$BASE/controlnet_aux/yzd-v/DWPose|yolox_l.onnx|https://huggingface.co/yzd-v/DWPose/resolve/main/yolox_l.onnx"
  "$BASE/controlnet_aux/depth-anything/Depth-Anything-V2-Large|depth_anything_v2_vitl.pth|https://huggingface.co/depth-anything/Depth-Anything-V2-Large/resolve/main/depth_anything_v2_vitl.pth"
)
SDXL=""
NEED_HF_TOKEN=""

# 프로필이 NODE_REPOS+= 로 덧붙이므로 반드시 source 보다 위에 있어야 한다.
NODE_REPOS=(
  "ComfyUI_UltimateSDUpscale|https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git|yes"
  "ComfyUI-Inpaint-CropAndStitch|https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git|no"
  "ComfyUI-WD14-Tagger|https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git|no"
  "comfyui_controlnet_aux|https://github.com/Fannovel16/comfyui_controlnet_aux.git|no"
  # 원저작자(LucianoCirino) 저장소는 관리 중단. jags111 포크가 유지판이다.
  "efficiency-nodes-comfyui|https://github.com/jags111/efficiency-nodes-comfyui.git|no"
  "ComfyUI_IPAdapter_plus|https://github.com/cubiq/ComfyUI_IPAdapter_plus.git|no"
  # FaceDetailer. v8.0 부터 UltralyticsDetectorProvider 가 Subpack 으로 분리돼서 둘 다 필요하다.
  # Subpack 의 requirements 가 ultralytics 를 끌고 온다(아래 pip 루프가 처리).
  "ComfyUI-Impact-Pack|https://github.com/ltdrdata/ComfyUI-Impact-Pack.git|no"
  "ComfyUI-Impact-Subpack|https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git|no"
)

for p in "$@"; do
  f="$SELF/profiles/$p.sh"
  [ -f "$f" ] || { echo "없는 프로필: $p"; exit 1; }
  source "$f"
done

# SDXL 전용 IPAdapter 가중치(약 4GB). qwen/video/ltx 단독 실행에서는 건너뛴다.
# 파일명 규칙: 앞의 sdxl = 체크포인트 계열, 뒤의 vit-h = clip_vision 인코더(bigG 아님).
# 원본이 model.safetensors 라 리네임 필수. Unified Loader 는 아래 이름과 글자 하나까지 같아야 인식한다.
if [ -n "$SDXL" ]; then
  FILES+=(
    "$BASE/clip_vision|CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors|https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors"
    "$BASE/ipadapter|ip-adapter_sdxl_vit-h.safetensors|https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl_vit-h.safetensors"
    "$BASE/ipadapter|ip-adapter-plus_sdxl_vit-h.safetensors|https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors"
  )

  # FaceDetailer 감지 모델. bbox/ segm/ 하위 폴더 구조가 그대로여야 노드 드롭다운에 뜬다.
  # 노드에서는 "bbox/face_yolov8m.pt" 처럼 폴더명이 붙은 채로 보인다.
  # yolov8m(약 52MB) 이 기본. 얼굴이 작은 구도에서는 s 보다 회수율이 낫다.
  FILES+=(
    "$BASE/ultralytics/bbox|face_yolov8m.pt|https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt"
    "$BASE/ultralytics/bbox|hand_yolov8s.pt|https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt"
    "$BASE/ultralytics/segm|person_yolov8m-seg.pt|https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt"
    # SAM. bbox 만으로 충분한 경우가 많아 선택이지만, 머리카락에 걸리는 얼굴 경계를
    # 정리할 때 sam_model_opt 로 물린다. vit_b 는 375MB 로 vit_h(2.4GB) 대비 가볍다.
    "$BASE/sams|sam_vit_b_01ec64.pth|https://huggingface.co/segments-arnaud/sam_vit_b/resolve/main/sam_vit_b_01ec64.pth"
  )
fi

# ──────────────────────────────────────────────────

echo "프로필: $* / python: $PY / 디스크: $(df -h /workspace | awk 'NR==2 {print $4}')"

# ComfyUI 버전. 예전엔 이미지에 뭐가 들었든 그냥 썼는데, 영상 모델은 코어 버전을
# 탄다(LTX-2.5 = 0.32.0 이상, Wan2.2 템플릿 = 0.3.46 이상). 안 맞으면 노드가 아예 없다.
if [ -d "$COMFY/.git" ]; then
  echo "ComfyUI: $(git -C "$COMFY" describe --tags --always 2>/dev/null || echo '태그 없음') ($(git -C "$COMFY" log -1 --format=%cd --date=short 2>/dev/null))"
  echo "  ※ 영상 모델 템플릿이 안 보이면 여기서 git pull 후 파드 재기동."
else
  echo "ComfyUI: 버전 확인 불가 (git 저장소 아님)"
fi

if [ -z "$TMUX" ] && [ -z "$STY" ] && [ -t 1 ]; then
  echo "  ⚠ tmux/screen 밖입니다. 세션이 끊기면 다운로드도 죽습니다 (.part 는 남습니다)."
  sleep 3
fi

echo "[1/5] git · 다운로더"
git config --global user.email "odineyes2@gmail.com"
git config --global user.name "odineyes2"
git config --global credential.helper 'cache --timeout=36000'

# aria2c 는 연결을 16개로 쪼갠다. 설치 실패해도 wget 으로 진행한다.
if ! command -v aria2c >/dev/null 2>&1; then
  (apt-get update -qq && apt-get install -y -qq aria2) >/dev/null 2>&1 || true
fi
command -v aria2c >/dev/null 2>&1 && echo "  aria2c (16 연결)" || echo "  wget (단일 연결)"

echo "[2/5] 폴더 · 설정"
# diffusion_models/text_encoders/unet 은 Qwen·Wan 계열용.
# model_patches / latent_upscale_models 는 LTX-2.5 용. yaml 에도 같은 키가 있어야 한다.
mkdir -p $BASE/{checkpoints,loras,vae,controlnet,upscale_models,clip_vision,ipadapter,embeddings,wd14_tagger,controlnet_aux,diffusion_models,text_encoders,unet,sams,model_patches,latent_upscale_models,audio_encoders}
# Impact Subpack 은 ultralytics/ 아래 bbox·segm 을 각각 따로 스캔한다. 평평하게 두면 못 찾는다.
mkdir -p $BASE/ultralytics/{bbox,segm}
mkdir -p $PROJ/{output_keep,depthmaps}
mkdir -p $PROJ/dataset/{raw,keep,caption}
# 영상 실습 산출물. mp4 는 용량이 커서 output_keep 과 섞으면 정리가 안 된다.
mkdir -p $PROJ/{video_in,video_out}
cp $REPO/extra_model_paths.yaml $COMFY/
mkdir -p $COMFY/user/default/workflows
# cp -n $REPO/workflows/*.json $COMFY/user/default/workflows/ 2>/dev/null || true
cp -rn $REPO/workflows/. $COMFY/user/default/workflows/ 2>/dev/null || true

echo "[3/5] 커스텀 노드"
mkdir -p $NODES && cd $NODES
for e in "${NODE_REPOS[@]}"; do
  IFS='|' read -r dir url rec <<< "$e"
  if [ -d "$dir/.git" ]; then
    [ "$rec" = "yes" ] && git -C "$dir" submodule update --init --recursive
  elif [ "$rec" = "yes" ]; then
    git clone --recursive "$url"
  else
    git clone "$url"
  fi
done
# RunPod 이미지는 PIP_CONSTRAINT 로 torch 버전을 못박아 둔다(+cuXXX 로컬 버전 휠).
# pip 의 빌드 격리 환경은 PyPI 만 보므로 로컬 버전 휠을 찾지 못하고,
# 소스 빌드가 필요한 패키지(Impact Subpack 의 sam2 등)가 ResolutionImpossible 로 죽는다.
# 이미 설치된 torch 를 그대로 쓰도록 격리를 끄고, 그래도 안 되면 건너뛴다.
# sam2 는 SAM2 모델 전용이라 FaceDetailer(segment-anything 사용)에는 없어도 된다.
install_reqs() {
  local req="$1" name tmp
  name="$(basename "$(dirname "$req")")"
  tmp="$(mktemp)"
  grep -v '^[[:space:]]*\(git+\|-e[[:space:]]\)' "$req" > "$tmp" || true
  PIP_CONSTRAINT= "$PY" -m pip install -q -r "$tmp" \
    || echo "  ! requirements 일부 실패: $name"
  rm -f "$tmp"
  grep '^[[:space:]]*git+' "$req" 2>/dev/null | while read -r pkg; do
    PIP_CONSTRAINT= "$PY" -m pip install -q --no-build-isolation "$pkg" \
      || echo "  ! 선택 의존성 건너뜀: $name → $pkg"
  done
}

for req in $NODES/*/requirements.txt; do
  [ -f "$req" ] && install_reqs "$req"
done

# Impact Pack 은 Manager 가 install.py 를 돌려주는 걸 전제로 만들어져 있다.
# 손으로 clone 하면 impact-pack.ini 가 안 생겨서 노드가 통째로 로드에 실패한다.
for ip in ComfyUI-Impact-Pack ComfyUI-Impact-Subpack; do
  [ -f "$NODES/$ip/install.py" ] || continue
  (cd "$NODES/$ip" && PIP_CONSTRAINT= "$PY" install.py) \
    || echo "  ! install.py 실패: $ip (기동 후 콘솔에서 IMPORT FAILED 여부 확인)"
done

echo "[4/5] 노드 설정"
# 전처리기 가중치를 노드 폴더 밖으로 뺀다(재클론 시 유실 방지).
# EP_list 가 CPU 인 이유: onnxruntime-gpu 는 CUDA 12+ 에서 설치가 번거롭다.
# 노드에서 .torchscript.pt 계열을 고르면 torch 가 GPU 를 쓴다.
cat > $NODES/comfyui_controlnet_aux/config.yaml << YAMLEOF
annotator_ckpts_path: "$BASE/controlnet_aux"
custom_temp_path:
USE_SYMLINKS: False
EP_list: ["CPUExecutionProvider"]
YAMLEOF

# pysssss.json 은 저장소 안에 있어 파드마다 초기화된다. settings 만 덮어쓴다.
# eva02-large 는 swinv2 보다 느리지만 의상·소품 태그 회수율이 높다.
# 캐릭터 LoRA 는 의상 태그를 빠짐없이 달아 얼굴과 분리하는 게 핵심이라 여기서 정확도가 곧 결과다.
CFG=$NODES/ComfyUI-WD14-Tagger/pysssss.json
[ -f "$CFG" ] && "$PY" - "$CFG" << 'PYEOF'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
c.setdefault("settings", {}).update({
    "model": "wd-eva02-large-tagger-v3", "threshold": 0.35,
    "character_threshold": 0.85, "replace_underscore": True,
    "exclude_tags": "watermark, signature, artist name, web address, username",
})
json.dump(c, open(p, "w"), indent=2, ensure_ascii=False)
PYEOF

# ── 다운로드 ──────────────────────────────────────
# 원칙: 실패해도 .part 를 지우지 않는다. 지우는 경우는 다 받았는데 크기가 비정상일 때뿐.

download() {
  local dir="$1" name="$2" url="$3"
  local dest="$dir/$name" part="$dir/$name.part"
  local ok=0 try=1 rc=0
  local -a hdr=()
  mkdir -p "$dir"

  # civitai 는 API 다운로드에 토큰을 요구한다. 헤더는 CDN 리다이렉트에서 잘려서
  # 쿼리 파라미터로 붙인다.
  case "$url" in
    *civitai.com/api/*|*civitai.red/api/*)
      if [ -n "$CIVITAI_TOKEN" ]; then
        case "$url" in
          *\?*) url="$url&token=$CIVITAI_TOKEN" ;;
          *)    url="$url?token=$CIVITAI_TOKEN" ;;
        esac
      fi ;;
    # HF 는 반대로 헤더가 살아남는다(cdn-lfs 로 리다이렉트돼도 재전송된다).
    # 토큰을 쿼리로 붙이면 서명이 깨지므로 반드시 헤더로.
    # 게이트가 아닌 저장소에 토큰을 얹어도 무해하다.
    *huggingface.co/*)
      if [ -n "$HF_TOKEN" ]; then
        # 반드시 배열 원소 하나로. 따옴표 없이 펼치면 "Bearer" 와 토큰이
        # 별개 인자로 쪼개져서 aria2c 가 URL 로 오해한다.
        hdr=("--header=Authorization: Bearer $HF_TOKEN")
      fi ;;
  esac

  [ -s "$part" ] && echo "    이어받기: $(du -h "$part" | cut -f1) 부터"

  while [ "$try" -le "$DL_RETRIES" ]; do
    rc=0
    if command -v aria2c >/dev/null 2>&1; then
      aria2c -c -x16 -s16 -k1M \
             --file-allocation=none --allow-overwrite=true --auto-file-renaming=false \
             --max-tries=3 --retry-wait=10 --timeout=60 \
             --console-log-level=warn --summary-interval=60 \
             "${hdr[@]}" \
             -d "$dir" -o "$name.part" "$url" || rc=$?
    else
      wget -c --tries=3 --waitretry=10 --read-timeout=60 \
           "${hdr[@]}" \
           --show-progress -q -O "$part" "$url" || rc=$?
    fi
    [ "$rc" -eq 0 ] && { ok=1; break; }

    # aria2 24 / wget 6 = 인증 실패. 재시도해도 안 바뀌므로 즉시 포기한다.
    if [ "$rc" -eq 24 ] || { ! command -v aria2c >/dev/null 2>&1 && [ "$rc" -eq 6 ]; }; then
      echo "  ! 인증 실패(401): $name"
      case "$url" in
        *civitai*)     echo "    CIVITAI_TOKEN=<키> ./setup.sh ...  또는 civitai.red 미러를 쓸 것." ;;
        *huggingface*) echo "    HF_TOKEN=<키> ./setup.sh ...  게이트 저장소는 웹에서 약관 동의도 먼저 해야 한다." ;;
      esac
      break
    fi

    echo "    … 실패($rc), 재시도 $try/$DL_RETRIES"
    try=$((try + 1))
    sleep 10
  done

  if [ "$ok" -ne 1 ]; then
    # 0바이트 조각은 다음 실행에서 "이어받기 0 부터"로 오해를 부른다.
    [ -s "$part" ] || rm -f "$part" "$dir/$name.part.aria2"
    [ -s "$part" ] && echo "  ! 미완료: $name ($part 유지, 재실행하면 이어받음)"
    return 1
  fi

  # HTML 오류 페이지를 받으면 크기가 확 작다.
  if [ "$(stat -c%s "$part")" -lt 100000 ]; then
    rm -f "$part" "$dir/$name.part.aria2"
    echo "  ! 크기 이상 — URL 확인 필요: $name"
    return 1
  fi

  mv "$part" "$dest"
  rm -f "$dir/$name.part.aria2"
}

# 5번씩 재시도하고 나서야 토큰이 없다는 걸 알게 되는 걸 막는다.
if [ -z "$CIVITAI_TOKEN" ]; then
  for e in "${FILES[@]}"; do
    case "$e" in
      *civitai*)
        echo "  ⚠ civitai 파일이 있는데 토큰이 없습니다."
        echo "    CIVITAI_TOKEN=<키> 또는 /workspace/.civitai_token 파일"
        break ;;
    esac
  done
fi
if [ -n "$NEED_HF_TOKEN" ] && [ -z "$HF_TOKEN" ]; then
  echo "  ⚠ 게이트된 HF 저장소를 받는 프로필인데 토큰이 없습니다. 반드시 401 이 납니다."
  echo "    1) 해당 모델 페이지에서 약관 동의  2) HF_TOKEN=<키> 또는 /workspace/.hf_token"
  echo "    LTX-2.5: https://huggingface.co/Lightricks/LTX-2.5"
fi

echo "[5/5] 파일 다운로드"
# 예전엔 첫 실패에서 exit 1 했는데, 20GB 짜리를 여럿 받는 중에 civitai 하나가
# 넘어지면 뒤의 정상 파일까지 통째로 못 받았다. 실패는 모아서 끝에 보고한다.
FAILED=()
for e in "${FILES[@]}"; do
  IFS='|' read -r dir name url <<< "$e"
  dest="$dir/$name"
  if [ -s "$dest" ] && [ "$(stat -c%s "$dest")" -gt 100000 ]; then
    echo "  = $name"
    continue
  fi
  echo "  + $name"
  download "$dir" "$name" "$url" || FAILED+=("$name")
done

echo ""
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "⚠ 실패 ${#FAILED[@]}건:"
  for f in "${FAILED[@]}"; do echo "    - $f"; done
  echo "  재실행하면 성공한 파일은 건너뛰고 실패분만 이어받습니다."
else
  echo "완료. 파드를 Restart 해야 yaml 이 적용됩니다."
fi
echo "  ※ extra_model_paths.yaml 에 ultralytics_bbox / ultralytics_segm / sams 키가"
echo "    없으면 FaceDetailer 의 감지 모델 드롭다운이 빈 채로 뜹니다."
echo "  ※ 영상 프로필은 model_patches / latent_upscale_models 키도 필요합니다."
echo "남은 디스크: $(df -h /workspace | awk 'NR==2 {print $4}')"

[ ${#FAILED[@]} -gt 0 ] && exit 1
exit 0
