#!/bin/bash
set -e

# RunPod ComfyUI (runpod-slim), CUDA 12.8. 파드는 매번 terminate.
# 유지할 설정은 전부 이 스크립트와 $REPO 안에 있어야 한다.

COMFY=/workspace/runpod-slim/ComfyUI
BASE=/workspace/shared_models
PROJ=/workspace/project_lomebrote
REPO=/workspace/lomebrote
NODES=$COMFY/custom_nodes

PY=""
for c in /workspace/runpod-slim/venv/bin/python /workspace/venv/bin/python $COMFY/venv/bin/python; do
  [ -x "$c" ] && PY="$c" && break
done
[ -z "$PY" ] && PY="$(command -v python3)"


# ── 받을 파일: 저장폴더|파일명|URL ──────────────────
# 필요 없으면 줄을 지우거나 앞에 #을 붙인다.

FILES=(
  "$BASE/checkpoints|WAI-illustrious-SDXL.safetensors|https://civitai.red/api/download/models/2883731?fileId=2763986"
  # "$BASE/checkpoints|Illustrious-XL-v1.1.safetensors|https://huggingface.co/OnomaAIResearch/Illustrious-XL-v1.1/resolve/main/Illustrious-XL-v1.1.safetensors"
  # "$BASE/checkpoints|Illustrious-XL-v2.0.safetensors|https://huggingface.co/OnomaAIResearch/Illustrious-XL-v2.0/resolve/main/Illustrious-XL-v2.0.safetensors"

  "$BASE/upscale_models|4x-AnimeSharp.pth|https://huggingface.co/Kim2091/AnimeSharp/resolve/main/4x-AnimeSharp.pth"

  # 태거는 .onnx/.csv 파일명이 모델명과 같아야 노드가 로컬 파일로 인식한다.
  "$BASE/wd14_tagger|wd-swinv2-tagger-v3.onnx|https://huggingface.co/SmilingWolf/wd-swinv2-tagger-v3/resolve/main/model.onnx"
  "$BASE/wd14_tagger|wd-swinv2-tagger-v3.csv|https://huggingface.co/SmilingWolf/wd-swinv2-tagger-v3/resolve/main/selected_tags.csv"

  # ControlNet은 계열을 맞춰야 색이 안 탁해진다. 범용 SDXL(xinsir 등) 쓰지 말 것.
  "$BASE/controlnet|Illustrious_openpose.safetensors|https://huggingface.co/windsingai/openpose/resolve/main/openpose_s6000.safetensors"
  "$BASE/controlnet|NoobAI_depth_midas.safetensors|https://huggingface.co/Eugeoter/noob-sdxl-controlnet-depth_midas-v1-1/resolve/main/diffusion_pytorch_model.fp16.safetensors"
  # "$BASE/controlnet|Illustrious_depth_umeairt.safetensors|https://huggingface.co/UmeAiRT/ComfyUI-Auto-Installer-Assets/resolve/main/models/controlnet/illustrious-xl-depth.safetensors"

  # 전처리기 가중치. 폴더가 <HF 저장소명> 구조여야 노드가 찾는다.
  "$BASE/controlnet_aux/hr16/yolox-onnx|yolox_l.torchscript.pt|https://huggingface.co/hr16/yolox-onnx/resolve/main/yolox_l.torchscript.pt"
  "$BASE/controlnet_aux/hr16/DWPose-TorchScript-BatchSize5|dw-ll_ucoco_384_bs5.torchscript.pt|https://huggingface.co/hr16/DWPose-TorchScript-BatchSize5/resolve/main/dw-ll_ucoco_384_bs5.torchscript.pt"
  "$BASE/controlnet_aux/yzd-v/DWPose|yolox_l.onnx|https://huggingface.co/yzd-v/DWPose/resolve/main/yolox_l.onnx"
  "$BASE/controlnet_aux/depth-anything/Depth-Anything-V2-Large|depth_anything_v2_vitl.pth|https://huggingface.co/depth-anything/Depth-Anything-V2-Large/resolve/main/depth_anything_v2_vitl.pth"
)

# 커스텀 노드: 폴더명|저장소|서브모듈 여부
NODE_REPOS=(
  "ComfyUI_UltimateSDUpscale|https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git|yes"
  "ComfyUI-Inpaint-CropAndStitch|https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git|no"
  "ComfyUI-WD14-Tagger|https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git|no"
  "comfyui_controlnet_aux|https://github.com/Fannovel16/comfyui_controlnet_aux.git|no"
)

# ──────────────────────────────────────────────────

echo "python: $PY / 디스크: $(df -h /workspace | awk 'NR==2 {print $4}')"

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

# Depth 비교 세션에서만 (NoobAI depth_midas와 전처리기를 맞출 때):
# HF_HOME=$BASE/hf_cache "$PY" -c "from huggingface_hub import snapshot_download as d; d('Intel/dpt-hybrid-midas')"

echo ""
echo "완료. 파드를 Restart 해야 yaml이 적용됩니다."
echo "포즈: DWPose(torchscript) + Illustrious_openpose, strength 1.0 / end 0.4"
echo "깊이: DepthAnythingV2(vitl) + NoobAI_depth_midas, end 0.8 근처에서 탐색"
echo "      깊이맵은 가까울수록 밝음. Blender Z pass는 반대로 나오기 쉬움."
