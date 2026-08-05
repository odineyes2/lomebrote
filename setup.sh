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

echo "[1/6] 폴더 생성"
mkdir -p $BASE/{checkpoints,loras,vae,controlnet,upscale_models,clip_vision,embeddings}
mkdir -p $PROJ/{workflows,output_keep,output_dump,reference}

echo "[2/6] 모델 경로 설정"
cp $REPO/extra_model_paths.yaml $COMFY/

echo "[3/6] 워크플로우 배치"
mkdir -p $COMFY/user/default/workflows
cp -n $REPO/workflows/*.json $COMFY/user/default/workflows/ 2>/dev/null || true

echo "[4/6] 커스텀 노드 설치"
mkdir -p $NODES
cd $NODES

# UltimateSDUpscale: 실제 업스케일 로직이 git 서브모듈에 있음.
# --recursive 없이 받으면 노드가 로드되지 않음.
if [ -d ComfyUI_UltimateSDUpscale/.git ]; then
  echo "  - UltimateSDUpscale 이미 존재, 서브모듈만 점검"
  git -C ComfyUI_UltimateSDUpscale submodule update --init --recursive
else
  echo "  - UltimateSDUpscale 클론"
  git clone --recursive \
    https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git
fi

# requirements.txt가 있는 노드만 의존성 설치
for req in $NODES/*/requirements.txt; do
  [ -f "$req" ] || continue
  echo "  - pip install: $(basename $(dirname $req))"
  "$PY" -m pip install -q -r "$req"
done

echo "[5/6] 체크포인트 다운로드"
cd $BASE/checkpoints
CKPT=WAI-illustrious-SDXL.safetensors
if [ -s "$CKPT" ]; then
  echo "  - $CKPT 있음, 건너뜀"
else
  wget -O "$CKPT" \
    "https://civitai.red/api/download/models/2883731?fileId=2763986"
fi

echo "[6/6] 업스케일 모델 다운로드"
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
