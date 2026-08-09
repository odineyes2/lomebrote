# 실사. 인물 나이·인종 다양성과 건축/풍경이 목적일 때.

FILES+=(
  "$BASE/checkpoints|RealVisXL_V5.0_fp16.safetensors|https://huggingface.co/SG161222/RealVisXL_V5.0/resolve/main/RealVisXL_V5.0_fp16.safetensors"
  "$BASE/upscale_models|4x-UltraSharpV2.pth|https://huggingface.co/Kim2091/UltraSharpV2/resolve/main/4x-UltraSharpV2.pth"
  "$BASE/controlnet|xinsir_openpose.safetensors|https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors"
  "$BASE/controlnet|xinsir_depth.safetensors|https://huggingface.co/xinsir/controlnet-depth-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors"
  "$BASE/controlnet|xinsir_scribble.safetensors|https://huggingface.co/xinsir/controlnet-scribble-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors"
  "$BASE/controlnet|xinsir_canny.safetensors|https://huggingface.co/xinsir/controlnet-canny-sdxl-1.0/resolve/main/diffusion_pytorch_model_V2.safetensors"
)

HINT="$HINT
[real] RealVisXL V5.0 / CFG 3~6 / steps 25~35 / DPM++ 2M Karras
       ControlNet: xinsir_openpose(end 0.4), xinsir_depth(end 0.8 근처)
       업스케일: 4x-UltraSharpV2
       자연어로 쓸 것. booru 태그와 masterpiece 류는 효과 없거나 해롭다.
       품질은 사진 용어로 — 35mm, overcast light, shallow depth of field.
       네거티브는 짧게: cartoon, anime, 3d render, illustration
"
