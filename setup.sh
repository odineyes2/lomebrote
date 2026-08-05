#!/bin/bash
set -e

# ── 환경 ──────────────────────────────────
# 템플릿: RunPod ComfyUI (runpod-slim), CUDA 12.8
# CUDA 13이 아닌 12.8을 쓰는 이유:
#   - Ampere/Ada 세대는 cu130으로 얻는 성능 이득이 없음
#   - 커스텀 노드 상당수가 아직 cu130 호환 안 됨
# ──────────────────────────────────────────

COMFY=/workspace/runpod-slim/ComfyUI
BASE=/workspace/shared_models
PROJ=/workspace/project_lomebrote
REPO=/workspace/lomebrote
NODES=$COMFY/custom_nodes

# venv 파이썬 자동 탐색 (없으면 시스템 python3)
PY=""
for c in /workspace/runpod-slim/venv/bin/python \
         /workspace/venv/bin/python \
         $COMFY/venv/bin/python; do
  [ -x "$c" ] && PY="$c" && break
done
[ -z "$PY" ] && PY="$(command -v python3)"
echo "python: $PY"

echo "[1/7] git 설정"
git config --global user.email "odineyes2@gmail.com"
git config --global user.name "odineyes2"
git config --global credential.helper 'cache --timeout=36000'
echo "git 설정 완료. 최초 로그인 후 10시간 동안 아이디와 PAT를 요구하지 않습니다."

echo "[2/7] 폴더 생성"
mkdir -p $BASE/{checkpoints,loras,vae,controlnet,upscale_models,clip_vision,embeddings}
mkdir -p $PROJ/output_keep

echo "[3/7] 모델 경로 설정"
cp $REPO/extra_model_paths.yaml $COMFY/

echo "[4/7] 워크플로우 배치"
mkdir -p $COMFY/user/default/workflows
cp -n $REPO/workflows/*.json $COMFY/user/default/workflows/ 2>/dev/null || true

echo "[5/7] 커스텀 노드 설치"
mkdir -p $NODES
cd $NODES

# 디렉터리명|저장소|서브모듈 필요 여부
NODE_REPOS=(
  "ComfyUI_UltimateSDUpscale|https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git|yes"
  "ComfyUI-Inpaint-CropAndStitch|https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git|no"
)

for entry in "${NODE_REPOS[@]}"; do
  IFS='|' read -r dir url rec <<< "$entry"
  if [ -d "$dir/.git" ]; then
    echo "  - $dir 이미 존재"
    if [ "$rec" = "yes" ]; then
      git -C "$dir" submodule update --init --recursive
    fi
  else
    echo "  - $dir 클론"
    if [ "$rec" = "yes" ]; then
      git clone --recursive "$url"
    else
      git clone "$url"
    fi
  fi
done

# requirements.txt가 있는 노드만 의존성 설치
for req in $NODES/*/requirements.txt; do
  [ -f "$req" ] || continue
  echo "  - pip install: $(basename $(dirname $req))"
  "$PY" -m pip install -q -r "$req"
done

echo "[6/7] 체크포인트 다운로드"
cd $BASE/checkpoints
CKPT=WAI-illustrious-SDXL.safetensors
if [ -s "$CKPT" ] && [ "$(stat -c%s "$CKPT")" -gt 1000000000 ]; then
  echo "  - $CKPT 있음, 건너뜀"
else
  wget -O "$CKPT.part" "https://civitai.red/api/download/models/2883731?fileId=2763986" \
    && mv "$CKPT.part" "$CKPT" \
    || { echo "체크포인트 다운로드 실패"; rm -f "$CKPT.part"; exit 1; }
fi

echo "[7/7] 업스케일 모델 다운로드"
cd $BASE/upscale_models
UPS=4x-AnimeSharp.pth
if [ -s "$UPS" ]; then
  echo "  - $UPS 있음, 건너뜀"
else
  wget -O "$UPS" \
    "https://huggingface.co/Kim2091/AnimeSharp/resolve/main/4x-AnimeSharp.pth"
fi

echo ""
echo "완료. RunPod 콘솔에서 파드를 Restart 해야 yaml이 적용됩니다."
