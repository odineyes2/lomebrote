#!/bin/bash
set -e

# RunPod ComfyUI (runpod-slim), CUDA 12.8.
#
#   ./setup.sh real            실사 (RealVisXL)
#   ./setup.sh anime           애니 (Illustrious 공식 베이스)
#   ./setup.sh nsfw            애니 (WAI)
#   ./setup.sh retro           레트로/반실사 (Retrordinary)
#   ./setup.sh qwen            Qwen-Image-Edit 2511 (SDXL 아님, 단독 실행 가능)
#   ./setup.sh anime qwen      부트스트랩. qwen 은 자동으로 GGUF.
#
# 20GB 급 파일이 섞이면 tmux 안에서 돌릴 것.
#   tmux new -s dl  →  ./setup.sh anime qwen  →  Ctrl+b, d
# 중단되어도 .part 를 남기므로 재실행하면 이어받는다.

COMFY=/workspace/runpod-slim/ComfyUI
BASE=/workspace/shared_models
PROJ=/workspace/project_lomebrote
REPO=/workspace/lomebrote
NODES=$COMFY/custom_nodes
SELF="$(cd "$(dirname "$0")" && pwd)"

DL_RETRIES=${DL_RETRIES:-5}

# civitai 토큰. 파드는 매번 새로 만들지만 /workspace 는 볼륨이라 살아남는다.
#   printf '%s' '<키>' > /workspace/.civitai_token && chmod 600 /workspace/.civitai_token
# 환경변수가 우선이므로 한 번만 다르게 쓰려면 CIVITAI_TOKEN=... 을 앞에 붙이면 된다.
if [ -z "$CIVITAI_TOKEN" ] && [ -r /workspace/.civitai_token ]; then
  CIVITAI_TOKEN="$(tr -d ' \t\r\n' < /workspace/.civitai_token)"
fi

PY=""
for c in /workspace/runpod-slim/venv/bin/python /workspace/venv/bin/python $COMFY/venv/bin/python; do
  [ -x "$c" ] && PY="$c" && break
done
[ -z "$PY" ] && PY="$(command -v python3)"

if [ $# -eq 0 ]; then
  echo "사용법: ./setup.sh <프로필...>"
  for f in "$SELF"/profiles/*.sh; do echo "  $(basename "${f%.sh}")"; done
  exit 1
fi

# ── 프로필 계약 ────────────────────────────────────
# 프로필은 FILES / NODE_REPOS 에 항목을 덧붙인다.
# SDXL 계열 프로필은 SDXL=1 을 선언한다 (IPAdapter 블록의 조건).

# 공통 전처리기 가중치. 폴더가 <HF 저장소명> 구조여야 노드가 찾는다.
FILES=(
  "$BASE/controlnet_aux/hr16/yolox-onnx|yolox_l.torchscript.pt|https://huggingface.co/hr16/yolox-onnx/resolve/main/yolox_l.torchscript.pt"
  "$BASE/controlnet_aux/hr16/DWPose-TorchScript-BatchSize5|dw-ll_ucoco_384_bs5.torchscript.pt|https://huggingface.co/hr16/DWPose-TorchScript-BatchSize5/resolve/main/dw-ll_ucoco_384_bs5.torchscript.pt"
  "$BASE/controlnet_aux/yzd-v/DWPose|yolox_l.onnx|https://huggingface.co/yzd-v/DWPose/resolve/main/yolox_l.onnx"
  "$BASE/controlnet_aux/depth-anything/Depth-Anything-V2-Large|depth_anything_v2_vitl.pth|https://huggingface.co/depth-anything/Depth-Anything-V2-Large/resolve/main/depth_anything_v2_vitl.pth"
)
SDXL=""

# 프로필이 NODE_REPOS+= 로 덧붙이므로 반드시 source 보다 위에 있어야 한다.
NODE_REPOS=(
  "ComfyUI_UltimateSDUpscale|https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git|yes"
  "ComfyUI-Inpaint-CropAndStitch|https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git|no"
  "ComfyUI-WD14-Tagger|https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git|no"
  "comfyui_controlnet_aux|https://github.com/Fannovel16/comfyui_controlnet_aux.git|no"
  # 원저작자(LucianoCirino) 저장소는 관리 중단. jags111 포크가 유지판이다.
  "efficiency-nodes-comfyui|https://github.com/jags111/efficiency-nodes-comfyui.git|no"
  "ComfyUI_IPAdapter_plus|https://github.com/cubiq/ComfyUI_IPAdapter_plus.git|no"
)

for p in "$@"; do
  f="$SELF/profiles/$p.sh"
  [ -f "$f" ] || { echo "없는 프로필: $p"; exit 1; }
  source "$f"
done

# SDXL 전용 IPAdapter 가중치(약 4GB). qwen 단독 실행에서는 건너뛴다.
# 파일명 규칙: 앞의 sdxl = 체크포인트 계열, 뒤의 vit-h = clip_vision 인코더(bigG 아님).
# 원본이 model.safetensors 라 리네임 필수. Unified Loader 는 아래 이름과 글자 하나까지 같아야 인식한다.
if [ -n "$SDXL" ]; then
  FILES+=(
    "$BASE/clip_vision|CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors|https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors"
    "$BASE/ipadapter|ip-adapter_sdxl_vit-h.safetensors|https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl_vit-h.safetensors"
    "$BASE/ipadapter|ip-adapter-plus_sdxl_vit-h.safetensors|https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors"
  )
fi

# ──────────────────────────────────────────────────

echo "프로필: $* / python: $PY / 디스크: $(df -h /workspace | awk 'NR==2 {print $4}')"

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
# diffusion_models/text_encoders/unet 은 Qwen 계열용. yaml 에도 같은 키가 있어야 한다.
mkdir -p $BASE/{checkpoints,loras,vae,controlnet,upscale_models,clip_vision,ipadapter,embeddings,wd14_tagger,controlnet_aux,diffusion_models,text_encoders,unet}
mkdir -p $PROJ/{output_keep,depthmaps}
mkdir -p $PROJ/dataset/{raw,keep,caption}
cp $REPO/extra_model_paths.yaml $COMFY/
mkdir -p $COMFY/user/default/workflows
cp -n $REPO/workflows/*.json $COMFY/user/default/workflows/ 2>/dev/null || true

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
for req in $NODES/*/requirements.txt; do
  [ -f "$req" ] && "$PY" -m pip install -q -r "$req"
done

echo "[4/5] 노드 설정"
# 전처리기 가중치를 노드 폴더 밖으로 뺀다(재클론 시 유실 방지).
# EP_list 가 CPU 인 이유: onnxruntime-gpu 는 CUDA 12 에서 설치가 번거롭다.
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
  esac

  [ -s "$part" ] && echo "    이어받기: $(du -h "$part" | cut -f1) 부터"

  while [ "$try" -le "$DL_RETRIES" ]; do
    rc=0
    if command -v aria2c >/dev/null 2>&1; then
      aria2c -c -x16 -s16 -k1M \
             --file-allocation=none --allow-overwrite=true --auto-file-renaming=false \
             --max-tries=3 --retry-wait=10 --timeout=60 \
             --console-log-level=warn --summary-interval=60 \
             -d "$dir" -o "$name.part" "$url" || rc=$?
    else
      wget -c --tries=3 --waitretry=10 --read-timeout=60 \
           --show-progress -q -O "$part" "$url" || rc=$?
    fi
    [ "$rc" -eq 0 ] && { ok=1; break; }

    # aria2 24 / wget 6 = 인증 실패. 재시도해도 안 바뀌므로 즉시 포기한다.
    if [ "$rc" -eq 24 ] || { ! command -v aria2c >/dev/null 2>&1 && [ "$rc" -eq 6 ]; }; then
      echo "  ! 인증 실패(401): $name"
      case "$url" in
        *civitai*) echo "    CIVITAI_TOKEN=<키> ./setup.sh ...  또는 civitai.red 미러를 쓸 것." ;;
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

echo "[5/5] 파일 다운로드"
for e in "${FILES[@]}"; do
  IFS='|' read -r dir name url <<< "$e"
  dest="$dir/$name"
  if [ -s "$dest" ] && [ "$(stat -c%s "$dest")" -gt 100000 ]; then
    echo "  = $name"
    continue
  fi
  echo "  + $name"
  download "$dir" "$name" "$url" || exit 1
done

echo ""
echo "완료. 파드를 Restart 해야 yaml 이 적용됩니다."
echo "남은 디스크: $(df -h /workspace | awk 'NR==2 {print $4}')"
