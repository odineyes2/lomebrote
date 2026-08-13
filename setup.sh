#!/bin/bash
set -e

# RunPod ComfyUI (runpod-slim), CUDA 12.8. 파드는 매번 terminate.
#
# 사용법: ./setup.sh <프로필...>
#   ./setup.sh real          실사
#   ./setup.sh anime         애니 (Illustrious 공식 베이스)
#   ./setup.sh nsfw          애니 NSFW (WAI)
#   ./setup.sh qwen          Qwen-Image-Edit 2511 지시문 편집 (SDXL 아님, 단독 실행 가능)
#   ./setup.sh anime nsfw    둘 다. 겹치는 파일은 한 번만 받는다.
#   ./setup.sh anime qwen    편집 후 LoRA 부트스트랩까지. qwen 은 자동으로 GGUF 가 된다.
#
# 20GB 급 파일이 섞이면 반드시 tmux 안에서 돌릴 것. SSH 가 끊겨도 살아남는다.
#   tmux new -s dl
#   ./setup.sh anime qwen
#   (Ctrl+b, d 로 빠져나오고 tmux attach -t dl 로 복귀)
#
# 중단되어도 받던 조각(.part)을 남기므로 다시 실행하면 이어받는다.

COMFY=/workspace/runpod-slim/ComfyUI
BASE=/workspace/shared_models
PROJ=/workspace/project_lomebrote
REPO=/workspace/lomebrote
NODES=$COMFY/custom_nodes
SELF="$(cd "$(dirname "$0")" && pwd)"

DL_RETRIES=${DL_RETRIES:-5}   # DL_RETRIES=10 ./setup.sh ... 로 조절

PY=""
for c in /workspace/runpod-slim/venv/bin/python /workspace/venv/bin/python $COMFY/venv/bin/python; do
  [ -x "$c" ] && PY="$c" && break
done
[ -z "$PY" ] && PY="$(command -v python3)"

# ── 프로필 로드 ────────────────────────────────────
# 프로필은 FILES 와 NODE_REPOS 에 항목을 덧붙이고, HINT 에 안내문을 넣는다.
# SDXL 계열 프로필은 SDXL=1 을 선언한다 (아래 IPAdapter 블록의 조건).

if [ $# -eq 0 ]; then
  echo "사용법: ./setup.sh <프로필...>"
  echo "사용 가능:"
  for f in "$SELF"/profiles/*.sh; do echo "  $(basename "${f%.sh}")"; done
  exit 1
fi

# 공통: 전처리기 가중치. 폴더가 <HF 저장소명> 구조여야 노드가 찾는다.
# qwen 에도 쓸모가 있다 — openpose 맵을 참조 이미지 중 하나로 넣으면 포즈를 읽는다.
FILES=(
  "$BASE/controlnet_aux/hr16/yolox-onnx|yolox_l.torchscript.pt|https://huggingface.co/hr16/yolox-onnx/resolve/main/yolox_l.torchscript.pt"
  "$BASE/controlnet_aux/hr16/DWPose-TorchScript-BatchSize5|dw-ll_ucoco_384_bs5.torchscript.pt|https://huggingface.co/hr16/DWPose-TorchScript-BatchSize5/resolve/main/dw-ll_ucoco_384_bs5.torchscript.pt"
  "$BASE/controlnet_aux/yzd-v/DWPose|yolox_l.onnx|https://huggingface.co/yzd-v/DWPose/resolve/main/yolox_l.onnx"
  "$BASE/controlnet_aux/depth-anything/Depth-Anything-V2-Large|depth_anything_v2_vitl.pth|https://huggingface.co/depth-anything/Depth-Anything-V2-Large/resolve/main/depth_anything_v2_vitl.pth"
)
HINT=""
SDXL=""

# 커스텀 노드: 폴더명|저장소|서브모듈 여부
# 프로필이 NODE_REPOS+= 로 덧붙일 수 있어야 하므로 반드시 프로필 source 보다 위에 있어야 한다.
NODE_REPOS=(
  "ComfyUI_UltimateSDUpscale|https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git|yes"
  "ComfyUI-Inpaint-CropAndStitch|https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git|no"
  "ComfyUI-WD14-Tagger|https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git|no"
  "comfyui_controlnet_aux|https://github.com/Fannovel16/comfyui_controlnet_aux.git|no"
  # XY Plot, KSampler (Efficient), Efficient Loader.
  # 원저작자(LucianoCirino) 저장소는 관리 중단. jags111 포크가 유지판이다.
  "efficiency-nodes-comfyui|https://github.com/jags111/efficiency-nodes-comfyui.git|no"
  # 참조 이미지 조건화(1-image LoRA). 노드 코드는 체크포인트 계열을 가리지 않는다.
  # 2025.04부터 유지보수 전용 모드라 노드명·파일명이 안정적이다.
  "ComfyUI_IPAdapter_plus|https://github.com/cubiq/ComfyUI_IPAdapter_plus.git|no"
)

for p in "$@"; do
  f="$SELF/profiles/$p.sh"
  [ -f "$f" ] || { echo "없는 프로필: $p"; exit 1; }
  source "$f"
done

# SDXL 전용: IPAdapter 가중치. 약 4GB 라 qwen 단독 실행에서는 받지 않는다.
# 예전엔 프로필이 전부 SDXL이라 무조건 받았지만 qwen 이 그 전제를 깼다.
# SD1.5 프로필을 추가하게 되면 models/ip-adapter(-plus)_sd15.safetensors 를 쓸 것.
# clip_vision(ViT-H)은 그대로 공유된다.
#
# 파일명 규칙: 앞의 sd15/sdxl = 체크포인트, 뒤의 vit-h/vit-G = clip_vision 인코더.
# sdxl_vit-h 는 "SDXL 체크포인트 + ViT-H 인코더"라는 뜻이다(bigG 아님).
# 원본 파일명이 model.safetensors 라서 리네임이 필수 — name 필드가 그 역할을 한다.
# Unified Loader는 아래 이름과 글자 하나까지 같아야 인식한다.
if [ -n "$SDXL" ]; then
  FILES+=(
    "$BASE/clip_vision|CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors|https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors"
    "$BASE/ipadapter|ip-adapter_sdxl_vit-h.safetensors|https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl_vit-h.safetensors"
    "$BASE/ipadapter|ip-adapter-plus_sdxl_vit-h.safetensors|https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors"
  )
fi

# ──────────────────────────────────────────────────

echo "프로필: $* / python: $PY / 디스크: $(df -h /workspace | awk 'NR==2 {print $4}')"

# tmux 밖에서 돌리면 SSH 가 끊길 때 다운로드가 같이 죽는다. 경고만 하고 진행한다.
if [ -z "$TMUX" ] && [ -z "$STY" ] && [ -t 1 ]; then
  echo ""
  echo "  ⚠ tmux/screen 밖입니다. 세션이 끊기면 다운로드도 같이 죽습니다."
  echo "    권장:  tmux new -s dl   후 다시 실행"
  echo "    중단되어도 .part 는 남으니 재실행하면 이어받습니다."
  echo ""
  sleep 3
fi

echo "[1/5] git · 다운로더"
git config --global user.email "odineyes2@gmail.com"
git config --global user.name "odineyes2"
git config --global credential.helper 'cache --timeout=36000'

# aria2c 는 연결을 16개로 쪼개 받는다. wget 단일 연결 대비 대용량에서 몇 배 빠르다.
# 설치 실패해도 wget 으로 진행하므로 죽이지 않는다.
if ! command -v aria2c >/dev/null 2>&1; then
  echo "  aria2 설치 중..."
  (apt-get update -qq && apt-get install -y -qq aria2) >/dev/null 2>&1 || echo "  aria2 설치 실패 — wget 으로 진행합니다"
fi
command -v aria2c >/dev/null 2>&1 && echo "  다운로더: aria2c (16 연결)" || echo "  다운로더: wget (단일 연결)"

echo "[2/5] 폴더 · 설정"
# diffusion_models/text_encoders/unet 은 Qwen·Flux 계열용. yaml 에도 같은 키가 있어야 한다.
mkdir -p $BASE/{checkpoints,loras,vae,controlnet,upscale_models,clip_vision,ipadapter,embeddings,wd14_tagger,controlnet_aux,diffusion_models,text_encoders,unet}
mkdir -p $PROJ/{output_keep,depthmaps}
# LoRA 데이터셋 작업 폴더. raw 에 배치 결과를 쏟고 → 선별해서 keep 으로 옮긴다.
# caption 은 WD14 태거 출력(.txt)이 이미지와 같은 이름으로 놓이는 자리다.
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
# EP_list를 CPU로 둔 이유: onnxruntime-gpu는 CUDA 12에서 설치가 번거롭다.
# 대신 노드에서 .torchscript.pt 계열을 고르면 torch가 GPU를 쓴다.
cat > $NODES/comfyui_controlnet_aux/config.yaml << YAMLEOF
annotator_ckpts_path: "$BASE/controlnet_aux"
custom_temp_path:
USE_SYMLINKS: False
EP_list: ["CPUExecutionProvider"]
YAMLEOF

# pysssss.json은 저장소 안에 있어 파드마다 초기화된다. settings만 덮어쓴다.
# 태거는 eva02-large 로 올렸다. swinv2 보다 느리지만 의상·소품 태그 회수율이 높다.
# 캐릭터 LoRA 는 "의상 태그를 빠짐없이 달아 얼굴과 분리"하는 게 핵심이라 여기서 정확도가 곧 결과다.
# 가볍게 가려면 wd-swinv2-tagger-v3 로 되돌릴 것.
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
# 원칙: 실패해도 .part 를 절대 지우지 않는다. 20GB 를 다시 받는 일이 없어야 한다.
# 지우는 경우는 단 하나 — 다 받았는데 크기가 비정상일 때(HTML 오류 페이지).

download() {
  local dir="$1" name="$2" url="$3"
  local dest="$dir/$name" part="$dir/$name.part"
  local ok=0 try=1
  mkdir -p "$dir"

  if [ -s "$part" ]; then
    echo "    이어받기: $(du -h "$part" | cut -f1) 부터"
  fi

  while [ "$try" -le "$DL_RETRIES" ]; do
    if command -v aria2c >/dev/null 2>&1; then
      if aria2c -c -x16 -s16 -k1M \
                --file-allocation=none --allow-overwrite=true --auto-file-renaming=false \
                --max-tries=3 --retry-wait=10 --timeout=60 \
                --console-log-level=warn --summary-interval=60 \
                -d "$dir" -o "$name.part" "$url"; then ok=1; break; fi
    else
      if wget -c --tries=3 --waitretry=10 --read-timeout=60 \
              --show-progress -q -O "$part" "$url"; then ok=1; break; fi
    fi
    echo "    … 실패, 재시도 $try/$DL_RETRIES (받은 부분은 유지)"
    try=$((try + 1))
    sleep 10
  done

  if [ "$ok" -ne 1 ]; then
    echo "  ! 미완료: $name"
    echo "    받은 부분을 $part 에 남겨뒀습니다. 스크립트를 다시 실행하면 이어받습니다."
    return 1
  fi

  # HTML 오류 페이지를 받으면 크기가 확 작다. 조용히 넘기지 않는다.
  if [ "$(stat -c%s "$part")" -lt 100000 ]; then
    rm -f "$part"
    echo "  ! 크기 이상 — URL 확인 필요: $name"
    return 1
  fi

  mv "$part" "$dest"
  rm -f "$dir/$name.part.aria2"
}

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
echo "완료. 파드를 Restart 해야 yaml이 적용됩니다."
echo "공통: DWPose(torchscript) / DepthAnythingV2(vitl)"
echo "      깊이맵은 가까울수록 밝음. Blender Z pass는 반대로 나오기 쉽습니다."
echo "데이터셋: $PROJ/dataset/{raw,keep,caption}"
if [ -n "$SDXL" ]; then
  echo "SDXL: IPAdapter(ViT-H) — base 와 plus 두 개."
  echo "      base=ip-adapter_sdxl_vit-h(무난), plus=ip-adapter-plus_sdxl_vit-h(강함)."
  echo "      clip_vision 은 CLIP-ViT-H-14 하나만 쓴다. weight 0.6~0.8 부터 시작."
else
  echo "SDXL 프로필이 없어 IPAdapter·clip_vision(약 4GB)은 건너뛰었습니다."
fi
printf "%s" "$HINT"
echo "남은 디스크: $(df -h /workspace | awk 'NR==2 {print $4}')"
