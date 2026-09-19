#!/bin/bash
set -e

# RunPod ComfyUI (runpod-slim).
#
#   ./setup.sh wai             애니 (WAI-illustrious, SDXL). 공용 도구(tools)를 함께 설치.
#   ./setup.sh video           Wan 2.2 i2v (SDXL 아님, 단독 실행 가능)
#   ./setup.sh wai video       부트스트랩. video 는 자동으로 5B.
#   ./setup.sh krea            Krea 2 Turbo t2i (SDXL 아님, 단독 실행 가능)
#   ./setup.sh anima           Anima t2i (SDXL 아님, 단독 실행 가능)
#   ./setup.sh smooth
#   ./setup.sh dasiwa
#   ./setup.sh latentsync      립싱크 — LatentSync (SVD 기반 Sonic 대체)
#   ./setup.sh tools           공용 도구(FaceDetailer·전처리기·태거·USDU). wai 는 자동 포함,
#                              다른 프로필에서 쓰려면 직접 지정: ./setup.sh krea tools
#
# 볼륨 100GB 기준 조합별 누계는 각 프로필 파일 상단 주석에 있다.
#
# 20GB 급 파일이 섞이면 tmux 안에서 돌릴 것.
#   tmux new -s dl  →  ./setup.sh wai video  →  Ctrl+b, d
# 중단되어도 .part 를 남기므로 재실행하면 이어받는다.

COMFY=/workspace/runpod-slim/ComfyUI
BASE=/workspace/shared_models
PROJ=/workspace/files
OUTPUT=/workspace/output
NODES=$COMFY/custom_nodes
SELF="$(cd "$(dirname "$0")" && pwd)"
# 예전엔 /workspace/lomebrote 를 박아 뒀는데, 클론 위치를 옮기면 조용히 깨졌다.
# 스크립트가 있는 곳을 저장소로 본다.
REPO="$SELF"

DL_RETRIES=${DL_RETRIES:-5}

# 토큰. 파드는 매번 새로 만들지만 /workspace 는 볼륨이라 살아남는다.
#   printf '%s' '<키>' > /workspace/.civitai_token && chmod 600 /workspace/.civitai_token
#   printf '%s' '<키>' > /workspace/.hf_token      && chmod 600 /workspace/.hf_token
# 환경변수가 우선이므로 한 번만 다르게 쓰려면 CIVITAI_TOKEN=... 을 앞에 붙이면 된다.
if [ -z "$CIVITAI_TOKEN" ] && [ -r /workspace/.civitai_token ]; then
  CIVITAI_TOKEN="$(tr -d ' \t\r\n' < /workspace/.civitai_token)"
fi
# HF 토큰은 게이트 저장소용. Comfy-Org / Wan 계열은 없어도 받아진다.
if [ -z "$HF_TOKEN" ] && [ -r /workspace/.hf_token ]; then
  HF_TOKEN="$(tr -d ' \t\r\n' < /workspace/.hf_token)"
fi

# 알려진 venv 후보를 순서대로 찾는다 — 셀의 PATH/venv 활성화 여부에 기대지 않는다.
# 이게 command -v python3 로 뽑았을 때의 함정: venv를 활성화한 채로 실행하면 venv의
# python3에 설치되지만, 활성화 안 한 채로 실행하면 시스템 python3에 설치돼서 커스텀
# 노드가 실제로 돌아가는 venv 밖에 남는다. ComfyUI는 조용히 import 실패하고 노드가
# 통째로 등록에서 빠지는데, 백그라운드 프로세스라 에러가 화면에 안 보여서 원인을
# 찾기 어렵다. .venv-cu128는 일부 파드 이미지에서 쓰는 이름이라 후보에 포함해둔다.
PY=""
for c in "$COMFY/.venv-cu128/bin/python" /workspace/runpod-slim/venv/bin/python /workspace/venv/bin/python "$COMFY/venv/bin/python"; do
  [ -x "$c" ] && PY="$c" && break
done
if [ -z "$PY" ]; then
  PY="$(command -v python3)"
  echo "  ! 경고: 알려진 venv 경로에서 python을 찾지 못해 시스템 python3($PY)로 커스텀 노드"
  echo "    requirements를 설치합니다. ComfyUI가 다른 venv 안에서 뜬다면 노드가 조용히"
  echo "    로드 실패할 수 있습니다 — 이 경고가 보이면 venv 경로를 확인하세요."
fi

if [ $# -eq 0 ]; then
  echo "사용법: ./setup.sh <프로필...>"
  for f in "$SELF"/profiles/*.sh; do
    [ -f "$f" ] && echo "  $(basename "${f%.sh}")"
  done
  exit 1
fi

# ── 프로필 계약 ────────────────────────────────────
# 프로필은 FILES / NODE_REPOS 에 항목을 덧붙인다. 공통으로 깔리는 것은 없다 —
# 노드·가중치는 전부 필요로 하는 프로필이 직접 선언한다.
# 노드가 clone 된 뒤에 해야 하는 설정(config 쓰기, install.py 등)은 함수로 만들어
#   POST_NODES+=(함수명)
# 으로 등록하면 [4/5] 에서 실행된다. 함수 안의 마지막 명령이 실패하면 set -e 로 전체가
# 죽으므로 `[ ... ] && ...` 대신 if 를 쓸 것.
# 다른 프로필의 구성이 필요하면 프로필 안에서 `load_profile <이름>` 을 부른다(중복 로드 방지됨).
# HF 게이트 파일을 받는 프로필은 NEED_HF_TOKEN=1 을 선언한다.

FILES=()
NEED_HF_TOKEN=""
POST_NODES=()

# 프로필이 NODE_REPOS+= 로 덧붙이므로 반드시 source 보다 위에 있어야 한다.
NODE_REPOS=()

# 프로필이 "$@" 로 함께 지정된 프로필을 볼 수 있어야 한다(예: video 의 5b 자동 선택).
# load_profile 은 함수라 그 안에서는 "$@" 가 프로필 이름이 되므로 배열로 따로 둔다.
PROFILES=("$@")
LOADED_PROFILES=()

load_profile() {
  local p="$1" f="$SELF/profiles/$1.sh" l
  for l in "${LOADED_PROFILES[@]}"; do
    [ "$l" = "$p" ] && return 0
  done
  [ -f "$f" ] || { echo "없는 프로필: $p"; exit 1; }
  LOADED_PROFILES+=("$p")
  source "$f"
}

for p in "${PROFILES[@]}"; do
  load_profile "$p"
done

# ──────────────────────────────────────────────────

echo "프로필: $* / python: $PY / 디스크: $(df -h /workspace | awk 'NR==2 {print $4}')"

# ComfyUI 버전. 예전엔 이미지에 뭐가 들었든 그냥 썼는데, 영상 모델은 코어 버전을
# 탄다(Wan2.2 템플릿 = 0.3.46 이상, Anima = 0.11.1 이상). 안 맞으면 노드가 아예 없다.
if [ -d "$COMFY/.git" ]; then
  echo "ComfyUI: $(git -C "$COMFY" describe --tags --always 2>/dev/null || echo '태그 없음') ($(git -C "$COMFY" log -1 --format=%cd --date=short 2>/dev/null))"
  echo "  ※ 영상 모델 템플릿이 안 보이면 여기서 git pull 후 파드 재기동."
else
  echo "ComfyUI: 버전 확인 불가 (git 저장소 아님)"
fi

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
# diffusion_models/text_encoders/unet 은 Qwen·Wan 계열용.
# model_patches / latent_upscale_models 는 LTX-2.5 용. yaml 에도 같은 키가 있어야 한다.
mkdir -p $BASE/{checkpoints,loras,vae,controlnet,upscale_models,clip_vision,ipadapter,embeddings,wd14_tagger,controlnet_aux,diffusion_models,text_encoders,unet,sams,model_patches,latent_upscale_models,audio_encoders}
# 예전 이름(project_lomebrote)을 쓰던 볼륨은 폴더째 files 로 옮긴다. 이미 files 가 있으면 건드리지 않는다.
if [ -d /workspace/project_lomebrote ] && [ ! -e "$PROJ" ]; then
  mv /workspace/project_lomebrote "$PROJ"
  echo "  project_lomebrote → files 로 이동"
fi
# 예전 output_keep 은 /workspace/output 으로 합친다(같은 이름은 덮어쓰지 않고 남긴다).
if [ -d "$PROJ/output_keep" ]; then
  mkdir -p "$OUTPUT"
  mv -n "$PROJ/output_keep"/* "$OUTPUT"/ 2>/dev/null || true
  rmdir "$PROJ/output_keep" 2>/dev/null \
    || echo "  ! $PROJ/output_keep 에 옮기지 못한 파일이 남았습니다(이름 충돌 또는 숨김 파일). 직접 확인하세요."
fi
mkdir -p $PROJ/depthmaps
mkdir -p $PROJ/dataset/{raw,keep,caption}
# 영상 실습 입출력.
mkdir -p $PROJ/{video_in,video_out}
cp $REPO/extra_model_paths.yaml $COMFY/
# 생성 이미지·영상은 ComfyUI/output 이 아니라 /workspace/output 으로 간다.
# ComfyUI/output 자리에는 심볼릭 링크가 남아서 ComfyUI 는 원래 경로 그대로 쓴다.
bash "$REPO/move_comfy_output.sh" "$COMFY" > /dev/null \
  && echo "  output → $OUTPUT" \
  || echo "  ! output 링크 설정 실패 — ./move_comfy_output.sh $COMFY 를 직접 실행해 보세요."
mkdir -p $COMFY/user/default/workflows
# cp -n $REPO/workflows/*.json $COMFY/user/default/workflows/ 2>/dev/null || true
cp -rn $REPO/workflows/. $COMFY/user/default/workflows/ 2>/dev/null || true

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
# RunPod 이미지는 PIP_CONSTRAINT 로 torch 버전을 못박아 둔다(+cuXXX 로컬 버전 휠).
# pip 의 빌드 격리 환경은 PyPI 만 보므로 로컬 버전 휠을 찾지 못하고,
# 소스 빌드가 필요한 패키지(Impact Subpack 의 sam2 등)가 ResolutionImpossible 로 죽는다.
# 이미 설치된 torch 를 그대로 쓰도록 격리를 끄고, 그래도 안 되면 건너뛴다.
# sam2 는 SAM2 모델 전용이라 FaceDetailer(segment-anything 사용)에는 없어도 된다.
install_reqs() {
  local req="$1" name tmp
  name="$(basename "$(dirname "$req")")"
  tmp="$(mktemp)"
  grep -v '^[[:space:]]*\(git+\|-e[[:space:]]\)' "$req" > "$tmp" || true
  PIP_CONSTRAINT= "$PY" -m pip install -q -r "$tmp" \
    || echo "  ! requirements 일부 실패: $name"
  rm -f "$tmp"
  grep '^[[:space:]]*git+' "$req" 2>/dev/null | while read -r pkg; do
    PIP_CONSTRAINT= "$PY" -m pip install -q --no-build-isolation "$pkg" \
      || echo "  ! 선택 의존성 건너뜀: $name → $pkg"
  done
}

for req in $NODES/*/requirements.txt; do
  [ -f "$req" ] && install_reqs "$req"
done

echo "[4/5] 노드 설정"
# 노드별 설정은 각 프로필이 POST_NODES 로 등록한 함수가 한다(노드 clone·requirements 설치 이후).
for fn in "${POST_NODES[@]}"; do
  "$fn"
done

# ── 다운로드 ──────────────────────────────────────
# 원칙: 실패해도 .part 를 지우지 않는다. 지우는 경우는 다 받았는데 크기가 비정상일 때뿐.

download() {
  local dir="$1" name="$2" url="$3"
  local dest="$dir/$name" part="$dir/$name.part"
  local ok=0 try=1 rc=0
  local -a hdr=()
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
    # HF 는 반대로 헤더가 살아남는다(cdn-lfs 로 리다이렉트돼도 재전송된다).
    # 토큰을 쿼리로 붙이면 서명이 깨지므로 반드시 헤더로.
    # 게이트가 아닌 저장소에 토큰을 얹어도 무해하다.
    *huggingface.co/*)
      if [ -n "$HF_TOKEN" ]; then
        # 반드시 배열 원소 하나로. 따옴표 없이 펼치면 "Bearer" 와 토큰이
        # 별개 인자로 쪼개져서 aria2c 가 URL 로 오해한다.
        hdr=("--header=Authorization: Bearer $HF_TOKEN")
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
             "${hdr[@]}" \
             -d "$dir" -o "$name.part" "$url" || rc=$?
    else
      wget -c --tries=3 --waitretry=10 --read-timeout=60 \
           "${hdr[@]}" \
           --show-progress -q -O "$part" "$url" || rc=$?
    fi
    [ "$rc" -eq 0 ] && { ok=1; break; }

    # aria2 24 / wget 6 = 인증 실패. 재시도해도 안 바뀌므로 즉시 포기한다.
    if [ "$rc" -eq 24 ] || { ! command -v aria2c >/dev/null 2>&1 && [ "$rc" -eq 6 ]; }; then
      echo "  ! 인증 실패(401): $name"
      case "$url" in
        *civitai*)     echo "    CIVITAI_TOKEN=<키> ./setup.sh ...  또는 civitai.red 미러를 쓸 것." ;;
        *huggingface*) echo "    HF_TOKEN=<키> ./setup.sh ...  게이트 저장소는 웹에서 약관 동의도 먼저 해야 한다." ;;
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
if [ -n "$NEED_HF_TOKEN" ] && [ -z "$HF_TOKEN" ]; then
  echo "  ⚠ 게이트된 HF 저장소를 받는 프로필인데 토큰이 없습니다. 반드시 401 이 납니다."
  echo "    1) 해당 모델 페이지에서 약관 동의  2) HF_TOKEN=<키> 또는 /workspace/.hf_token"
fi

echo "[5/5] 파일 다운로드"
# 예전엔 첫 실패에서 exit 1 했는데, 20GB 짜리를 여럿 받는 중에 civitai 하나가
# 넘어지면 뒤의 정상 파일까지 통째로 못 받았다. 실패는 모아서 끝에 보고한다.
FAILED=()
for e in "${FILES[@]}"; do
  IFS='|' read -r dir name url <<< "$e"
  dest="$dir/$name"
  if [ -s "$dest" ] && [ "$(stat -c%s "$dest")" -gt 100000 ]; then
    echo "  = $name"
    continue
  fi
  echo "  + $name"
  download "$dir" "$name" "$url" || FAILED+=("$name")
done

echo ""
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "⚠ 실패 ${#FAILED[@]}건:"
  for f in "${FAILED[@]}"; do echo "    - $f"; done
  echo "  재실행하면 성공한 파일은 건너뛰고 실패분만 이어받습니다."
else
  echo "완료. 파드를 Restart 해야 yaml 이 적용됩니다."
fi
echo "  ※ extra_model_paths.yaml 에 ultralytics_bbox / ultralytics_segm / sams 키가"
echo "    없으면 FaceDetailer 의 감지 모델 드롭다운이 빈 채로 뜹니다."
echo "  ※ 영상 프로필은 model_patches / latent_upscale_models 키도 필요합니다."
echo "남은 디스크: $(df -h /workspace | awk 'NR==2 {print $4}')"

[ ${#FAILED[@]} -gt 0 ] && exit 1
exit 0
