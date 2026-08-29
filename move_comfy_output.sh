#!/usr/bin/env bash
#
# ComfyUI의 output 폴더를 /workspace/output 으로 옮기고,
# 원래 자리에는 심볼릭 링크를 남겨서 ComfyUI가 어떻게 실행되든
# (스크립트, systemd, nightshift를 통해서든) 그대로 동작하게 한다.
#
# 사용법:
#   ./move_comfy_output.sh                 # ComfyUI 설치 경로 자동 탐색
#   ./move_comfy_output.sh /opt/ComfyUI    # 경로를 직접 지정

set -euo pipefail

NEW_OUTPUT="/workspace/output"

find_comfyui_dir() {
    # main.py가 있고, 그 안에 ComfyUI 특유의 흔적이 있는 폴더를 찾는다
    local candidates=(
        "/workspace/ComfyUI"
        "/opt/ComfyUI"
        "/ComfyUI"
        "$HOME/ComfyUI"
    )
    for dir in "${candidates[@]}"; do
        if [[ -f "$dir/main.py" ]]; then
            echo "$dir"
            return 0
        fi
    done
    # 후보 경로에 없으면 파일시스템에서 직접 탐색 (시간이 좀 걸릴 수 있음)
    find / -maxdepth 5 -type f -name "main.py" -path "*ComfyUI*" 2>/dev/null \
        | head -n 1 | xargs -r dirname
}

if [[ $# -ge 1 ]]; then
    COMFY_DIR="$1"
else
    COMFY_DIR="$(find_comfyui_dir)"
fi

if [[ -z "${COMFY_DIR:-}" || ! -d "$COMFY_DIR" ]]; then
    echo "ComfyUI 설치 경로를 찾지 못했어요. 직접 경로를 인자로 넘겨주세요:"
    echo "  ./move_comfy_output.sh /경로/ComfyUI"
    exit 1
fi

OLD_OUTPUT="$COMFY_DIR/output"
echo "ComfyUI 경로: $COMFY_DIR"
echo "기존 output:  $OLD_OUTPUT"
echo "새 output:    $NEW_OUTPUT"
echo

mkdir -p "$NEW_OUTPUT"

if [[ -L "$OLD_OUTPUT" ]]; then
    # 이미 심볼릭 링크라면 (재실행 등) 그냥 다시 걸어준다
    echo "이미 심볼릭 링크네요. 다시 연결합니다."
    rm "$OLD_OUTPUT"
elif [[ -d "$OLD_OUTPUT" ]]; then
    # 기존 output 폴더에 파일이 있으면 새 위치로 옮긴다
    shopt -s dotglob nullglob
    files=("$OLD_OUTPUT"/*)
    if [[ ${#files[@]} -gt 0 ]]; then
        echo "기존 output 폴더에 있던 ${#files[@]}개 항목을 옮깁니다..."
        mv "$OLD_OUTPUT"/* "$NEW_OUTPUT"/
    fi
    rmdir "$OLD_OUTPUT"
fi

ln -s "$NEW_OUTPUT" "$OLD_OUTPUT"

echo
echo "완료됐어요."
echo "  $OLD_OUTPUT  →  $NEW_OUTPUT (심볼릭 링크)"
echo
echo "확인:"
ls -la "$COMFY_DIR" | grep output
