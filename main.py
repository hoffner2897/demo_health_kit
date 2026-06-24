import json
from datetime import datetime, timezone
from typing import Any, Dict

from fastapi import FastAPI

from schemas import HealthKitSyncRequest, HealthKitSyncResponse
from storage import append_healthkit_payload


app = FastAPI(
    title="HealthKit Sync Demo API",
    version="0.1.0",
    description="Minimal local backend for receiving HealthKit data from an iOS demo app.",
)


def model_to_json_dict(model: Any) -> Dict[str, Any]:
    """Return a JSON-serializable dict for both Pydantic v1 and v2."""
    if hasattr(model, "model_dump"):
        return model.model_dump(mode="json")
    return model.dict()


@app.get("/health")
def health() -> Dict[str, Any]:
    return {
        "ok": True,
        "service": "healthkit-sync-demo",
        "time": datetime.now(timezone.utc).isoformat(),
    }


@app.post("/healthkit/sync", response_model=HealthKitSyncResponse)
def sync_healthkit(payload: HealthKitSyncRequest) -> HealthKitSyncResponse:
    data = model_to_json_dict(payload)

    print("Received HealthKit sync payload:")
    print(json.dumps(data, indent=2, ensure_ascii=False))

    saved_path = append_healthkit_payload(data)
    return HealthKitSyncResponse(
        ok=True,
        message="received",
        savedPath=str(saved_path),
    )
