# lomebrote

RunPod ComfyUI 환경 세팅. 파드는 작업 후 매번 terminate하므로, 유지되어야 하는 것은
전부 이 저장소 안이나 `/workspace` 볼륨 안에 있어야 한다.

---

## 빠른 시작

```bash
cd /workspace && git clone https://github.com/odineyes2/lomebrote.git
cd /workspace/lomebrote
```

```bash
# 20GB급 파일이 섞이므로 tmux 안에서 돌린다 (아래 "긴 다운로드" 항목 참고)
tmux new -s dl
./setup.sh wai video
```

끝나면 **RunPod 콘솔에서 파드를 Restart** 해야 `extra_model_paths.yaml`이 적용된다.

인자 없이 실행하면 프로필 목록이 나온다.

```bash
./setup.sh
```

---

## 긴 다운로드 — tmux

`⚠ tmux/screen 밖입니다` 경고는 **세션이 끊기면 다운로드 프로세스도 같이 죽기 때문**에
나온다. RunPod 웹 터미널은 브라우저 탭을 닫거나 네트워크가 잠깐 흔들리면 그대로 끊긴다.
20GB짜리를 받는 중이라면 그 시점까지의 시간이 날아간다(`.part`는 남으므로 재실행하면
이어받지만, 다시 붙어 있어야 한다).

tmux는 **명령을 터미널이 아니라 서버 쪽 세션에 붙여 두는** 도구다. 세션은 파드가 살아 있는 한
유지되므로, 접속이 끊겨도 다운로드는 계속 돌고 나중에 다시 들어가서 진행 상황을 볼 수 있다.

### 기본 흐름

```bash
# 1. 세션 만들면서 들어간다 (이름은 아무거나, 여기선 dl)
tmux new -s dl

# 2. 세션 안에서 평소처럼 실행
cd /workspace/lomebrote && ./setup.sh wai video

# 3. 붙여 놓은 채로 빠져나온다 — Ctrl+b 를 누르고 손을 뗀 다음 d
#    (동시에 누르는 게 아니라 순서대로. "detach"의 d)
```

여기서 터미널을 닫아도, 노트북 뚜껑을 덮어도 다운로드는 계속된다.

```bash
# 4. 다시 들어가서 확인
tmux attach -t dl

# 5. 다 끝났으면 세션 안에서
exit
```

### 자주 쓰는 것만

| 상황 | 명령 / 키 |
| --- | --- |
| 세션 만들고 진입 | `tmux new -s dl` |
| 빠져나오기 (detach) | `Ctrl+b` → `d` |
| 세션 목록 | `tmux ls` |
| 다시 들어가기 | `tmux attach -t dl` |
| 세션이 하나뿐일 때 | `tmux a` |
| 위로 스크롤 | `Ctrl+b` → `[` , 방향키/PgUp, 나갈 때 `q` |
| 세션 통째로 죽이기 | `tmux kill-session -t dl` |
| 세션 종료 | 세션 안에서 `exit` |

`Ctrl+b`는 tmux의 **프리픽스 키**다. tmux 명령은 전부 이걸 먼저 누른 뒤에 온다.
누른 줄 모르고 `d`만 치면 그냥 `d`가 입력되니, 화면 아래 초록 막대가 보이는지로
tmux 안인지 확인하면 된다.

### tmux가 없다면

이미지에 따라 없을 수 있다. **`setup.sh` 실행 전에** 깔아야 의미가 있다.

```bash
apt-get update -qq && apt-get install -y -qq tmux
```

`screen`이 익숙하면 그쪽도 된다 (`screen -S dl` / 빠져나오기 `Ctrl+a` → `d` /
복귀 `screen -r dl`). `setup.sh`는 `$TMUX`와 `$STY`를 둘 다 검사한다.

### 이어받기

세션이 죽었든 다운로드가 실패했든, **같은 명령을 그대로 다시 실행하면 된다.**

- 완성된 파일은 `= 파일명`으로 표시하고 건너뛴다
- 받다 만 파일은 `.part`가 남아 있어 그 지점부터 이어받는다
- 실패는 즉시 중단하지 않고 모아 뒀다가 마지막에 목록으로 보고한다

---

## 프로필

| 프로필 | 내용 | 계열 |
| --- | --- | --- |
| `wai` | WAI-illustrious + Illustrious 계열 CN + AnimeSharp/Remacri + IP-Adapter. `tools`를 자동 포함 | SDXL |
| `tools` | 공용 도구 — FaceDetailer, 전처리기(DWPose·Depth·lineart), WD14 태거, USDU, Inpaint C&S | 공용 |
| `video` | Wan 2.2 — i2v 영상 생성 | 독립 |
| `krea` | Krea 2 Turbo — 지시문 기반 t2i (turbo/int8/raw) | 독립 |
| `dasiwa` | Wan 2.2 I2V DaSiWa-TastySin GGUF (NSFW LoRA 세트) | Wan 2.2 MoE |
| `smooth` | Wan 2.2 I2V SmoothMix (애니/실사 스타일 LoRA 세트) | Wan 2.2 MoE |
| `anima` | Anima — 애니메이션 특화 독립 t2i (aesthetic/turbo/base) | 독립 |
| `latentsync` | LatentSync 립싱크 (노드 폴더 안에 체크포인트 설치) | 독립 |

여러 개를 동시에 지정할 수 있고, 겹치는 파일은 한 번만 받는다.

```bash
./setup.sh wai video           # 부트스트랩 조합 (video 는 자동으로 5b)
./setup.sh krea tools          # tools 는 wai 가 아닌 프로필에서 쓰려면 직접 지정
```

**공통으로 깔리는 것은 없다.** 노드와 가중치는 필요한 프로필이 직접 선언한다.
`wai`는 내부에서 `tools`를 불러오므로 `./setup.sh wai` 하나로 SDXL 작업에 필요한 노드·가중치가
모두 깔린다. `krea`·`anima`·`video` 계열 단독 실행에서는 `tools`가 설치되지 않는다.

**ControlNet은 체크포인트 계열에 맞춰야 한다.** Illustrious 계열에는 계열을 맞춘 것을 쓴다.
범용 SDXL ControlNet을 물리면 화풍이 끌려가고 색이 탁해진다.

### 모드가 있는 프로필

같이 지정한 프로필에 따라 자동으로 가벼운 쪽으로 내려간다. 환경변수로 강제할 수 있다.

| 프로필 | 변수 | 값 | 기본 |
| --- | --- | --- | --- |
| `video` | `VIDEO` | `5b` (TI2V 단일) / `14b` (I2V MoE) | `14b`, `wai`와 함께면 `5b` |
| `krea` | `KREA` | `turbo` (8스텝) / `int8` (스타일 레퍼런스) / `raw` (52스텝, 학습용) | `turbo` |
| `krea` | `KREA_LORAS` | `1`이면 공식 스타일 LoRA 9종까지 함께 받음 | 미설정 |
| `anima` | `ANIMA` | `aesthetic` (v1.1, 별도 LoRA 없이 고품질) / `turbo` (8~12스텝) / `base` (LoRA 학습용) | `aesthetic` |

```bash
VIDEO=14b ./setup.sh video
KREA=raw ./setup.sh krea
```

---

## 프로필별 설치 파일

`setup.sh`가 실제로 받는 파일은 **프로필이 직접 선언한 것뿐**이다. 공통으로 깔리는 것은 없다.
아래는 `profiles/*.sh`를 그대로 반영한 현재 목록이다 (경로는 전부 `$BASE` = `/workspace/shared_models` 기준 상대경로).

### `tools` — 공용 도구

체크포인트 계열과 무관하게 쓰는 노드·전처리기·검출 모델. 특정 모델에 귀속시키기 애매해서 별도 프로필로 뺐다.
`wai`가 자동으로 불러오고, 다른 프로필에서 쓰려면 `./setup.sh krea tools`처럼 직접 지정한다.

| 폴더 | 파일 | 용도 |
| --- | --- | --- |
| `controlnet_aux/hr16/yolox-onnx` | `yolox_l.torchscript.pt` | DWPose 인물 검출 (GPU) |
| `controlnet_aux/hr16/DWPose-TorchScript-BatchSize5` | `dw-ll_ucoco_384_bs5.torchscript.pt` | DWPose 골격 추정 (GPU) |
| `controlnet_aux/yzd-v/DWPose` | `yolox_l.onnx` | DWPose 폴백 (CPU) |
| `controlnet_aux/depth-anything/Depth-Anything-V2-Large` | `depth_anything_v2_vitl.pth` | 깊이맵 추출 (1.3GB) |
| `wd14_tagger` | `wd-swinv2-tagger-v3.onnx` | WD14 태거 |
| `wd14_tagger` | `wd-swinv2-tagger-v3.csv` | WD14 태거 태그 목록 |
| `ultralytics/bbox` | `face_yolov8m.pt` | FaceDetailer 얼굴 검출 |
| `ultralytics/bbox` | `hand_yolov8s.pt` | FaceDetailer 손 검출 |
| `ultralytics/segm` | `person_yolov8m-seg.pt` | FaceDetailer 인물 세그멘테이션 |
| `sams` | `sam_vit_b_01ec64.pth` | 얼굴 경계 정리용 SAM (선택 사용) |

전처리기 가중치는 약 1.9GB, 검출 모델과 SAM은 약 0.5GB다.

커스텀 노드: `ComfyUI_UltimateSDUpscale` · `ComfyUI-Inpaint-CropAndStitch` · `ComfyUI-WD14-Tagger` ·
`comfyui_controlnet_aux` · `ComfyUI-Impact-Pack` · `ComfyUI-Impact-Subpack`
(노드 설정 — controlnet_aux 가중치 경로, WD14 기본값, Impact `install.py` — 은 프로필이 `POST_NODES` 훅으로 처리한다)

### `wai` — WAI-illustrious

`tools`를 자동으로 함께 설치한다. 여기에는 SDXL 체크포인트에만 묶이는 것을 둔다.

| 폴더 | 파일 | 비고 |
| --- | --- | --- |
| `checkpoints` | `WAI-illustrious-SDXL.safetensors` | civitai.red, `CIVITAI_TOKEN` 필요 |
| `clip_vision` | `CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` | IP-Adapter 클립 인코더 (약 4GB의 IP-Adapter 묶음) |
| `ipadapter` | `ip-adapter_sdxl_vit-h.safetensors` | IP-Adapter (기본) |
| `ipadapter` | `ip-adapter-plus_sdxl_vit-h.safetensors` | IP-Adapter Plus |
| `upscale_models` | `4x-AnimeSharp.pth` · `4x_foolhardy_Remacri.safetensors` | |
| `controlnet` | `Illustrious_openpose.safetensors` · `NoobAI_depth_midas.safetensors` · `Illustrious_lineart_anime.safetensors` | Illustrious 계열에 맞춘 것 |
| `loras` | 일반·캐릭터·체위 LoRA 다수 | civitai.red — 목록은 `profiles/wai.sh` 참고 |

커스텀 노드: `efficiency-nodes-comfyui` · `ComfyUI_IPAdapter_plus` (+ `tools`의 노드 전체)

### `video` — Wan 2.2 i2v

| 폴더 | 파일 | 비고 |
| --- | --- | --- |
| `diffusion_models` | `wan2.2_ti2v_5B_fp16.safetensors` | `VIDEO=5b` |
| `vae` | `wan2.2_vae.safetensors` | `VIDEO=5b` 전용 VAE |
| `diffusion_models` | `wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors` | `VIDEO=14b`, MoE high |
| `diffusion_models` | `wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors` | `VIDEO=14b`, MoE low |
| `vae` | `wan_2.1_vae.safetensors` | `VIDEO=14b` 전용 VAE |
| `loras` | `wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors` | `VIDEO=14b`, 4스텝 증류 |
| `loras` | `wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors` | `VIDEO=14b`, 4스텝 증류 |
| `loras` | `wan2.2_i2v_anime_style_v2_high_noise.safetensors` | `VIDEO=14b`, civitai |
| `loras` | `wan2.2_i2v_anime_style_v2_low_noise.safetensors` | `VIDEO=14b`, civitai |
| `text_encoders` | `umt5_xxl_fp8_e4m3fn_scaled.safetensors` | 두 모드 공유, 6.7GB |

커스텀 노드: `ComfyUI-VideoHelperSuite`

### `krea` — Krea 2 Turbo t2i

| 폴더 | 파일 | 비고 |
| --- | --- | --- |
| `diffusion_models` | `krea2_turbo_fp8_scaled.safetensors` | `KREA=turbo` (기본) |
| `diffusion_models` | `krea2_turbo_int8_convrot.safetensors` | `KREA=int8` |
| `loras` | `krea2_style_reference.safetensors` | `KREA=int8`, 스타일 레퍼런스 템플릿 전용 |
| `diffusion_models` | `krea2_raw_fp8_scaled.safetensors` | `KREA=raw` |
| `loras` | `krea2_turbo_lora_rank_64_bf16.safetensors` | `KREA=raw` |
| `text_encoders` | `qwen3vl_4b_fp8_scaled.safetensors` | 모드 공유 |
| `vae` | `qwen_image_vae.safetensors` | 모드 공유 |
| `loras` | `Krea2MythD4rkL1nes.safetensors` | 모드 공유, civitai |
| `loras` | `Niji_Sweet_Spot_Krea2_v2A.safetensors` | 모드 공유, civitai |
| `loras` | `snofs_krea_v1_1.safetensors` | 모드 공유, civitai.red |
| `loras` | `krea2_{darkbrush,dotmatrix,kidsdrawing,neondrip,rainywindow,retroanime,softwatercolor,sunsetblur,vintagetarot}.safetensors` | `KREA_LORAS=1`일 때만, 공식 스타일 9종 |

### `anima` — Anima (애니메이션 특화 t2i)

`SDXL`이 아닌 독립 베이스(Cosmos-Predict2-2B 파인튜닝). 커스텀 노드 없이 코어 로더만으로 동작한다.

| 폴더 | 파일 | 비고 |
| --- | --- | --- |
| `diffusion_models` | `anima-aesthetic-v1.1.safetensors` | `ANIMA=aesthetic` (기본) |
| `diffusion_models` | `anima-base-v1.0.safetensors` | `ANIMA=turbo` / `ANIMA=base` 공용 베이스 |
| `loras` | `anima-turbo-lora-v0.2.safetensors` | `ANIMA=turbo` |
| `text_encoders` | `qwen_3_06b_base.safetensors` | 모드 공유 |
| `vae` | `qwen_image_vae.safetensors` | 모드 공유. `krea`와 파일명이 같아 중복 다운로드 없음 |

라이선스: CircleStone Labs Non-Commercial License — 모델·LoRA 본체는 비상업 전용, 생성된 이미지 자체는 상업 이용 가능(모델 카드 명시).

### `dasiwa` — Wan 2.2 I2V DaSiWa-TastySin

| 폴더 | 파일 | 비고 |
| --- | --- | --- |
| `diffusion_models` | `Wan2_2-I2V-High-DaSiWa-TastySin-q8.gguf.safetensors` | MoE high, civitai.red |
| `diffusion_models` | `Wan2_2-I2V-Low-DaSiWa-TastySin-q8.gguf.safetensors` | MoE low, civitai.red |
| `vae` | `wan_2.1_vae.safetensors` | |
| `loras` | `NSFW-22-H-e8.safetensors` | |
| `loras` | `bounce_test_HighNoise-000005.safetensors` | |
| `loras` | `bounce_test_LowNoise-000005.safetensors` | |
| `loras` | `DR34ML4Y_I2V_14B_HIGH_V2.safetensors` | |
| `loras` | `DR34ML4Y_I2V_14B_LOW_V2.safetensors` | |
| `text_encoders` | `umt5_xxl_fp8_e4m3fn_scaled.safetensors` | |

커스텀 노드: `ComfyUI-VideoHelperSuite`

### `smooth` — Wan 2.2 I2V SmoothMix

| 폴더 | 파일 | 비고 |
| --- | --- | --- |
| `diffusion_models` | `SmoothMix_I2V_High_v2.safetensors` | MoE high, civitai.red |
| `diffusion_models` | `SmoothMix_I2V_Low_v2.safetensors` | MoE low, civitai.red |
| `vae` | `wan_2.1_vae.safetensors` | |
| `loras` | `SmoothXXXAnimation_High.safetensors` | |
| `loras` | `SmoothXXXAnimation_Low.safetensors` | |
| `loras` | `bounce_test_HighNoise-000005.safetensors` | |
| `loras` | `bounce_test_LowNoise-000005.safetensors` | |
| `loras` | `DR34ML4Y_I2V_14B_HIGH_V2.safetensors` | |
| `loras` | `DR34ML4Y_I2V_14B_LOW_V2.safetensors` | |
| `loras` | `wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors` | |
| `loras` | `wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors` | |
| `text_encoders` | `umt5_xxl_fp8_e4m3fn_scaled.safetensors` | |

커스텀 노드: `ComfyUI-VideoHelperSuite`

---

## 용량 (볼륨 100GB 기준)

조합별 누계다. 개별 프로필을 더하면 안 된다 — 공통 파일이 겹친다.

| 명령 | 누계 |
| --- | --- |
| `./setup.sh video` (5b) | ~18GB |
| `./setup.sh video` (14b) | ~32GB |
| `./setup.sh krea` (turbo) | ~19GB |
| `./setup.sh anima` (aesthetic/turbo/base) | ~5.6GB |

위 수치는 공통 전처리기(약 1.9GB)가 모든 프로필에 깔리던 때 잰 값이다. 지금은 `tools`를 쓰지 않으면
설치되지 않으므로 실제로는 그만큼 적을 수 있다. `wai`(+`tools`)는 체크포인트와 LoRA가 많아 누계를 다시 재지 않았다.

`dasiwa`/`smooth`는 각각 diffusion_models 2개(고/저노이즈) + LoRA 6~7종 조합으로, 단독 실행 시 대략 20GB대 후반(diffusion_models ~14GB + LoRA ~4GB + 공유 text_encoder ~6.7GB)이지만 프로필 파일에 공식 누계가 기록돼 있지 않다.

- **볼륨 100GB / 컨테이너 20\~30GB** 권장
- 모델은 전부 `/workspace` 아래로 간다 → **볼륨**이 늘어나야 한다
- 컨테이너로 새는 것은 pip 캐시 정도. venv 탐색이 실패해 시스템 python으로 떨어지면
  pip 설치분이 전부 컨테이너로 간다. 확인:
  `"$PY" -c "import sys; print(sys.prefix)"` → `/workspace`로 시작하면 정상

---

## 토큰

파드는 매번 새로 만들지만 `/workspace`는 볼륨이라 살아남는다. 파일로 한 번만 넣어 두면 된다.

```bash
printf '%s' '<civitai 키>' > /workspace/.civitai_token && chmod 600 /workspace/.civitai_token
printf '%s' '<hf 키>'      > /workspace/.hf_token      && chmod 600 /workspace/.hf_token
```

환경변수가 우선이므로 한 번만 다르게 쓰려면 앞에 붙이면 된다.

```bash
CIVITAI_TOKEN=xxxx ./setup.sh wai
```

| 토큰 | 필요한 프로필 | 비고 |
| --- | --- | --- |
| `CIVITAI_TOKEN` | `wai`, `dasiwa`, `smooth`, `krea`(LoRA) | civitai API 다운로드에 필요. 쿼리 파라미터로 붙는다 (헤더는 CDN 리다이렉트에서 잘림) |
| `HF_TOKEN` | 현재 필수인 프로필 없음 | 게이트 저장소를 받는 프로필을 추가할 때(`NEED_HF_TOKEN=1`). **웹에서 약관 동의를 먼저** 해야 한다 |

**civitai 403 이슈**: `civitai.com` 직링크는 `b2.civitai.com`으로 리다이렉트되면 403이
난다(civitai #2113). R2로 배정되면 되고 B2면 안 되는데 어느 쪽일지는 서버가 정하고,
재시도로는 못 뚫는다. 그래서 `wai`는 `civitai.red` 미러를 쓴다.

---

## 환경변수 정리

| 변수 | 기본 | 용도 |
| --- | --- | --- |
| `VIDEO` | 자동 | `5b` / `14b` |
| `KREA` | `turbo` | `turbo` / `int8` / `raw` |
| `KREA_LORAS` | 미설정 | `1`이면 공식 스타일 LoRA 9종 추가 |
| `ANIMA` | `aesthetic` | `aesthetic` / `turbo` / `base` |
| `CIVITAI_TOKEN` | `/workspace/.civitai_token` | civitai 인증 |
| `HF_TOKEN` | `/workspace/.hf_token` | HF 게이트 저장소 인증 |
| `DL_RETRIES` | `5` | 파일당 재시도 횟수 |

---

## 구조

```
lomebrote/
├── README.md
├── setup.sh                    프로필 로드 + 노드 clone + 다운로드 (공통 설치분 없음)
├── move_comfy_output.sh        ComfyUI/output → /workspace/output 심볼릭 링크 (setup.sh 가 호출)
├── extra_model_paths.yaml      ComfyUI 모델 경로 설정
├── profiles/
│   ├── wai.sh                  WAI-illustrious (tools 자동 포함)
│   ├── tools.sh                공용 도구 (FaceDetailer·전처리기·태거·USDU)
│   ├── video.sh                Wan 2.2
│   ├── dasiwa.sh               Wan 2.2 DaSiWa
│   ├── smooth.sh               Wan 2.2 SmoothMix
│   ├── krea.sh                 Krea 2
│   ├── anima.sh                Anima
│   └── latentsync.sh           립싱크
└── workflows/
    └── *.json                  ComfyUI 워크플로우
```

`setup.sh`는 **자기 위치를 저장소로 본다**(`REPO="$SELF"`). 프로필도
`extra_model_paths.yaml`도 `workflows/`도 전부 스크립트가 있는 폴더 기준이라,
저장소를 `/workspace/lomebrote` 밖에 두어도 그대로 동작한다.
*(예전에는 `REPO`가 하드코딩이라 위치를 옮기면 yaml 복사가 조용히 깨졌다.)*

### 경로 상수

| 변수 | 경로 | 용도 |
| --- | --- | --- |
| `COMFY` | `/workspace/runpod-slim/ComfyUI` | ComfyUI 본체 |
| `BASE` | `/workspace/shared_models` | 모든 모델 |
| `PROJ` | `/workspace/files` | 깊이맵, 데이터셋, 영상 입출력 (예전 이름 `project_lomebrote`) |
| `OUTPUT` | `/workspace/output` | 생성된 이미지·영상. `ComfyUI/output` 은 이쪽을 가리키는 심볼릭 링크 |
| `REPO` | = `$SELF` | 이 저장소 |

`setup.sh`는 예전 `/workspace/project_lomebrote` 가 남아 있고 `/workspace/files` 가 없으면
폴더째 `files`로 옮긴다. 그 안의 `output_keep/` 은 `/workspace/output` 으로 합친다
(같은 이름의 파일은 덮어쓰지 않고 `output_keep/` 에 남기며, 남았다는 경고를 낸다).

### 프로필 계약

공통으로 깔리는 것은 없다. 필요한 노드·가중치는 프로필이 직접 선언한다.

```bash
FILES+=( "저장폴더|파일명|URL" )              # 받을 파일
NODE_REPOS+=( "폴더명|git URL|서브모듈여부" )  # 필요한 커스텀 노드
POST_NODES+=( 함수명 )                         # 노드 clone·requirements 이후에 할 설정 ([4/5] 에서 호출)
load_profile tools                            # 다른 프로필의 구성이 필요할 때 (중복 로드 방지됨)
NEED_HF_TOKEN=1                               # HF 게이트 파일을 받으면 선언 (사전 경고용)
```

새 프로필은 기존 파일을 복사해 URL만 갈아끼우면 된다. `FILES`/`NODE_REPOS`/`POST_NODES`는
`setup.sh`가 프로필을 `source` 하기 전에 먼저 선언해 둔다. 함께 지정된 프로필 이름은
`PROFILES` 배열로 볼 수 있다(`video.sh` 가 5b 자동 선택에 사용).
`POST_NODES` 함수는 마지막 명령이 실패하면 `set -e` 로 전체가 죽으므로 `[ ... ] && ...` 대신 `if` 를 쓴다.

---

## 커스텀 노드

### `tools` (`wai`가 자동 포함)

| 노드 | 용도 |
| --- | --- |
| `ComfyUI_UltimateSDUpscale` | USDU 타일 업스케일 (서브모듈 필요) |
| `ComfyUI-Inpaint-CropAndStitch` | 인페인팅 영역 확대 후 재합성 |
| `ComfyUI-WD14-Tagger` | booru 태그 추출 (애니 계열에서만 유용) |
| `comfyui_controlnet_aux` | DWPose, DepthAnythingV2 등 전처리기 |
| `ComfyUI-Impact-Pack` + `-Subpack` | FaceDetailer. v8.0부터 둘 다 필요 |

### 프로필별 추가

| 프로필 | 노드 |
| --- | --- |
| `wai` | `efficiency-nodes-comfyui` (XY Plot, KSampler (Efficient) — jags111 포크가 유지판), `ComfyUI_IPAdapter_plus` |
| `video`, `dasiwa`, `smooth` | `ComfyUI-VideoHelperSuite` (영상 *로드*용. mp4 저장은 코어 `SaveVideo` 노드로 된다) |
| `dasiwa` | `ComfyUI-GGUF` |
| `latentsync` | `ComfyUI-LatentSyncWrapper` |

### 전처리기 가중치 (`tools`, 약 1.9GB)

| 파일 | 크기 | 용도 |
| --- | --- | --- |
| `yolox_l.torchscript.pt` | ~200MB | DWPose 인물 검출 (GPU) |
| `dw-ll_ucoco_384_bs5.torchscript.pt` | ~200MB | DWPose 골격 추정 (GPU) |
| `yolox_l.onnx` | ~200MB | DWPose 폴백 (CPU) |
| `depth_anything_v2_vitl.pth` | 1.3GB | 깊이맵 추출 |

`EP_list`가 `CPUExecutionProvider`인 이유는 `onnxruntime-gpu` 설치가 번거롭기 때문이다.
노드에서 `.torchscript.pt` 계열을 고르면 torch가 GPU를 쓴다.

---

## 권장 설정 (SDXL 계열)

| | wai |
| --- | --- |
| CFG | 4\~7 |
| Steps | 28\~32 |
| 샘플러 | Euler a |
| 프롬프트 | booru 태그 |
| 네거티브 | 품질 태그 계열 |
| CN end\_percent | 포즈 0.4 / 깊이 0.8 |

**Wan은 다르다.** 태그 나열이 아니라 문장형 지시문·서술을 쓴다.
특히 i2v에서는 이미지 내용이 아니라 **무엇이 어떻게 움직이는지**를 쓴다.

---

## 트러블슈팅

### 드롭다운이 비어 있다

거의 항상 `extra_model_paths.yaml` 키가 없거나 파드를 재시작하지 않은 경우다.

| 빈 드롭다운 | 필요한 키 |
| --- | --- |
| FaceDetailer 감지 모델 | `ultralytics_bbox`, `ultralytics_segm`, `sams` |
| Wan / Krea / Anima 로더 | `diffusion_models`, `text_encoders`, `unet` |

`ultralytics/` 아래 `bbox`와 `segm`은 **하위 폴더 구조 그대로** 있어야 한다.
평평하게 두면 Impact Subpack이 못 찾는다.

### IP-Adapter Unified Loader가 인식을 못 한다

파일명이 글자 하나까지 같아야 한다. 원본이 `model.safetensors`라 리네임이 필수다.

```
clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors
ipadapter/ip-adapter_sdxl_vit-h.safetensors
```

### Impact Pack이 통째로 IMPORT FAILED

Manager 없이 손으로 clone하면 `impact-pack.ini`가 안 생긴다. `setup.sh`가
`install.py`를 대신 돌리지만 실패할 수 있으니, 기동 후 콘솔에서 확인할 것.

### requirements 설치가 ResolutionImpossible로 죽는다

RunPod 이미지가 `PIP_CONSTRAINT`로 torch 로컬 버전 휠(`+cuXXX`)을 못박아 두는데,
pip의 빌드 격리 환경은 PyPI만 본다. `setup.sh`는 격리를 끄고 설치하며, 그래도 안 되면
건너뛴다. Impact Subpack의 `sam2`는 SAM2 전용이라 FaceDetailer에는 없어도 된다.

### 영상 모델 템플릿이 안 보인다

ComfyUI 코어 버전 문제다. `setup.sh`가 기동 시 버전을 찍어 준다.
Wan 2.2 템플릿은 0.3.46 이상, Anima는 **0.11.1 이상**이 필요하다.

```bash
git -C /workspace/runpod-slim/ComfyUI pull
# 이후 파드 Restart
```

### Wan 결과가 죽처럼 나온다

VAE를 바꿔 물린 경우다. **5B는 `wan2.2_vae`, 14B는 `wan_2.1_vae`**다.
증상이 애매해서 가장 오래 헤매는 함정.

### 다운로드가 "크기 이상"으로 실패

HTML 오류 페이지를 받은 것이다(100KB 미만이면 자동 삭제). URL이나 토큰을 확인할 것.
