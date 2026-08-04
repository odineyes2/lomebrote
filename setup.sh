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
PROJ=/workspace/project_lombrote
REPO=/workspace/lomebrote

echo "[1/4] 폴더 생성"
mkdir -p $BASE/{checkpoints,loras,vae,controlnet,upscale_models,clip_vision,embeddings}
mkdir -p $PROJ/{workflows,output_keep,output_dump,reference}

echo "[2/4] 모델 경로 설정"
cp $REPO/extra_model_paths.yaml $COMFY/

echo "[3/4] 워크플로우 배치"
mkdir -p $COMFY/user/default/workflows
cp -n $REPO/workflows/*.json $COMFY/user/default/workflows/ 2>/dev/null || true

echo "[4/4] 모델 다운로드"
cd $BASE/checkpoints
wget -nc -O WAI-illustrious-SDXL.safetensors \
  "https://civitai.red/api/download/models/2883731?fileId=2763986"

echo ""
echo "완료. RunPod 콘솔에서 파드를 Restart 해야 yaml이 적용됩니다."