# MiniMax H3 (Hailuo 3.0) — 옴니모달 T2V / I2V / R2V, 네이티브 스테레오 오디오.
#   ./setup.sh mmh3            LoRA 만 받으려면: ./setup.sh --loras mmh3
#
# ComfyUI 코어 0.30.0+ 에 MiniMaxH3ImageToVideo / MiniMaxH3ReferenceToVideo 노드가
# 내장돼 있다(PR #15224). qwen/video 처럼 SDXL이 아니고 단독 실행 가능 — 커스텀 노드
# 불필요. 코어가 오래됐으면(0.30.0 미만) 템플릿을 열어도 노드가 안 보이니 위쪽
# "ComfyUI: ..." 줄에서 버전을 확인하고 필요하면 git pull 후 파드 재기동.
#
# 기본 선택 근거 (huggingface.co/Comfy-Org/MiniMax-H3 확인, 2026-09-18):
#   diffusion : pruned_fp8_scaled — 이 이미지의 venv가 .venv-cu128 이름이라 cu128
#               계열로 보고 이걸 기본값으로 잡았다. 공식 모델 카드는 "torch를 cu130으로
#               쓸 수 있으면 int8_convrot을 우선하라"고 명시한다(같은 21GB, comfy-kitchen
#               가속 커널을 더 탄다). cu128에서 int8_convrot을 써도 에러는 안 나고
#               경고 후 느린 fallback으로 동작한다 — torch.version.cuda 가 13 이상으로
#               확인되면 아래 두 줄의 pruned_fp8_scaled → pruned_int8_convrot 로 이름만
#               바꿔도 된다.
#   fl2va vs ref2va : 둘 다 받는다. fl2va = T2V/I2V(video_minimax_h3_t2v.json,
#               video_minimax_h3_i2v.json), ref2va = 레퍼런스 기반 R2V
#               (video_minimax_h3_r2v.json). 서로 다른 체크포인트라 겸용이 안 된다.
#   encoder   : nvfp4_awq — 세 quant 중 유일하게 모델 카드가 "Blackwell 불필요"라고
#               명시한 텍스트 인코더(Qwen3-VL-32B 기반). 15.7GB로 가장 작다.
#   video vae : int8_convrot — fp16(5.21GB)보다 작고, 디코드도 더 빠르다는 커뮤니티
#               보고가 있다(체감 차이는 GPU따라 다를 수 있음, 결정적이진 않음).
#   audio vae : fp32 하나뿐(다른 정밀도 옵션 자체가 없다).
#
# 누계: diffusion 21GB×2 + encoder 15.7GB + video_vae 2.81GB + audio_vae 0.6GB
#      ≈ 61GB (100GB 볼륨 기준, 다른 프로필과 같이 쓰면 합산해서 여유 확인할 것)
#
# 라이선스: minimax-h3-community-license-agreement. 모델 카드에서 클릭 동의 게이트
# 문구는 확인되지 않았다 — 토큰 없이 먼저 시도하고, 401이 나면
# huggingface.co/Comfy-Org/MiniMax-H3 에서 약관 동의 후 HF_TOKEN 을 넣을 것.
#
# 워크플로우 템플릿(공식 T2V/I2V/R2V) 3개는 함께 전달한 workflows/ 폴더를
# 저장소의 workflows/ 아래 합쳐 넣으면 기존 `cp -rn $REPO/workflows/. ...` 단계가
# 그대로 ComfyUI에 복사한다. 이 프로필 파일 자체는 다운로드를 네트워크로 하지 않는다.

FILES+=(
#  "$BASE/diffusion_models|minimax_h3_fl2va_pruned_fp8_scaled.safetensors|https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/diffusion_models/minimax_h3_fl2va_pruned_fp8_scaled.safetensors"
#  "$BASE/diffusion_models|minimax_h3_ref2va_pruned_fp8_scaled.safetensors|https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/diffusion_models/minimax_h3_ref2va_pruned_fp8_scaled.safetensors"
#  "$BASE/text_encoders|qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors|https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
#  "$BASE/vae|minimax_h3_video_vae_int8_convrot.safetensors|https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_video_vae_int8_convrot.safetensors"
#  "$BASE/vae|minimax_h3_audio_vae_fp32.safetensors|https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors"

  "$BASE/loras/MMH3|MysticXXX_MMH3-V4.safetensors|https://civitai.red/api/download/models/3266628?fileId=3150341"
  "$BASE/loras/MMH3|H3_Motion_BoosterV2.safetensors|https://civitai.red/api/download/models/3228867?fileId=3111185"
)
