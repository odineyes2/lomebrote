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
./setup.sh anime qwen video
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
cd /workspace/lomebrote && ./setup.sh anime qwen video

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
| `real` | RealVisXL V5.0 + xinsir ControlNet + UltraSharpV2 | SDXL |
| `anime` | Illustrious XL v1.1 (공식 베이스) + Illustrious 계열 CN + AnimeSharp | SDXL |
| `nsfw` | WAI-illustrious + Illustrious 계열 CN + AnimeSharp | SDXL |
| `retro` | Retrordinary (Illustrious 계열) + 위와 동일 | SDXL |
| `qwen` | Qwen-Image-Edit 2511 — 지시문 기반 편집 | 독립 |
| `video` | Wan 2.2 — i2v 영상 생성 | 독립 |
| `ltx` | LTX-2.5 — 영상+오디오 동시 생성 (실험적) | 독립 |

여러 개를 동시에 지정할 수 있고, 겹치는 파일은 한 번만 받는다.

```bash
./setup.sh anime nsfw          # 체크포인트만 다르고 나머지 공유
./setup.sh anime qwen video    # 부트스트랩 조합
```

`real` / `anime` / `nsfw` / `retro`는 `SDXL=1`을 선언해서 IP-Adapter와 FaceDetailer
감지 모델(약 4.5GB)을 함께 받는다. `qwen` / `video` / `ltx` 단독 실행에서는 건너뛴다.

**ControlNet은 체크포인트 계열에 맞춰야 한다.** 실사에는 범용 SDXL(xinsir),
Illustrious 계열에는 계열을 맞춘 것. 반대로 물리면 화풍이 끌려가고 색이 탁해진다.

### 모드가 있는 프로필

같이 지정한 프로필에 따라 자동으로 가벼운 쪽으로 내려간다. 환경변수로 강제할 수 있다.

| 프로필 | 변수 | 값 | 기본 |
| --- | --- | --- | --- |
| `qwen` | `QWEN` | `fp8` (20.5GB) / `gguf` (Q5\_K\_M, 15GB) | `fp8`, `ltx`나 `video=14b`와 함께면 `gguf` |
| `video` | `VIDEO` | `5b` (TI2V 단일) / `14b` (I2V MoE) | `14b`, 다른 프로필과 함께면 `5b` |
| `ltx` | `LTX` | `distilled` (8스텝) / `dev` (학습 가능) | `distilled` |

```bash
VIDEO=14b ./setup.sh video
QWEN=gguf ./setup.sh anime qwen
```

---

## 용량 (볼륨 100GB 기준)

조합별 누계다. 개별 프로필을 더하면 안 된다 — 공통 파일이 겹친다.

| 명령 | 누계 |
| --- | --- |
| `./setup.sh anime` | ~21GB |
| `./setup.sh anime nsfw` | ~28GB (체크포인트 하나만 추가) |
| `./setup.sh qwen` (fp8) | ~37GB |
| `./setup.sh qwen` (gguf) | ~32GB |
| `./setup.sh video` (5b) | ~18GB |
| `./setup.sh video` (14b) | ~32GB |
| `./setup.sh ltx` | ~40GB |
| `./setup.sh anime qwen` (fp8) | ~52GB |
| **`./setup.sh anime qwen video`** | **~70GB** ← 권장 |
| `VIDEO=14b ./setup.sh anime qwen video` | ~78GB (qwen 자동 gguf) |

`ltx`는 `qwen`과 함께 쓰지 않는 편이 낫다. 영상 전용 파드로 분리하는 게 편하다.

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
CIVITAI_TOKEN=xxxx ./setup.sh nsfw
```

| 토큰 | 필요한 프로필 | 비고 |
| --- | --- | --- |
| `CIVITAI_TOKEN` | `nsfw`, `retro` | civitai API 다운로드에 필요. 쿼리 파라미터로 붙는다 (헤더는 CDN 리다이렉트에서 잘림) |
| `HF_TOKEN` | `ltx` | 게이트 저장소용. **웹에서 약관 동의를 먼저** 해야 한다 |

`ltx`를 쓰려면 [huggingface.co/Lightricks/LTX-2.5](https://huggingface.co/Lightricks/LTX-2.5)
에서 동의 후 토큰을 넣는다. 둘 중 하나라도 빠지면 401이 난다.

**civitai 403 이슈**: `civitai.com` 직링크는 `b2.civitai.com`으로 리다이렉트되면 403이
난다(civitai #2113). R2로 배정되면 되고 B2면 안 되는데 어느 쪽일지는 서버가 정하고,
재시도로는 못 뚫는다. 그래서 `nsfw`/`retro`는 `civitai.red` 미러를 쓴다.

---

## 환경변수 정리

| 변수 | 기본 | 용도 |
| --- | --- | --- |
| `QWEN` | 자동 | `fp8` / `gguf` |
| `VIDEO` | 자동 | `5b` / `14b` |
| `LTX` | `distilled` | `distilled` / `dev` |
| `CIVITAI_TOKEN` | `/workspace/.civitai_token` | civitai 인증 |
| `HF_TOKEN` | `/workspace/.hf_token` | HF 게이트 저장소 인증 |
| `DL_RETRIES` | `5` | 파일당 재시도 횟수 |

---

## 구조

```
lomebrote/
├── README.md
├── setup.sh                    공통 설치 + 프로필 로드 + 다운로드
├── extra_model_paths.yaml      ComfyUI 모델 경로 설정
├── profiles/
│   ├── real.sh
│   ├── anime.sh
│   ├── nsfw.sh
│   ├── retro.sh
│   ├── qwen.sh                 Qwen-Image-Edit 2511
│   ├── video.sh                Wan 2.2
│   └── ltx.sh                  LTX-2.5 (실험적)
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
| `PROJ` | `/workspace/project_lomebrote` | 출력물, 깊이맵, 데이터셋, 영상 입출력 |
| `REPO` | = `$SELF` | 이 저장소 |

### 프로필 계약

프로필이 하는 일은 세 가지뿐이다.

```bash
FILES+=( "저장폴더|파일명|URL" )              # 받을 파일
NODE_REPOS+=( "폴더명|git URL|서브모듈여부" )  # 필요한 커스텀 노드
SDXL=1                                        # SDXL 계열이면 선언 (IPAdapter 블록 조건)
NEED_HF_TOKEN=1                               # HF 게이트 파일을 받으면 선언 (사전 경고용)
```

새 프로필은 기존 파일을 복사해 URL만 갈아끼우면 된다. `NODE_REPOS+=`는 반드시
`setup.sh`의 `source` 지점 아래에서 동작하도록 배열이 먼저 선언돼 있다.

---

## 커스텀 노드

### 공통

| 노드 | 용도 |
| --- | --- |
| `ComfyUI_UltimateSDUpscale` | USDU 타일 업스케일 (서브모듈 필요) |
| `ComfyUI-Inpaint-CropAndStitch` | 인페인팅 영역 확대 후 재합성 |
| `ComfyUI-WD14-Tagger` | booru 태그 추출 (애니 계열에서만 유용) |
| `comfyui_controlnet_aux` | DWPose, DepthAnythingV2 등 전처리기 |
| `efficiency-nodes-comfyui` | XY Plot, KSampler (Efficient) — jags111 포크가 유지판 |
| `ComfyUI_IPAdapter_plus` | IP-Adapter |
| `ComfyUI-Impact-Pack` + `-Subpack` | FaceDetailer. v8.0부터 둘 다 필요 |

### 프로필별 추가

| 프로필 | 노드 |
| --- | --- |
| `qwen` | `ComfyUI-GGUF` (fp8 모드에서도 설치 — 나중에 GGUF로 내려갈 때 재실행이 줄어든다) |
| `video`, `ltx` | `ComfyUI-VideoHelperSuite` (영상 *로드*용. mp4 저장은 코어 `SaveVideo` 노드로 된다) |

### 전처리기 가중치 (프로필 무관, 약 1.9GB)

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

| | real | anime / nsfw / retro |
| --- | --- | --- |
| CFG | 3\~6 | 4\~7 |
| Steps | 25\~35 | 28\~32 |
| 샘플러 | DPM++ 2M Karras | Euler a |
| 프롬프트 | 자연어 + 사진 용어 | booru 태그 |
| 네거티브 | `cartoon, anime, 3d render, illustration` | 품질 태그 계열 |
| CN end\_percent | 포즈 0.4 / 깊이 0.8 | 포즈 0.4 / 깊이 0.8 |

**실사 프롬프트.** `masterpiece` 같은 품질 태그는 효과가 없거나 해롭다.
대신 사진 용어가 품질 태그 역할을 한다 — 렌즈(35mm, 85mm), 조명(golden hour,
overcast), 심도.

```
a weathered old man in a wool coat standing on a stone bridge,
overcast evening light, shallow depth of field, 35mm photograph
```

**Qwen / Wan은 다르다.** 태그 나열이 아니라 문장형 지시문·서술을 쓴다.
특히 i2v에서는 이미지 내용이 아니라 **무엇이 어떻게 움직이는지**를 쓴다.

---

## 트러블슈팅

### 드롭다운이 비어 있다

거의 항상 `extra_model_paths.yaml` 키가 없거나 파드를 재시작하지 않은 경우다.

| 빈 드롭다운 | 필요한 키 |
| --- | --- |
| FaceDetailer 감지 모델 | `ultralytics_bbox`, `ultralytics_segm`, `sams` |
| Qwen / Wan 로더 | `diffusion_models`, `text_encoders`, `unet` |
| LTX duration head | `model_patches` |
| LTX 업스케일러 | `latent_upscale_models` (안 뜨면 `upscale_models/`로 옮겨 볼 것) |

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
Wan 2.2 템플릿은 0.3.46 이상, LTX-2.5는 **0.32.0 이상**이 필요하다.

```bash
git -C /workspace/runpod-slim/ComfyUI pull
# 이후 파드 Restart
```

### Wan 결과가 죽처럼 나온다

VAE를 바꿔 물린 경우다. **5B는 `wan2.2_vae`, 14B는 `wan_2.1_vae`**다.
증상이 애매해서 가장 오래 헤매는 함정.

### 다운로드가 "크기 이상"으로 실패

HTML 오류 페이지를 받은 것이다(100KB 미만이면 자동 삭제). URL이나 토큰을 확인할 것.
