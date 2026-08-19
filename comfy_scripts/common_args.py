"""공용 CLI 인자 정의.

모든 step 스크립트가 이 파서를 기반으로 시작한다.
공통 옵션을 여기서만 관리하면 스크립트가 늘어나도 한 곳만 고치면 된다.

    from common_args import base_parser

    ap = base_parser("시드 배치 생성", count=True)
    ap.add_argument("--prefix", default="gen")   # 스크립트 전용 옵션
    args = ap.parse_args()
"""
import argparse
from pathlib import Path

HERE = Path(__file__).parent


def base_parser(description: str = "", *, count: bool = False,
                count_default: int = 1, csv: bool = False
                ) -> argparse.ArgumentParser:
    """공통 옵션이 등록된 파서를 돌려준다.

    count / csv 는 필요한 스크립트에서만 True 로 켠다.
    """
    ap = argparse.ArgumentParser(description=description)

    ap.add_argument("--workflow", "--wf", "--w", "-w", dest="workflow",
                    default="wf_api.json",
                    help="API 포맷 워크플로 JSON (기본: wf_api.json)")
    ap.add_argument("--out", "-o", dest="out", default="results",
                    help="출력 디렉터리 (기본: results)")
    ap.add_argument("--server", default="http://127.0.0.1:8188",
                    help="ComfyUI 주소 (기본: http://127.0.0.1:8188)")
    ap.add_argument("--timeout", type=int, default=900,
                    help="작업 하나당 최대 대기 초 (기본: 900)")
    ap.add_argument("--quiet", "-q", action="store_true",
                    help="진행바를 숨긴다")
    ap.add_argument("--dry-run", action="store_true",
                    help="큐잉하지 않고 계획만 출력")

    if count:
        ap.add_argument("--count", "-c", type=int, default=count_default,
                        help=f"생성 개수 (기본: {count_default})")
    if csv:
        ap.add_argument("--csv", dest="csv", default="batch_list.csv",
                        help="배치 목록 CSV (기본: batch_list.csv)")

    return ap


def resolve(path_str: str) -> Path:
    """상대 경로는 스크립트 디렉터리 기준으로 푼다."""
    p = Path(path_str)
    return p if p.is_absolute() else HERE / p
