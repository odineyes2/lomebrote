# ESRGAN 업스케일러. 보충 실습 "ESRGAN 업스케일링"에서 사용.
# UpscaleModelLoader / ImageUpscaleWithModel 은 ComfyUI 기본 노드라
# NODE_REPOS 에 추가할 게 없다. 모델 파일만 받으면 끝.
#
# nsfw 프로필에는 이미 4x-AnimeSharp / 4x_foolhardy_Remacri 가 들어있다.
# 여기서는 겹치지 않게 범용 계열(UltraSharp, RealESRGAN)만 추가한다 —
# 애니 화풍은 nsfw 쪽 모델로, 사진·반실사 비교는 이쪽으로 실습할 것.

FILES+=(
  "$BASE/upscale_models|4x-UltraSharp.pth|https://huggingface.co/fofr/comfyui/resolve/main/upscale_models/4x-UltraSharp.pth"
  "$BASE/upscale_models|RealESRGAN_x4plus.pth|https://huggingface.co/fofr/comfyui/resolve/main/upscale_models/RealESRGAN_x4plus.pth"
)
