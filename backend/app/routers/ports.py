from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.models.tables import PortInfo
from app.models.schemas import PortDetail

router = APIRouter(prefix="/api/ports", tags=["ports"])


@router.get("/{port}", response_model=PortDetail | None)
async def get_port_info(port: int, db: AsyncSession = Depends(get_db)):
    """Get info about a specific port."""
    result = await db.execute(select(PortInfo).where(PortInfo.port == port))
    row = result.scalar_one_or_none()
    if not row:
        return PortDetail(
            port=port,
            service_name=f"Unknown service on port {port}",
            risk_level="caution",
            description="We're not sure what's running here.",
            what_to_do="If you didn't set this up, it's worth checking.",
        )
    return PortDetail(
        port=row.port,
        service_name=row.service_name,
        risk_level=row.risk_level,
        description=row.description,
        what_to_do=row.what_to_do,
    )
