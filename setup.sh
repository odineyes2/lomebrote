#!/bin/bash
set -e

# RunPod ComfyUI (runpod-slim), CUDA 12.8. 파드는 매번 terminate.
#
# 사용법: ./setup.sh <프로필...>
#   ./setup.sh real          실사
#   ./setup.sh anime         애니 (Illustrious 공식 베이스)
#   ./setup.sh nsfw          애니 NSFW (WAI)
#   ./setup.sh anime nsfw    둘 다. 겹치는 파일은 한 번만 받는다.

COMFY=/workspace/runpod-slim/ComfyUI
BASE=/workspace/shared_models
PROJ=/workspace/project_lomebrote
REPO=/workspace/lomebrote
NODES=$COMFY/custom_nodes
SELF="$(cd "$(dirname "$0")" && pwd)"

PY=""
for c in /workspace/runpod-slim/venv/bin/python /workspace/venv/bin/python $COMFY/venv/bin/python; do
  [ -x "$c" ] && PY="$c" && break
done
[ -z "$PY" ] && PY="$(command -v python3)"

# ── 프로필 로드 ────────────────────────────────────
# 프로필은 FILES 에 항목을 덧붙이고, HINT 에 안내문을 넣는다.

if [ $# -eq 0 ]; then
  echo "사용법: ./setup.sh <프로필...>"
  echo "사용 가능:"
  for f in "$SELF"/profiles/*.sh; do echo "  $(basename "${f%.sh}")"; done
  exit 1
fi

# 공통: 전처리기 가중치. 폴더가 <HF 저장소명> 구조여야 노드가 찾는다.
FILES=(
  "$BASE/controlnet_aux/hr16/yolox-onnx|yolox_l.torchscript.pt|https://huggingface.co/hr16/yolox-onnx/resolve/main/yolox_l.torchscript.pt"
  "$BASE/controlnet_aux/hr16/DWPose-TorchScript-BatchSize5|dw-ll_ucoco_384_bs5.torchscript.pt|https://huggingface.co/hr16/DWPose-TorchScript-BatchSize5/resolve/main/dw-ll_ucoco_384_bs5.torchscript.pt"
  "$BASE/controlnet_aux/yzd-v/DWPose|yolox_l.onnx|https://huggingface.co/yzd-v/DWPose/resolve/main/yolox_l.onnx"
  "$BASE/controlnet_aux/depth-anything/Depth-Anything-V2-Large|depth_anything_v2_vitl.pth|https://huggingface.co/depth-anything/Depth-Anything-V2-Large/resolve/main/depth_anything_v2_vitl.pth"
)
HINT=""

for p in "$@"; do
  f="$SELF/profiles/$p.sh"
  [ -f "$f" ] || { echo "없는 프로필: $p"; exit 1; }
  source "$f"
done

# 커스텀 노드: 폴더명|저장소|서브모듈 여부
NODE_REPOS=(
  "ComfyUI_UltimateSDUpscale|https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git|yes"
  "ComfyUI-Inpaint-CropAndStitch|https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git|no"
  "ComfyUI-WD14-Tagger|https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git|no"
  "comfyui_controlnet_aux|https://github.com/Fannovel16/comfyui_controlnet_aux.git|no"
  # XY Plot, KSampler (Efficient), Efficient Loader.
  # 원저작자(LucianoCirino) 저장소는 관리 중단. jags111 포크가 유지판이다.
  "efficiency-nodes-comfyui|https://github.com/jags111/efficiency-nodes-comfyui.git|no"
)

# ──────────────────────────────────────────────────

echo "프로필: $* / python: $PY / 디스크: $(df -h /workspace | awk 'NR==2 {print $4}')"

echo "[1/5] git"
git config --global user.email "odineyes2@gmail.com"
git config --global user.name "odineyes2"
git config --global credential.helper 'cache --timeout=36000'

echo "[2/5] 폴더 · 설정"
mkdir -p $BASE/{checkpoints,loras,vae,controlnet,upscale_models,clip_vision,embeddings,wd14_tagger,controlnet_aux}
mkdir -p $PROJ/{output_keep,depthmaps}
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
CFG=$NODES/ComfyUI-WD14-Tagger/pysssss.json
[ -f "$CFG" ] && "$PY" - "$CFG" << 'PYEOF'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
c.setdefault("settings", {}).update({
    "model": "wd-swinv2-tagger-v3", "threshold": 0.35,
    "character_threshold": 0.85, "replace_underscore": True,
    "exclude_tags": "watermark, signature, artist name, web address, username",
})
json.dump(c, open(p, "w"), indent=2, ensure_ascii=False)
PYEOF

echo "[5/5] 파일 다운로드"
for e in "${FILES[@]}"; do
  IFS='|' read -r dir name url <<< "$e"
  dest="$dir/$name"
  if [ -s "$dest" ] && [ "$(stat -c%s "$dest")" -gt 100000 ]; then
    echo "  = $name"
    continue
  fi
  echo "  + $name"
  mkdir -p "$dir"
  wget -q --show-progress -O "$dest.part" "$url" \
    || { rm -f "$dest.part"; echo "  ! 다운로드 실패: $name"; exit 1; }
  # HTML 오류 페이지를 받으면 크기가 확 작다. 조용히 넘기지 않는다.
  if [ "$(stat -c%s "$dest.part")" -lt 100000 ]; then
    rm -f "$dest.part"; echo "  ! 크기 이상 — URL 확인 필요: $name"; exit 1
  fi
  mv "$dest.part" "$dest"
done

echo ""
echo "완료. 파드를 Restart 해야 yaml이 적용됩니다."
echo "공통: DWPose(torchscript) / DepthAnythingV2(vitl)"
echo "      깊이맵은 가까울수록 밝음. Blender Z pass는 반대로 나오기 쉬움."
printf "%s" "$HINT"
