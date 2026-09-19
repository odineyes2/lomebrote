# tools — 체크포인트 계열과 무관하게 쓰는 공용 도구 묶음.
# 특정 모델에 귀속시키기 애매한 노드·전처리기 가중치·검출 모델을 한곳에 모았다.
# 기본 모델 프로필(wai)이 load_profile 로 자동으로 함께 부른다. 다른 프로필과 조합할 때는
# 직접 지정한다:  ./setup.sh krea tools
#
#   ComfyUI_UltimateSDUpscale        USDU 타일 업스케일 (서브모듈 필요)
#   ComfyUI-Inpaint-CropAndStitch    인페인팅 영역 확대 후 재합성
#   ComfyUI-WD14-Tagger              booru 태그 추출 (데이터셋 캡션용)
#   comfyui_controlnet_aux           DWPose, DepthAnythingV2, lineart 등 전처리기
#   ComfyUI-Impact-Pack + Subpack    FaceDetailer. v8.0 부터 UltralyticsDetectorProvider 가
#                                    Subpack 으로 분리돼서 둘 다 필요하다.
#                                    Subpack 의 requirements 가 ultralytics 를 끌고 온다
#                                    (setup.sh 의 pip 루프가 처리).
#
# 이 프로필의 노드 설정(controlnet_aux 가중치 경로, WD14 태거 기본값, Impact install.py)은
# 노드가 clone 된 뒤에야 할 수 있으므로 POST_NODES 훅으로 setup.sh 의 [4/5] 에서 실행된다.

NODE_REPOS+=(
  "ComfyUI_UltimateSDUpscale|https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git|yes"
  "ComfyUI-Inpaint-CropAndStitch|https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git|no"
  "ComfyUI-WD14-Tagger|https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git|no"
  "comfyui_controlnet_aux|https://github.com/Fannovel16/comfyui_controlnet_aux.git|no"
  "ComfyUI-Impact-Pack|https://github.com/ltdrdata/ComfyUI-Impact-Pack.git|no"
  "ComfyUI-Impact-Subpack|https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git|no"
)

FILES+=(
  # 전처리기 가중치. 폴더가 <HF 저장소명> 구조여야 노드가 찾는다.
  "$BASE/controlnet_aux/hr16/yolox-onnx|yolox_l.torchscript.pt|https://huggingface.co/hr16/yolox-onnx/resolve/main/yolox_l.torchscript.pt"
  "$BASE/controlnet_aux/hr16/DWPose-TorchScript-BatchSize5|dw-ll_ucoco_384_bs5.torchscript.pt|https://huggingface.co/hr16/DWPose-TorchScript-BatchSize5/resolve/main/dw-ll_ucoco_384_bs5.torchscript.pt"
  "$BASE/controlnet_aux/yzd-v/DWPose|yolox_l.onnx|https://huggingface.co/yzd-v/DWPose/resolve/main/yolox_l.onnx"
  "$BASE/controlnet_aux/depth-anything/Depth-Anything-V2-Large|depth_anything_v2_vitl.pth|https://huggingface.co/depth-anything/Depth-Anything-V2-Large/resolve/main/depth_anything_v2_vitl.pth"

  # WD14 태거. .onnx/.csv 파일명이 모델명과 같아야 노드가 로컬 파일로 인식한다.
  "$BASE/wd14_tagger|wd-swinv2-tagger-v3.onnx|https://huggingface.co/SmilingWolf/wd-swinv2-tagger-v3/resolve/main/model.onnx"
  "$BASE/wd14_tagger|wd-swinv2-tagger-v3.csv|https://huggingface.co/SmilingWolf/wd-swinv2-tagger-v3/resolve/main/selected_tags.csv"

  # FaceDetailer 감지 모델. bbox/ segm/ 하위 폴더 구조가 그대로여야 노드 드롭다운에 뜬다
  # (Impact Subpack 은 ultralytics/ 아래 bbox·segm 을 각각 따로 스캔한다. 평평하게 두면 못 찾는다).
  # 노드에서는 "bbox/face_yolov8m.pt" 처럼 폴더명이 붙은 채로 보인다.
  # yolov8m(약 52MB) 이 기본. 얼굴이 작은 구도에서는 s 보다 회수율이 낫다.
  "$BASE/ultralytics/bbox|face_yolov8m.pt|https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt"
  "$BASE/ultralytics/bbox|hand_yolov8s.pt|https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt"
  "$BASE/ultralytics/segm|person_yolov8m-seg.pt|https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt"
  # SAM. bbox 만으로 충분한 경우가 많아 선택이지만, 머리카락에 걸리는 얼굴 경계를
  # 정리할 때 sam_model_opt 로 물린다. vit_b 는 375MB 로 vit_h(2.4GB) 대비 가볍다.
  "$BASE/sams|sam_vit_b_01ec64.pth|https://huggingface.co/segments-arnaud/sam_vit_b/resolve/main/sam_vit_b_01ec64.pth"
)

# 함수의 마지막 명령이 실패하면 set -e 로 setup.sh 전체가 죽는다. 조건문은 반드시 if 로 쓸 것.
tools_post_nodes() {
  # 전처리기 가중치를 노드 폴더 밖으로 뺀다(재클론 시 유실 방지).
  # EP_list 가 CPU 인 이유: onnxruntime-gpu 는 CUDA 12+ 에서 설치가 번거롭다.
  # 노드에서 .torchscript.pt 계열을 고르면 torch 가 GPU 를 쓴다.
  cat > "$NODES/comfyui_controlnet_aux/config.yaml" << YAMLEOF
annotator_ckpts_path: "$BASE/controlnet_aux"
custom_temp_path:
USE_SYMLINKS: False
EP_list: ["CPUExecutionProvider"]
YAMLEOF

  # pysssss.json 은 저장소 안에 있어 파드마다 초기화된다. settings 만 덮어쓴다.
  # eva02-large 는 swinv2 보다 느리지만 의상·소품 태그 회수율이 높다.
  # 캐릭터 LoRA 는 의상 태그를 빠짐없이 달아 얼굴과 분리하는 게 핵심이라 여기서 정확도가 곧 결과다.
  local cfg="$NODES/ComfyUI-WD14-Tagger/pysssss.json"
  if [ -f "$cfg" ]; then
    "$PY" - "$cfg" << 'PYEOF'
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
  fi

  # Impact Pack 은 Manager 가 install.py 를 돌려주는 걸 전제로 만들어져 있다.
  # 손으로 clone 하면 impact-pack.ini 가 안 생겨서 노드가 통째로 로드에 실패한다.
  local ip
  for ip in ComfyUI-Impact-Pack ComfyUI-Impact-Subpack; do
    if [ -f "$NODES/$ip/install.py" ]; then
      (cd "$NODES/$ip" && PIP_CONSTRAINT= "$PY" install.py) \
        || echo "  ! install.py 실패: $ip (기동 후 콘솔에서 IMPORT FAILED 여부 확인)"
    fi
  done
}
POST_NODES+=(tools_post_nodes)
