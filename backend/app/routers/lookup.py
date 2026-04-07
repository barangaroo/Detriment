from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.models.schemas import (
    DeviceLookupRequest, DeviceLookupResponse,
    BatchLookupRequest, BatchLookupResponse,
    ScanReportRequest,
)
from app.services.lookup import lookup_device

router = APIRouter(prefix="/api", tags=["lookup"])


@router.post("/lookup", response_model=DeviceLookupResponse)
async def lookup_single(req: DeviceLookupRequest, db: AsyncSession = Depends(get_db)):
    """Look up a single device by MAC prefix and open ports."""
    return await lookup_device(db, req)


@router.post("/lookup/batch", response_model=BatchLookupResponse)
async def lookup_batch(req: BatchLookupRequest, db: AsyncSession = Depends(get_db)):
    """Look up multiple devices in one request."""
    results = []
    for device in req.devices:
        result = await lookup_device(db, device)
        results.append(result)
    return BatchLookupResponse(devices=results)


@router.post("/report")
async def submit_scan_report(req: ScanReportRequest):
    """Accept anonymized scan data (read-only deployment — acknowledged but not stored)."""
    return {"status": "ok", "devices_reported": len(req.devices)}
