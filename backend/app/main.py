from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select, func
from app.database import init_db, async_session
from app.models.tables import Manufacturer, DeviceProfile, Vulnerability
from app.routers import lookup, ports


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield


app = FastAPI(
    title="Detriment API",
    description="Device intelligence for WiFi security scanning",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(lookup.router)
app.include_router(ports.router)


@app.get("/")
async def root():
    return {"app": "Detriment API", "version": "1.0.0"}


@app.get("/health")
async def health():
    async with async_session() as db:
        mfr_count = (await db.execute(select(func.count()).select_from(Manufacturer))).scalar()
        profile_count = (await db.execute(select(func.count()).select_from(DeviceProfile))).scalar()
        vuln_count = (await db.execute(select(func.count()).select_from(Vulnerability))).scalar()

    return {
        "status": "ok",
        "manufacturers_count": mfr_count,
        "device_profiles_count": profile_count,
        "vulnerabilities_count": vuln_count,
    }
