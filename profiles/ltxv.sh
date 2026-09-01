# LTXV (Lightricks LTX-Video). 보충 실습 "LTXV — 영상+오디오 동시 생성"에서 사용.
#
# 기존 ltx 프로필(LTX-2.5, HF 토큰 필요, 풀정밀도면 60GB+)과는 다른 프로필이다.
# 그쪽은 최신·최고사양 트랙, 이쪽은 학습용 경량 트랙이라고 보면 된다.
# 여기서는 문서화가 잘 되어 있고 게이트가 걸려 있지 않은 0.9.8 distilled-fp8
# 체크포인트를 쓴다 — 2b(4.46GB)면 12GB급 GPU에서도 실습이 가능하다.
# 13b가 필요해지면 아래 대안 줄의 주석만 풀면 된다(15.7GB, VRAM 16~24GB 권장).
#
# 주의 — 텍스트 인코더: LTXV 체크포인트에는 CLIP(텍스트 인코더)이 포함되어 있지
# 않다. FLUX 계열과 동일한 t5xxl 을 그대로 재사용하므로 별도로 받아야 한다.
# 이미 qwen/flux 계열 프로필로 t5xxl_fp8_e4m3fn_scaled.safetensors 를 받아둔
# 적이 있다면 이 블록은 건너뛰어도 된다(파일명이 같으면 스킵 로직이 알아서 건너뜀).

NODE_REPOS+=(
  "ComfyUI-LTXVideo|https://github.com/Lightricks/ComfyUI-LTXVideo.git|no"
)

FILES+=(
  "$BASE/checkpoints|ltxv-2b-0.9.8-distilled-fp8.safetensors|https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltxv-2b-0.9.8-distilled-fp8.safetensors"
  # 13b로 올리고 싶으면 위 줄 대신 이걸 쓸 것 (15.7GB, VRAM 16~24GB):
  # "$BASE/checkpoints|ltxv-13b-0.9.8-distilled-fp8.safetensors|https://huggingface.co/Lightricks/LTX-Video/resolve/main/ltxv-13b-0.9.8-distilled-fp8.safetensors"
  "$BASE/text_encoders|t5xxl_fp8_e4m3fn_scaled.safetensors|https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn_scaled.safetensors"
)
