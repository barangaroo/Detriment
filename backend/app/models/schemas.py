from pydantic import BaseModel


class DeviceLookupRequest(BaseModel):
    mac_prefix: str  # First 8 chars: "AC:DE:48"
    open_ports: list[int] = []


class BatchLookupRequest(BaseModel):
    devices: list[DeviceLookupRequest]


class VulnerabilityInfo(BaseModel):
    title: str
    severity: str
    description: str
    fix: str | None = None


class PortDetail(BaseModel):
    port: int
    service_name: str
    risk_level: str
    description: str
    what_to_do: str | None = None


class DeviceLookupResponse(BaseModel):
    mac_prefix: str
    manufacturer: str | None = None
    device_type: str | None = None
    device_model: str | None = None
    device_description: str | None = None
    risk_score: int = 0  # 0-100
    ports: list[PortDetail] = []
    vulnerabilities: list[VulnerabilityInfo] = []
    tips: list[str] = []


class BatchLookupResponse(BaseModel):
    devices: list[DeviceLookupResponse]


class ScanReportRequest(BaseModel):
    devices: list[DeviceLookupRequest]
    region: str | None = None


class HealthResponse(BaseModel):
    status: str
    manufacturers_count: int
    device_profiles_count: int
    vulnerabilities_count: int
