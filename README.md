# lomebrote

RunPod ComfyUI 환경 세팅. 파드는 작업 후 매번 terminate하고 네트워크 볼륨이 없으므로,
유지되어야 하는 것은 전부 이 저장소 안에 있어야 한다.

---

## 빠른 시작

```bash
cd /workspace && git clone https://github.com/odineyes2/lomebrote.git
```

```bash
cd /workspace/lomebrote && time bash setup.sh real nsfw
```

```bash
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

---

## 공통 구성

### 커스텀 노드

| 노드 | 용도 |
|---|---|
| ComfyUI_UltimateSDUpscale | USDU 타일 업스케일 (서브모듈 필요) |
| ComfyUI-Inpaint-CropAndStitch | 인페인팅 영역 확대 후 재합성 |
| ComfyUI-WD14-Tagger | booru 태그 추출 (애니 계열에서만 유용) |
| comfyui_controlnet_aux | DWPose, DepthAnythingV2 등 전처리기 |
| efficiency-nodes-comfyui | XY Plot, KSampler (Efficient), Efficient Loader |

### 전처리기 가중치 (프로필 무관, 약 1.9GB)

| 파일 | 크기 | 용도 |
|---|---|---|
| `yolox_l.torchscript.pt` | ~200MB | DWPose 인물 검출 (GPU) |
| `dw-ll_ucoco_384_bs5.torchscript.pt` | ~200MB | DWPose 골격 추정 (GPU) |
| `yolox_l.onnx` | ~200MB | DWPose 폴백 (CPU) |
| `depth_anything_v2_vitl.pth` | 1.3GB | 깊이맵 추출 |

## 운영 메모

### 디스크

모델은 전부 `/workspace` 아래 → **볼륨 디스크**가 늘어나야 한다.
컨테이너 디스크로 새는 것은 pip 캐시와 (`DEPTH_AB` 계열 작업 시) MiDaS 캐시 정도.

- 볼륨 60GB / 컨테이너 20~30GB 권장.
- venv 탐색이 실패해 시스템 python으로 떨어지면 pip 설치분이 전부 컨테이너로 간다.
  확인: `"$PY" -c "import sys; print(sys.prefix)"` → `/workspace`로 시작하면 정상.
