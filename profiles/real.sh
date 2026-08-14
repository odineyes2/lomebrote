# 실사 (RealVisXL).

SDXL=1

FILES+=(
  "$BASE/checkpoints|RealVisXL_V5.0_fp16.safetensors|https://huggingface.co/SG161222/RealVisXL_V5.0/resolve/main/RealVisXL_V5.0_fp16.safetensors"
  "$BASE/upscale_models|4x-UltraSharpV2.pth|https://huggingface.co/Kim2091/UltraSharpV2/resolve/main/4x-UltraSharpV2.pth"
  "$BASE/controlnet|xinsir_openpose.safetensors|https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors"
  "$BASE/controlnet|xinsir_depth.safetensors|https://huggingface.co/xinsir/controlnet-depth-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors"
  "$BASE/controlnet|xinsir_scribble.safetensors|https://huggingface.co/xinsir/controlnet-scribble-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors"
  "$BASE/controlnet|xinsir_canny.safetensors|https://huggingface.co/xinsir/controlnet-canny-sdxl-1.0/resolve/main/diffusion_pytorch_model_V2.safetensors"
)
