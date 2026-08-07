#!/bin/bash
set -e

# ── 환경 ──────────────────────────────────
# 템플릿: RunPod ComfyUI (runpod-slim), CUDA 12.8
# 파드는 작업 후 매번 terminate. 네트워크 볼륨 없음.
# 따라서 모든 실물 파일은 파드마다 재다운로드되고,
# 유지되어야 하는 설정은 전부 이 스크립트와 $REPO 안에 있어야 한다.
#
# 사용법:
#   ./setup.sh              평소. 확정된 모델만 받는다.
#                           체크포인트는 WAI + Illustrious XL v1.1 두 개 (약 14GB).
#   DEPTH_AB=1 ./setup.sh   Depth ControlNet 비교 세션용.
#                           후보 모델과 MiDaS 전처리기까지 추가로 받는다(+8GB, 시간 소요).
#                           승자를 정한 뒤에는 CN_FILES에 고정하고 이 스위치는 다시 끈다.
#   ILXL_V2=1 ./setup.sh    Illustrious XL v2.0(STABLE)까지 받는다(+7GB).
#                           v1.1과 성격이 꽤 달라서 비교해볼 때만 켠다.
#                           상시로 쓰기로 정하면 CKPT_FILES에 고정하고 스위치는 끈다.
# ──────────────────────────────────────────

COMFY=/workspace/runpod-slim/ComfyUI
BASE=/workspace/shared_models
PROJ=/workspace/project_lomebrote
REPO=/workspace/lomebrote
NODES=$COMFY/custom_nodes

DEPTH_AB="${DEPTH_AB:-0}"
ILXL_V2="${ILXL_V2:-0}"

# venv 파이썬 자동 탐색 (없으면 시스템 python3)
PY=""
for c in /workspace/runpod-slim/venv/bin/python \
         /workspace/venv/bin/python \
         $COMFY/venv/bin/python; do
  [ -x "$c" ] && PY="$c" && break
done
[ -z "$PY" ] && PY="$(command -v python3)"
echo "python: $PY"

# 모델 총량이 늘어나 디스크가 먼저 터지는 일이 잦다. 시작 시 남은 용량을 보여준다.
echo "디스크 여유: $(df -h /workspace | awk 'NR==2 {print $4}')"
[ "$DEPTH_AB" = "1" ] && echo "※ DEPTH_AB=1 — Depth 비교용 모델까지 받습니다 (추가 약 8GB)"
[ "$ILXL_V2" = "1" ] && echo "※ ILXL_V2=1 — Illustrious XL v2.0까지 받습니다 (추가 약 7GB)"

echo "[1/12] git 설정"
git config --global user.email "odineyes2@gmail.com"
git config --global user.name "odineyes2"
git config --global credential.helper 'cache --timeout=36000'
echo "git 설정 완료. 최초 로그인 후 10시간 동안 아이디와 PAT를 요구하지 않습니다."

echo "[2/12] 폴더 생성"
mkdir -p $BASE/{checkpoints,loras,vae,controlnet,upscale_models,clip_vision,embeddings,wd14_tagger}
mkdir -p $BASE/controlnet_aux   # DWPose, Depth Anything 등 전처리기 가중치
mkdir -p $PROJ/output_keep
mkdir -p $PROJ/depthmaps        # Blender 블록아웃 렌더 / 수동 깊이맵 반입용

echo "[3/12] 모델 경로 설정"
cp $REPO/extra_model_paths.yaml $COMFY/

echo "[4/12] 워크플로우 배치"
mkdir -p $COMFY/user/default/workflows
cp -n $REPO/workflows/*.json $COMFY/user/default/workflows/ 2>/dev/null || true

echo "[5/12] 커스텀 노드 설치"
mkdir -p $NODES
cd $NODES

# 디렉터리명|저장소|서브모듈 필요 여부
NODE_REPOS=(
  "ComfyUI_UltimateSDUpscale|https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git|yes"
  "ComfyUI-Inpaint-CropAndStitch|https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git|no"
  "ComfyUI-WD14-Tagger|https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git|no"
  "comfyui_controlnet_aux|https://github.com/Fannovel16/comfyui_controlnet_aux.git|no"
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

echo "[6/12] controlnet_aux 설정"
# 전처리기 가중치 기본 저장 위치가 노드 폴더 안(./ckpts)이라 노드를 다시 클론하면 같이 날아간다.
# annotator_ckpts_path를 $BASE로 빼서 다른 모델들과 같은 곳에 모아둔다.
# EP_list를 CPU만 남긴 이유: onnxruntime-gpu는 CUDA 12에서 별도 인덱스가 필요해 설치가 번거롭다.
# 대신 노드에서 .torchscript.pt 계열을 고르면 torch가 알아서 GPU를 쓴다 (아래 12단계에서 미리 받음).
#
# 주의: 이 설정은 custom_hf_download를 타는 전처리기에만 적용된다.
#       DWPose, Depth Anything V2 → 적용됨 ($BASE/controlnet_aux 아래로 떨어짐)
#       MiDaS → 적용 안 됨. transformers로 Intel/dpt-hybrid-midas를 직접 부르므로
#               ~/.cache/huggingface 로 간다 (12단계 DEPTH_AB 블록에서 별도 처리).
cat > $NODES/comfyui_controlnet_aux/config.yaml << YAMLEOF
annotator_ckpts_path: "$BASE/controlnet_aux"
custom_temp_path:
USE_SYMLINKS: False
EP_list: ["CPUExecutionProvider"]
YAMLEOF
echo "  - 전처리기 가중치 경로: $BASE/controlnet_aux"

echo "[7/12] WD14 태거 기본값 패치"
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

echo "[8/12] 체크포인트 다운로드"
# WAI는 미소녀/NSFW 방향으로 강하게 파인튜닝된 머지라 프롬프트를 자주 덮어쓴다.
# 프롬프트 반응을 통제된 조건에서 확인하려면 편향이 덜한 베이스가 하나 더 필요하다.
# 그래서 OnomaAI 공식 베이스(Illustrious XL)를 같이 받아두고 노드에서 골라 쓴다.
#
# 계열이 같은 SDXL이라 ControlNet / VAE / 업스케일러는 그대로 호환된다.
# 다만 LoRA는 대부분 v0.1 기반으로 학습돼 있어서, v1.1/v2.0에 얹으면
# 강도가 약해지거나 화풍이 어긋날 수 있다. 필요하면 strength를 올려서 보정.
#
# 저장 파일명|URL|최소 바이트(무결성 확인용)
CKPT_FILES=(
  "WAI-illustrious-SDXL.safetensors|https://civitai.red/api/download/models/2883731?fileId=2763986|1000000000"
  # Illustrious XL v1.1 — OnomaAI 공식. v1.0의 후속 안정판이고 공식 org에 올라와 있어
  #                       서드파티 미러를 타는 v1.0보다 이쪽이 낫다. 6.94GB.
  "Illustrious-XL-v1.1.safetensors|https://huggingface.co/OnomaAIResearch/Illustrious-XL-v1.1/resolve/main/Illustrious-XL-v1.1.safetensors|6000000000"
)

# v2.0은 성격이 꽤 달라서(아래 주석 참고) 비교 세션에서만 받는다.
if [ "$ILXL_V2" = "1" ]; then
  CKPT_FILES+=(
    # v2.0 저장소의 main 파일이 곧 STABLE 판이다 (annealing 마지막 단계 체크포인트).
    # 자연어 프롬프트 대응이 늘어난 대신 태그 반응이 v1.x와 달라서, 기존 프롬프트를
    # 그대로 옮기면 결과가 어긋난다. 같은 시드로 비교부터 해볼 것.
    "Illustrious-XL-v2.0.safetensors|https://huggingface.co/OnomaAIResearch/Illustrious-XL-v2.0/resolve/main/Illustrious-XL-v2.0.safetensors|6000000000"
  )
fi

cd $BASE/checkpoints
for entry in "${CKPT_FILES[@]}"; do
  IFS='|' read -r fname url minsize <<< "$entry"
  if [ -s "$fname" ] && [ "$(stat -c%s "$fname")" -gt "$minsize" ]; then
    echo "  - $fname 있음, 건너뜀"
  else
    echo "  - $fname 받는 중"
    wget -q --show-progress -O "$fname.part" "$url" \
      && mv "$fname.part" "$fname" \
      || { echo "$fname 다운로드 실패"; rm -f "$fname.part"; exit 1; }
    # HF 게이팅이나 URL 오류로 HTML 페이지를 받으면 크기가 확 작아진다. 조용히 넘기지 않는다.
    if [ "$(stat -c%s "$fname")" -lt "$minsize" ]; then
      echo "  ! $fname 크기 이상 ($(stat -c%s "$fname") 바이트)."
      echo "    HF 저장소가 동의(gated)를 요구하면 웹에서 한 번 수락한 뒤"
      echo "    wget에 --header=\"Authorization: Bearer <HF_TOKEN>\" 를 붙여야 합니다."
      rm -f "$fname"; exit 1
    fi
  fi
done

echo "[9/12] 업스케일 모델 다운로드"
cd $BASE/upscale_models
UPS=4x-AnimeSharp.pth
if [ -s "$UPS" ]; then
  echo "  - $UPS 있음, 건너뜀"
else
  wget -O "$UPS" \
    "https://huggingface.co/Kim2091/AnimeSharp/resolve/main/4x-AnimeSharp.pth"
fi

echo "[10/12] WD14 태거 모델 다운로드"
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

echo "[11/12] ControlNet 본체 다운로드"
# WAI-illustrious-SDXL은 Illustrious 계열이라 범용 SDXL ControlNet(xinsir 등)을 쓰면
# 포즈는 잡히지만 색이 탁해지고 화풍이 흐트러진다. 계열을 맞춘 걸 쓴다.
#
# 저장 파일명|URL|최소 바이트(무결성 확인용)
CN_FILES=(
  # openpose: Civitai "Illustrious-XL ControlNet Openpose"와 동일 파일 (sha256 0d8bacf2...)
  "Illustrious_openpose.safetensors|https://huggingface.co/windsingai/openpose/resolve/main/openpose_s6000.safetensors|2000000000"
  # depth: windsingai는 pose/tile만 냈고 depth를 안 냈다.
  #        NoobAI는 Illustrious 사촌 계열이라 범용 SDXL보다 화풍 궁합이 낫다는 판단.
  #        fp16(2.5GB)로 받는다. 화질 문제가 보이면 diffusion_pytorch_model.safetensors(5GB)로 교체.
  "NoobAI_depth_midas.safetensors|https://huggingface.co/Eugeoter/noob-sdxl-controlnet-depth_midas-v1-1/resolve/main/diffusion_pytorch_model.fp16.safetensors|2000000000"
)

# 비교 세션에서만 받는 후보들
if [ "$DEPTH_AB" = "1" ]; then
  CN_FILES+=(
    "Illustrious_depth_umeairt.safetensors|https://huggingface.co/UmeAiRT/ComfyUI-Auto-Installer-Assets/resolve/main/models/controlnet/illustrious-xl-depth.safetensors|4000000000"
  )
fi

cd $BASE/controlnet
for entry in "${CN_FILES[@]}"; do
  IFS='|' read -r fname url minsize <<< "$entry"
  if [ -s "$fname" ] && [ "$(stat -c%s "$fname")" -gt "$minsize" ]; then
    echo "  - $fname 있음, 건너뜀"
  else
    echo "  - $fname 받는 중"
    wget -q --show-progress -O "$fname.part" "$url" \
      && mv "$fname.part" "$fname" \
      || { echo "$fname 다운로드 실패"; rm -f "$fname.part"; exit 1; }
    # 받았는데 크기가 안 맞으면 HTML 오류 페이지를 받은 것이다. 조용히 넘어가면 안 된다.
    if [ "$(stat -c%s "$fname")" -lt "$minsize" ]; then
      echo "  ! $fname 크기 이상 ($(stat -c%s "$fname") 바이트). URL을 확인하세요."
      rm -f "$fname"; exit 1
    fi
  fi
done

echo "[12/12] 전처리기 가중치 다운로드"
# 안 받아두면 첫 추출 때 런타임 다운로드로 몇 분간 멈춘다.
# 저장 경로는 <ckpts>/<HF 저장소명>/<파일명> 구조를 그대로 지켜야 노드가 로컬 파일로 인식한다.
# 저장소|파일명
AUX_FILES=(
  # DWPose (골격)
  "hr16/yolox-onnx|yolox_l.torchscript.pt"
  "hr16/DWPose-TorchScript-BatchSize5|dw-ll_ucoco_384_bs5.torchscript.pt"
  "yzd-v/DWPose|yolox_l.onnx"
  # Depth Anything V2 (깊이). vitl = 1.3GB. 순수 torch라 onnxruntime EP 설정과 무관하게 GPU를 쓴다.
  # 노드 ckpt_name 기본값도 vitl이라 그대로 두면 된다. 더 가볍게 가려면 vitb/vits로 교체 가능.
  "depth-anything/Depth-Anything-V2-Large|depth_anything_v2_vitl.pth"
)

for entry in "${AUX_FILES[@]}"; do
  IFS='|' read -r repo fname <<< "$entry"
  dest="$BASE/controlnet_aux/$repo"
  mkdir -p "$dest"
  if [ -s "$dest/$fname" ]; then
    echo "  - $fname 있음, 건너뜀"
  else
    echo "  - $fname 받는 중"
    wget -q --show-progress -O "$dest/$fname.part" \
      "https://huggingface.co/$repo/resolve/main/$fname" \
      && mv "$dest/$fname.part" "$dest/$fname" \
      || { echo "$fname 다운로드 실패"; rm -f "$dest/$fname.part"; exit 1; }
  fi
done

# MiDaS는 위 경로 규칙을 안 따른다. transformers가 HF 캐시로 직접 받으므로
# annotator_ckpts_path와 무관하게 ~/.cache/huggingface 로 간다.
# 평소엔 불필요하고, NoobAI depth_midas 모델과 전처리기를 맞춰볼 때만 미리 캐싱한다.
if [ "$DEPTH_AB" = "1" ]; then
  echo "  - MiDaS(Intel/dpt-hybrid-midas) 사전 캐싱"
  "$PY" - << 'PYEOF'
try:
    from huggingface_hub import snapshot_download
    p = snapshot_download("Intel/dpt-hybrid-midas")
    print(f"    캐시 위치: {p}")
except Exception as e:
    print(f"    ! MiDaS 캐싱 실패(건너뜀): {e}")
PYEOF
fi

echo ""
echo "완료. RunPod 콘솔에서 파드를 Restart 해야 yaml이 적용됩니다."
echo ""
echo "[체크포인트] Load Checkpoint 노드에서 골라 씁니다."
echo "        WAI-illustrious-SDXL      화풍 완성도는 높지만 프롬프트를 자주 덮어씀"
echo "        Illustrious-XL-v1.1       공식 베이스. 밋밋하지만 프롬프트에 정직함"
[ "$ILXL_V2" = "1" ] && \
echo "        Illustrious-XL-v2.0       태그 반응이 v1.x와 다름. 같은 시드로 비교할 것"
echo "        CFG 4~7 / steps 28~32 / Euler a 또는 DPM++ 2M Karras 부터 시작."
echo ""
echo "[포즈]  DWPose: bbox_detector=yolox_l.torchscript.pt,"
echo "                pose_estimator=dw-ll_ucoco_384_bs5.torchscript.pt (GPU 사용)"
echo "        ControlNet: Illustrious_openpose.safetensors"
echo "        strength 1.0 / start 0.0 / end 0.4"
echo ""
echo "[깊이]  전처리기: DepthAnythingV2Preprocessor (ckpt_name=depth_anything_v2_vitl.pth)"
echo "        ControlNet: NoobAI_depth_midas.safetensors"
echo "        end_percent는 포즈(0.4)보다 높게 시작할 것. 배경은 후반까지 구조를 잡아야"
echo "        원근선이 안 무너진다. 0.8 근처에서 내려오며 탐색."
echo "        깊이맵 규약: 가까울수록 밝음. Blender Z pass는 반대로 나오기 쉬우니 미리보기 확인."
echo "        Blender 블록아웃 렌더는 $PROJ/depthmaps 에 올려두고 Load Image로 읽는다."
