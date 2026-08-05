#!/bin/bash
set -e
COMFY=/workspace/runpod-slim/ComfyUI
REPO=/workspace/lomebrote
SRC=$COMFY/user/default/workflows

# nullglob: 매칭되는 json이 없을 때 '*.json' 문자열 대신 빈 배열이 되도록
shopt -s nullglob
files=("$SRC"/*.json)
shopt -u nullglob

# 경우 1) ComfyUI에 저장된 워크플로우 자체가 없음
if [ ${#files[@]} -eq 0 ]; then
  echo "저장된 워크플로우가 없습니다. (확인 경로: $SRC)"
  exit 0
fi

cp -u "${files[@]}" "$REPO/workflows/"
cd $REPO
git add .

# 경우 2) json은 있지만 이미 전부 백업되어 새 변경이 없음
# git diff --cached --quiet : 스테이징된 변경이 없으면 0, 있으면 1을 반환
if git diff --cached --quiet; then
  echo "새로 추가되거나 변경된 워크플로우가 없습니다. 커밋할 것이 없습니다."
  exit 0
fi

# 경우 3) 스테이징 완료
echo "다음 파일이 스테이징되었습니다:"
git status --short
echo ""
echo "이제 커밋하세요:  cd $REPO && git commit -m \"메시지\" && git push"
