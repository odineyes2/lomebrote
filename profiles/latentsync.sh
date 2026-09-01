# LatentSync (ByteDance). 보충 실습 "립싱크"에서 사용.
# 흔히 쓰이는 Sonic 노드는 내부적으로 SVD 체크포인트를 요구해서 제외했다.
# LatentSync 는 SVD 없이 오디오→입모양을 직접 매핑하는 모델이라 더 가볍다.
#
# 주의 1 — 버전: 노드 저장소(ShmuelRonen/ComfyUI-LatentSyncWrapper)가 권장하는
# "1.6" 체크포인트는 ByteDance/LatentSync-1.6 이 private/게이트 저장소라
# 자동 다운로드가 막혀 있다(로그인 후 약관 동의 필요). 여기서는 완전히 공개된
# chunyu-li/LatentSync 미러(1.5 계열, latentsync_unet.pt 3.4GB)를 대신 받는다.
# README 는 "1.5/1.6 코드는 호환, 체크포인트만 다르다"고 명시하므로 실습
# 목적에는 문제없다. 더 최신인 1.6이 꼭 필요하면 HF에서 약관 동의 후
# stable_syncnet.pt 포함 세트로 수동 교체할 것.
#
# 주의 2 — stable_syncnet.pt 는 훈련(supervision)용이라 순수 추론(립싱크 생성)에는
# 필요 없다. 안 받아도 워크플로가 정상 동작한다 — 1.6GB를 아낄 수 있다.
#
# 주의 3 — 설치 경로: 다른 프로필처럼 $BASE 밑으로 모으면 안 된다. 이 노드는
# 자기 폴더 안의 checkpoints/ 를 상대경로로 그대로 찾기 때문에, 반드시
# $NODES/ComfyUI-LatentSyncWrapper/checkpoints/ 밑에 둬야 인식한다.

NODE_REPOS+=(
  "ComfyUI-LatentSyncWrapper|https://github.com/ShmuelRonen/ComfyUI-LatentSyncWrapper.git|no"
)

FILES+=(
  "$NODES/ComfyUI-LatentSyncWrapper/checkpoints|latentsync_unet.pt|https://huggingface.co/chunyu-li/LatentSync/resolve/main/latentsync_unet.pt"
  "$NODES/ComfyUI-LatentSyncWrapper/checkpoints/whisper|tiny.pt|https://huggingface.co/chunyu-li/LatentSync/resolve/main/whisper/tiny.pt"
)
