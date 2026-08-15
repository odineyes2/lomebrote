# LTX-2.5 — 실험적. 커리큘럼 본선은 video(Wan 2.2) 이고 이건 곁다리다.
#
# 2026-08-11 공개, ComfyUI 데이-0 네이티브 지원. 22B, 오디오·비디오 동시 생성,
# 네이티브 멀티샷(한 번의 생성으로 연결된 여러 컷). 성능은 좋지만 공개된 지
# 얼마 안 돼서 커뮤니티 레시피와 트러블슈팅 자료가 거의 없다. 실습 중 막히면
# 검색으로 안 풀린다는 뜻이다. Wan 을 먼저 성공시킨 다음에 올 것.
#
# ⚠ 사전 조건 3가지. 하나라도 빠지면 스크립트가 401 로 죽는다.
#   1. https://huggingface.co/Lightricks/LTX-2.5 에서 약관 동의(게이트 저장소다)
#   2. HF_TOKEN=<키> 또는 /workspace/.hf_token 파일
#   3. ComfyUI 0.32.0 이상. setup.sh 가 기동 시 버전을 찍어 준다.
#
# ⚠ 라이선스: LTX-2.x Community License. ARR 1000만 달러 미만이면 상용 포함 무료지만
#   Apache 2.0 인 Wan 2.2 와 조건이 다르다. 결과물을 팔 계획이면 원문을 읽을 것.
#
# 모드:
#   LTX=distilled (기본) 8스텝 고정, CFG=1. 반복 실습용.
#   LTX=dev              풀 모델. 학습(LoRA) 가능한 쪽. 느리고 무겁다.
#
# 볼륨 100GB 기준 (누계, int8 기준 추정):
#   ltx(distilled) 단독               40GB 안팎
#   anime + qwen(gguf) + ltx          87GB 안팎  ← 여유 없음
#   qwen 과 함께 쓰지 말 것을 권함. 영상 전용 파드로 분리하는 게 편하다.
#
# 제약(워크플로에서 자주 걸린다):
#   num_frames % 8 == 1  → 1, 9, 17, ... 121
#   width / height 는 32 의 배수
#   duration head 를 물리면 프레임 수를 프롬프트에서 알아서 정한다

LTX_MODE="${LTX:-distilled}"
NEED_HF_TOKEN=1

# *-comfy-int8-convrot 는 ComfyUI 전용 양자화다. bf16 대비 절반 크기.
# ltx-pipelines / diffusers 로는 못 읽으니 파이썬 쪽으로 갈 거면 bf16 을 따로 받을 것.
if [ "$LTX_MODE" = "dev" ]; then
  FILES+=(
    "$BASE/diffusion_models|ltx-2.5-22b-dev-transformer-comfy-int8-convrot.safetensors|https://huggingface.co/Lightricks/LTX-2.5/resolve/main/diffusion_models/ltx-2.5-22b-dev-transformer-comfy-int8-convrot.safetensors"
    # dev 트랜스포머로 증류 스케줄을 쓰려면 이 LoRA 를 얹는다.
    "$BASE/loras|ltx-2.5-22b-distilled-lora-450-bf16.safetensors|https://huggingface.co/Lightricks/LTX-2.5/resolve/main/loras/ltx-2.5-22b-distilled-lora-450-bf16.safetensors"
  )
else
  FILES+=(
    "$BASE/diffusion_models|ltx-2.5-22b-distilled-transformer-comfy-int8-convrot.safetensors|https://huggingface.co/Lightricks/LTX-2.5/resolve/main/diffusion_models/ltx-2.5-22b-distilled-transformer-comfy-int8-convrot.safetensors"
  )
fi

FILES+=(
  # Gemma 4 12B 기반 전용 인코더. T5 가 아니다. 긴 프롬프트에서 절이 안 떨어진다.
  "$BASE/text_encoders|gemma4-12b-with-proj-ltx-2.5-comfy-int8-convrot.safetensors|https://huggingface.co/Lightricks/LTX-2.5/resolve/main/text_encoders/gemma4-12b-with-proj-ltx-2.5-comfy-int8-convrot.safetensors"
  # VAE 가 둘이다. conv 가 가볍고 빠름. 화질이 아쉬우면 ltx-2.5-video-vae-bf16 (DiffVAE) 로 교체.
  "$BASE/vae|ltx-2.5-video-vae-conv-bf16.safetensors|https://huggingface.co/Lightricks/LTX-2.5/resolve/main/vae/ltx-2.5-video-vae-conv-bf16.safetensors"
  "$BASE/vae|ltx-2.5-audio-vae-bf16.safetensors|https://huggingface.co/Lightricks/LTX-2.5/resolve/main/vae/ltx-2.5-audio-vae-bf16.safetensors"
  "$BASE/model_patches|ltx-2.5-duration-head-bf16.safetensors|https://huggingface.co/Lightricks/LTX-2.5/resolve/main/model_patches/ltx-2.5-duration-head-bf16.safetensors"
  # 다단계 파이프라인 필수. 없으면 2스테이지 템플릿이 안 돈다.
  "$BASE/latent_upscale_models|ltx-2.5-latent-spatial-upscaler-x2-bf16-1.0.safetensors|https://huggingface.co/Lightricks/LTX-2.5/resolve/main/latent_upscale_models/ltx-2.5-latent-spatial-upscaler-x2-bf16-1.0.safetensors"
  "$BASE/latent_upscale_models|ltx-2.5-latent-temporal-upscaler-x2-bf16-1.0.safetensors|https://huggingface.co/Lightricks/LTX-2.5/resolve/main/latent_upscale_models/ltx-2.5-latent-temporal-upscaler-x2-bf16-1.0.safetensors"
)

# ※ latent_upscale_models 폴더 키는 아직 확정적으로 확인하지 못했다.
#   공식 템플릿을 로드했는데 업스케일러 드롭다운이 비어 있으면
#   두 파일을 $BASE/upscale_models/ 로 옮기고 노드를 다시 확인할 것.

NODE_REPOS+=(
  "ComfyUI-VideoHelperSuite|https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git|no"
)
