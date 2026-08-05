#!/bin/bash
set -e

# ── 환경 ──────────────────────────────────
# 템플릿: RunPod ComfyUI (runpod-slim), CUDA 12.8
# 파드는 작업 후 매번 terminate. 네트워크 볼륨 없음.
# 따라서 모든 실물 파일은 파드마다 재다운로드되고,
# 유지되어야 하는 설정은 전부 이 스크립트와 $REPO 안에 있어야 한다.
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

echo "[1/9] git 설정"
git config --global user.email "odineyes2@gmail.com"
git config --global user.name "odineyes2"
git config --global credential.helper 'cache --timeout=36000'
echo "git 설정 완료. 최초 로그인 후 10시간 동안 아이디와 PAT를 요구하지 않습니다."

echo "[2/9] 폴더 생성"
mkdir -p $BASE/{checkpoints,loras,vae,controlnet,upscale_models,clip_vision,embeddings,wd14_tagger}
mkdir -p $PROJ/output_keep

echo "[3/9] 모델 경로 설정"
cp $REPO/extra_model_paths.yaml $COMFY/

echo "[4/9] 워크플로우 배치"
mkdir -p $COMFY/user/default/workflows
cp -n $REPO/workflows/*.json $COMFY/user/default/workflows/ 2>/dev/null || true

echo "[5/9] 커스텀 노드 설치"
mkdir -p $NODES
cd $NODES

# 디렉터리명|저장소|서브모듈 필요 여부
NODE_REPOS=(
  "ComfyUI_UltimateSDUpscale|https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git|yes"
  "ComfyUI-Inpaint-CropAndStitch|https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git|no"
  "ComfyUI-WD14-Tagger|https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git|no"
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

echo "[6/9] WD14 태거 기본값 패치"
# pysssss.json은 클론한 저장소 안에 있어서 파드를 버리면 초기화된다.
# 기본값은 구형 moat-v2 + replace_underscore 꺼짐 상태이므로 매번 덮어쓴다.
# models 딕셔너리는 건드리지 않고 settings만 병합 (업스트림 모델 목록 갱신 반영).
TAGGER_CFG=$NODES/ComfyUI-WD14-Tagger/pysssss.json
if [ -f "$TAGGER_CFG" ]; then
  "$PY" - "$TAGGER_CFG" << 'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)
cfg.setdefault("settings", {}).update({
    "model": "wd-swinv2-tagger-v3",
    "threshold": 0.35,
    "character_threshold": 0.85,
    "replace_underscore": True,
    "exclude_tags": "watermark, signature, artist name, web address, username",
})
with open(path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
PYEOF
  echo "  - 우클릭 태깅 기본값: wd-swinv2-tagger-v3 / replace_underscore on"
else
  echo "  ! pysssss.json 없음, 건너뜀"
fi

echo "[7/9] 체크포인트 다운로드"
cd $BASE/checkpoints
CKPT=WAI-illustrious-SDXL.safetensors
if [ -s "$CKPT" ] && [ "$(stat -c%s "$CKPT")" -gt 1000000000 ]; then
  echo "  - $CKPT 있음, 건너뜀"
else
  wget -O "$CKPT.part" "https://civitai.red/api/download/models/2883731?fileId=2763986" \
    && mv "$CKPT.part" "$CKPT" \
    || { echo "체크포인트 다운로드 실패"; rm -f "$CKPT.part"; exit 1; }
fi

echo "[8/9] 업스케일 모델 다운로드"
cd $BASE/upscale_models
UPS=4x-AnimeSharp.pth
if [ -s "$UPS" ]; then
  echo "  - $UPS 있음, 건너뜀"
else
  wget -O "$UPS" \
    "https://huggingface.co/Kim2091/AnimeSharp/resolve/main/4x-AnimeSharp.pth"
fi

echo "[9/9] WD14 태거 모델 다운로드"
# 런타임 자동 다운로드도 되지만, 첫 태깅 때 작업이 멈추는 걸 피하려고 미리 받는다.
# .onnx / .csv 두 파일 이름이 모델명과 같아야 노드가 로컬 모델로 인식한다.
cd $BASE/wd14_tagger
TAGGER=wd-swinv2-tagger-v3
if [ -s "$TAGGER.onnx" ] && [ -s "$TAGGER.csv" ]; then
  echo "  - $TAGGER 있음, 건너뜀"
else
  wget -O "$TAGGER.onnx.part" \
    "https://huggingface.co/SmilingWolf/$TAGGER/resolve/main/model.onnx" \
    && mv "$TAGGER.onnx.part" "$TAGGER.onnx" \
    || { echo "태거 모델 다운로드 실패"; rm -f "$TAGGER.onnx.part"; exit 1; }
  wget -O "$TAGGER.csv" \
    "https://huggingface.co/SmilingWolf/$TAGGER/resolve/main/selected_tags.csv"
fi

echo ""
echo "완료. RunPod 콘솔에서 파드를 Restart 해야 yaml이 적용됩니다."
