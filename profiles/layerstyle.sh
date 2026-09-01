# LayerStyle. 보충 실습 "레이어 합성(Layer Composition)"에서 사용.
# 기본 블렌드(ImageBlend)·그림자(DropShadow)만 쓰는 실습 범위에서는
# 모델 다운로드가 전혀 필요 없다 — 노드팩 설치만으로 끝난다.
#
# 배경 제거·세그멘테이션(Florence-2, RemBG 계열) 같은 고급 기능을 나중에
# 쓰게 되면 이 파일 아래에 FILES+= 블록을 추가할 것. 그 전까지는 굳이
# +2~5GB를 미리 받아둘 이유가 없다.

NODE_REPOS+=(
  "ComfyUI_LayerStyle|https://github.com/chflame163/ComfyUI_LayerStyle.git|no"
)
