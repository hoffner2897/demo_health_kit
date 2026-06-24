import json
from datetime import date, datetime
from pathlib import Path
from typing import Any, Mapping


DATA_DIR = Path(__file__).resolve().parent / "data"
HEALTHKIT_JSONL_PATH = DATA_DIR / "healthkit-sync.jsonl"


def json_default(value: Any) -> str:
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    raise TypeError(f"Object of type {type(value).__name__} is not JSON serializable")


def append_healthkit_payload(
    payload: Mapping[str, Any],
    path: Path = HEALTHKIT_JSONL_PATH,
) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)

    with path.open("a", encoding="utf-8") as file:
        file.write(json.dumps(payload, ensure_ascii=False, default=json_default))
        file.write("\n")

    return path
