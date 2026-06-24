from datetime import date as Date
from datetime import datetime as DateTime
from typing import Optional

from pydantic import BaseModel, Field


class HeartRateSample(BaseModel):
    bpm: float = Field(..., gt=0, description="Latest heart-rate value in beats per minute.")
    measuredAt: DateTime = Field(..., description="When HealthKit measured the heart-rate sample.")


class HealthKitSyncRequest(BaseModel):
    source: str = Field("ios-healthkit-demo", min_length=1)
    syncedAt: DateTime = Field(..., description="When the iOS app sent this sync payload.")
    date: Date = Field(..., description="Local calendar date represented by the daily aggregates.")
    steps: Optional[int] = Field(None, ge=0)
    activeEnergyKcal: Optional[float] = Field(None, ge=0)
    latestHeartRate: Optional[HeartRateSample] = None


class HealthKitSyncResponse(BaseModel):
    ok: bool
    message: str
    savedPath: str
