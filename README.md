# lomebrote

RunPod ComfyUI 환경 세팅. 파드는 작업 후 매번 terminate하고 네트워크 볼륨이 없으므로,
유지되어야 하는 것은 전부 이 저장소 안에 있어야 한다.

---

## 빠른 시작

```bash
cd /workspace && git clone https://github.com/odineyes2/lomebrote.git
cd /workspace/lomebrote
./setup.sh real          # 실사
./setup.sh anime         # 애니 (Illustrious 공식 베이스)
./setup.sh nsfw          # 애니 NSFW (WAI)
./setup.sh anime nsfw    # 둘 다. 겹치는 파일은 한 번만 받는다.
./setup.sh               # 프로필 목록 출력
```

실행 후 **RunPod 콘솔에서 파드를 Restart** 해야 `extra_model_paths.yaml`이 적용된다.

완료 시점에 프로필별 권장 설정(CFG, 샘플러, ControlNet 값)이 출력된다.

---

## 구조

```
lomebrote/
├── README.md
├── setup.sh                    공통 설치 + 프로필 로드 + 다운로드
├── extra_model_paths.yaml      ComfyUI 모델 경로 설정
├── profiles/
│   ├── real.sh                 RealVisXL + xinsir CN + UltraSharpV2
│   ├── anime.sh                Illustrious XL v1.1 + Illustrious CN + AnimeSharp
│   └── nsfw.sh                 WAI + Illustrious CN + AnimeSharp
└── workflows/
    └── *.json                  ComfyUI 워크플로우
```

`setup.sh`는 프로필을 **자기 위치 기준**(`$SELF/profiles/`)으로 찾는다.
따라서 `setup.sh`와 `profiles/`는 항상 같은 폴더에 있어야 하고, 저장소를 다른 곳에
두어도 동작한다. 반면 `extra_model_paths.yaml`과 `workflows/`는 `$REPO` 상수를
그대로 참조하므로 경로가 바뀌면 스크립트 상단의 `REPO=`도 같이 고쳐야 한다.

경로 상수:

| 변수 | 경로 | 용도 |
|---|---|---|
| `COMFY` | `/workspace/runpod-slim/ComfyUI` | ComfyUI 본체 |
| `BASE` | `/workspace/shared_models` | 모든 모델 |
| `PROJ` | `/workspace/project_lomebrote` | 출력물, 깊이맵 |
| `REPO` | `/workspace/lomebrote` | 이 저장소 |

---

## 프로필

프로필은 `FILES` 배열에 `저장폴더|파일명|URL` 을 덧붙이고 `HINT`에 안내문을 넣는 것뿐이다.
새 프로필은 기존 파일을 복사해 URL만 갈아끼우면 된다.

| 항목 | real | anime | nsfw |
|---|---|---|---|
| 체크포인트 | RealVisXL V5.0 fp16 (6.94GB) | Illustrious XL v1.1 (6.94GB) | WAI-illustrious-SDXL (~6.9GB) |
| 업스케일러 | 4x-UltraSharpV2 (140MB) | 4x-AnimeSharp (~67MB) | 4x-AnimeSharp (~67MB) |
| CN 포즈 | xinsir_openpose (2.5GB) | Illustrious_openpose (~2.5GB) | Illustrious_openpose (~2.5GB) |
| CN 깊이 | xinsir_depth (2.5GB) | NoobAI_depth_midas (~2.5GB) | NoobAI_depth_midas (~2.5GB) |
| WD14 태거 | 없음 | onnx + csv (~400MB) | onnx + csv (~400MB) |
| 총 용량 | ~14GB | ~14.3GB | ~14.3GB |

**ControlNet은 체크포인트 계열에 맞춰야 한다.** 실사에는 범용 SDXL(xinsir),
Illustrious 계열에는 계열을 맞춘 것. 반대로 물리면 화풍이 끌려가고 색이 탁해진다.

`anime`과 `nsfw`는 체크포인트만 다르고 나머지를 공유한다. 같이 지정해도 7GB만 늘어난다
(다운로드 루프의 "이미 있으면 건너뜀" 검사가 중복을 처리하므로 별도 로직 없음).

| 명령 | 받는 항목 | 용량 |
|---|---|---|
| `./setup.sh real` | 8 | ~14GB |
| `./setup.sh anime` | 10 | ~14.3GB |
| `./setup.sh nsfw` | 10 | ~14.3GB |
| `./setup.sh anime nsfw` | 11 (13개 중 2개 중복) | ~21GB |
| `./setup.sh real anime` | 14 | ~26GB |

---

## 권장 설정

| | real | anime / nsfw |
|---|---|---|
| CFG | 3~6 | 4~7 |
| Steps | 25~35 | 28~32 |
| 샘플러 | DPM++ 2M Karras | Euler a |
| 프롬프트 | 자연어 + 사진 용어 | booru 태그 |
| 네거티브 | `cartoon, anime, 3d render, illustration` | 품질 태그 계열 |
| CN end_percent | 포즈 0.4 / 깊이 0.8 | 포즈 0.4 / 깊이 0.8 |

**실사 프롬프트.** `masterpiece` 같은 품질 태그는 효과가 없거나 해롭다.
대신 사진 용어가 품질 태그 역할을 한다 — 렌즈(35mm, 85mm), 조명(golden hour, overcast), 심도.

```
a weathered old man in a wool coat standing on a stone bridge,
overcast evening light, shallow depth of field, 35mm photograph
```

**WAI에서 선정성을 줄이려면.** `full body` / `wide shot`으로 카메라를 빼는 게 효과가 크다.
데이터셋의 선정성이 클로즈업~상반신 구간에 몰려 있어서, 인물 비중을 줄이면 그 영역을 벗어난다.
네거티브에는 `looking at viewer`와 `from below`가 가장 효과적이다 —
booru 데이터셋에서 이 두 태그가 도발적 포즈·앵글과 강하게 얽혀 있어 기본값처럼 작동한다.
품질 태그 `very aesthetic`도 미소녀 서브셋으로 끌어당기므로 빼고 비교해볼 것.

**ControlNet end_percent.** 깊이는 포즈(0.4)보다 높게 간다. 배경은 후반까지 구조를 잡아야
원근선이 안 무너진다. 0.8 근처에서 내려오며 탐색.

**깊이맵 규약.** 가까울수록 밝음. Blender Z pass는 반대로 나오기 쉬우니 미리보기로 확인할 것.
Blender 블록아웃 렌더는 `$PROJ/depthmaps`에 올려두고 Load Image로 읽는다.

---

## 공통 구성

### 커스텀 노드

| 노드 | 용도 |
|---|---|
| ComfyUI_UltimateSDUpscale | USDU 타일 업스케일 (서브모듈 필요) |
| ComfyUI-Inpaint-CropAndStitch | 인페인팅 영역 확대 후 재합성 |
| ComfyUI-WD14-Tagger | booru 태그 추출 (애니 계열에서만 유용) |
| comfyui_controlnet_aux | DWPose, DepthAnythingV2 등 전처리기 |

### 전처리기 가중치 (프로필 무관, 약 1.9GB)

| 파일 | 크기 | 용도 |
|---|---|---|
| `yolox_l.torchscript.pt` | ~200MB | DWPose 인물 검출 (GPU) |
| `dw-ll_ucoco_384_bs5.torchscript.pt` | ~200MB | DWPose 골격 추정 (GPU) |
| `yolox_l.onnx` | ~200MB | DWPose 폴백 (CPU) |
| `depth_anything_v2_vitl.pth` | 1.3GB | 깊이맵 추출 |

---

## 함정 모음

파드를 새로 만들 때마다 다시 밟기 쉬운 것들.

**전처리기 가중치 경로.** 기본 저장 위치가 노드 폴더 안(`./ckpts`)이라 노드를 다시 클론하면
같이 날아간다. `config.yaml`의 `annotator_ckpts_path`를 `$BASE/controlnet_aux`로 뺐다.
저장 구조가 `<ckpts>/<HF 저장소명>/<파일명>` 이어야 노드가 로컬 파일로 인식한다.

**EP_list가 CPU인 이유.** onnxruntime-gpu는 CUDA 12에서 별도 인덱스가 필요해 설치가 번거롭다.
대신 노드에서 `.torchscript.pt` 계열을 고르면 torch가 알아서 GPU를 쓴다.

**MiDaS는 예외.** `annotator_ckpts_path`를 안 따르고 transformers가 `~/.cache/huggingface`로
직접 받는다. 필요하면:

```bash
HF_HOME=$BASE/hf_cache "$PY" -c \
  "from huggingface_hub import snapshot_download as d; d('Intel/dpt-hybrid-midas')"
```

**WD14 태거 파일명.** `.onnx`와 `.csv` 이름이 모델명과 같아야 로컬 모델로 인식한다.
`pysssss.json`은 클론한 저장소 안에 있어 파드마다 초기화되므로 `settings`만 매번 덮어쓴다.

**다운로드 실패 감지.** URL이 죽거나 HF가 gated면 HTML 오류 페이지를 받는다.
크기가 100KB 미만이면 실패로 보고 중단한다. gated 저장소는 웹에서 한 번 수락한 뒤
`--header="Authorization: Bearer <HF_TOKEN>"` 을 붙여야 한다.

---

## 운영 메모

### 디스크

모델은 전부 `/workspace` 아래 → **볼륨 디스크**가 늘어나야 한다.
컨테이너 디스크로 새는 것은 pip 캐시와 (`DEPTH_AB` 계열 작업 시) MiDaS 캐시 정도.

- 볼륨 60GB / 컨테이너 20~30GB 권장.
- venv 탐색이 실패해 시스템 python으로 떨어지면 pip 설치분이 전부 컨테이너로 간다.
  확인: `"$PY" -c "import sys; print(sys.prefix)"` → `/workspace`로 시작하면 정상.

### 다운로드 속도

`wget`은 단일 연결이라 HF 대용량 파일(Xet 백엔드)에서 느리다. Civitai는 R2 직결이라 빠르다.
느리면 출처를 바꾸지 말고 다운로더를 바꾼다 — Civitai URL은 버전 정리 시 죽어서
파드 세션이 통째로 막힌다.

```bash
apt-get install -y -qq aria2
aria2c -x 16 -s 16 -k 1M -d "$dir" -o "$name" "$url"
```

또는 HF 전용:

```bash
"$PY" -m pip install -q huggingface_hub[hf_transfer]
export HF_HUB_ENABLE_HF_TRANSFER=1
```

### 미해결

- `extra_model_paths.yaml`이 프로필과 무관하게 공통 복사된다. 지금은 전부 `$BASE` 하나를
  보고 있어 문제없지만, Flux 등 다른 아키텍처를 프로필로 추가하면 이것도 `profiles/`로 내려야 한다.
- 단계별 소요 시간 측정이 없다. 느려질 때 원인 추적이 어렵다.

---

## 기법 메모

**전역 vs 국소.** 캔버스 전체를 보며 작동하는 기법은 안정적이고, 일부만 보는 기법은 겉돈다.
하이레즈픽스·ControlNet은 전역이라 잘 되고, 인페인팅과 USDU는 국소라 편차가 크다.

**인페인팅이 약한 이유.** SDXL 계열에는 전용 인페인팅 체크포인트가 사실상 없다.
일반 모델에 억지로 시키는 것이므로 잘 안 되는 게 정상. 개선 수단은 효과 순으로:

1. **Inpaint Crop & Stitch** — 마스크 주변을 잘라 1024로 확대 후 인페인팅하고 되돌린다.
   1024 이미지에서 200px 얼굴을 고치면 SDXL이 제대로 작동하는 해상도가 아니다. 효과가 가장 크다.
2. **Fooocus inpaint patch** (`comfyui-inpaint-nodes`) — SDXL 인페인팅 보정.
3. **Differential Diffusion** (코어 노드) — 마스크를 연속 강도로 해석해 이음새를 줄인다.
4. denoise 0.5~0.7 + 마스크 blur 8~16px. 1.0은 백지에서 새로 그리는 것이라 겉돈다.

세계관 초기 단계에서는 인페인팅으로 한 장을 붙드는 것보다 시드를 여러 개 뽑아 고르는 편이
시간당 산출이 낫다. 인페인팅은 "이 컷은 반드시 살려야 한다"는 상황용.

**USDU 편차의 원인.**

- 프롬프트가 모든 타일에 똑같이 들어간다. `1girl, detailed face`로 돌리면 벽 타일에도 얼굴을
  그린다. USDU용 프롬프트는 주제어를 빼고 `masterpiece, detailed texture` 정도만 남긴다.
- denoise 0.15~0.25가 안전 구간. 0.35를 넘으면 타일마다 다른 해석을 시작해 이음새가 튄다.

**체크포인트 릴레이.** 확산은 "노이즈→이미지" 한 방이 아니라 궤적이므로 중간에 모델을 바꿀 수 있다.

- 같은 latent 공간(SDXL↔SDXL): `KSampler (Advanced)` 두 개. 첫 번째 `end_at_step`=N +
  `return_with_leftover_noise` enable, 두 번째 `start_at_step`=N + `add_noise` disable.
  노이즈와 궤적은 하나이고 담당 모델만 바뀐다.
- 다른 아키텍처(SDXL↔Flux): latent 채널 수가 달라 직접 못 넘긴다. VAE decode → encode를
  거쳐 denoise 0.3~0.4로 재진입. 두 번째 모델이 상당히 다시 그리므로 얼굴이 바뀔 수 있고,
  ControlNet으로 구조를 붙잡아야 한다.

---

## 판단 기록

**Illustrious XL 베이스 보류 (2026-08).**
WAI가 프롬프트를 자주 덮어써서, 편향이 덜한 공식 베이스로 통제된 비교를 하려 했다.
체감 차이가 기대만큼 크지 않았고 셋업이 5분 → 15분으로 늘어 보류.
원인 추정: 데이터 분포가 같아서(둘 다 booru 기반) 노인·아이·건물 약점이 그대로 상속됨.
다시 볼 일이 생기면 프롬프트를 베이스에 맞춰 다시 짜고 비교할 것 —
Illustrious 베이스는 화풍이 밋밋해서 WAI 기준 설정을 그대로 쓰면 저평가되기 쉽다.

**실사 전환의 근거.**
위 실험과 달리 데이터 분포 자체가 바뀐다. 실사 모델은 실제 인물 사진과 건축물로 학습돼
남자 어른·노인·아이·풍경·건물의 공백에 직접 대응한다.
대가로 애니 표현력, Illustrious LoRA, WD14 태거를 전부 잃는다.
판단 기준: 노인 한 명, 아이 한 명, 건물 하나를 양쪽으로 뽑아 비교.

**목표.** 미소녀 일러스트가 아니라 세계관 구현.
필요한 것은 (1) 주제 다양성 (2) 프롬프트 충실도 (3) 스타일 일관성.
(3)은 체크포인트보다 스타일 LoRA 고정 + ControlNet + 프롬프트 템플릿 표준화로 잡힌다.

---

## 참고

- Notion: ComfyUI 셋업 스크립트 구조 (프로필 분리)
- 아키텍처 전환 후보 (SDXL 이후): Z-Image (6B, Apache 2.0, 가벼움),
  Chroma1-HD (Flux schnell 재훈련, 무검열, 다중 스타일), FLUX.1 dev (프롬프트 충실도),
  Qwen-Image (이미지 내 텍스트 렌더링). 모두 자연어 프롬프트라 서술적 세계관 작업에 유리.
