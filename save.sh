#!/bin/bash
set -e
COMFY=/workspace/runpod-slim/ComfyUI
REPO=/workspace/lomebrote
SRC=$COMFY/user/default/workflows

# 하위 폴더까지 재귀적으로 json 파일 탐색
mapfile -t files < <(find "$SRC" -type f -name "*.json")

# 경우 1) 저장된 워크플로우가 하나도 없음
if [ ${#files[@]} -eq 0 ]; then
  echo "저장된 워크플로우가 없습니다. (확인 경로: $SRC)"
  exit 0
fi

# 상대 경로(하위 폴더 구조)를 유지하며 복사
for f in "${files[@]}"; do
  rel="${f#$SRC/}"                  # SRC 기준 상대경로 (예: subdir/foo.json)
  dest="$REPO/workflows/$rel"
  mkdir -p "$(dirname "$dest")"     # 필요한 하위 폴더 생성
  cp -u "$f" "$dest"
done

cd $REPO
git add .

# 경우 2) json은 있지만 이미 전부 백업되어 새 변경이 없음
if git diff --cached --quiet; then
  echo "새로 추가되거나 변경된 워크플로우가 없습니다. 커밋할 것이 없습니다."
  exit 0
fi

# 경우 3) 스테이징 완료
echo "다음 파일이 스테이징되었습니다:"
git status --short
echo ""
echo "이제 커밋하세요:  cd $REPO && git commit -m \"메시지\" && git push"