from sqlalchemy import Column, String, Integer, Text, DateTime, Boolean, Float, Index
from sqlalchemy.sql import func
from app.database import Base


class Manufacturer(Base):
    __tablename__ = "manufacturers"

    mac_prefix = Column(String(8), primary_key=True)  # "AC:DE:48"
    name = Column(String(255), nullable=False, index=True)
    full_name = Column(String(500))
    country = Column(String(100))
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class DeviceProfile(Base):
    __tablename__ = "device_profiles"

    id = Column(Integer, primary_key=True, autoincrement=True)
    mac_prefix = Column(String(8), nullable=False, index=True)
    port_signature = Column(String(255))  # "80,443,554" — sorted open ports
    device_type = Column(String(50))  # "camera", "router", "phone"
    device_model = Column(String(255))  # "Ring Doorbell Pro 2"
    device_description = Column(Text)  # Plain English
    icon = Column(String(50))  # SF Symbol name
    confidence = Column(Float, default=0.5)
    report_count = Column(Integer, default=1)  # Crowdsourced confidence
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index("ix_device_fingerprint", "mac_prefix", "port_signature"),
    )


class Vulnerability(Base):
    __tablename__ = "vulnerabilities"

    id = Column(Integer, primary_key=True, autoincrement=True)
    manufacturer = Column(String(255), nullable=False, index=True)
    device_type = Column(String(50))
    cve_id = Column(String(20))
    severity = Column(String(20))  # "low", "medium", "high", "critical"
    title = Column(String(500), nullable=False)
    description = Column(Text, nullable=False)  # Plain English
    fix = Column(Text)  # What the user should do
    published_date = Column(DateTime)
    is_active = Column(Boolean, default=True)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class PortInfo(Base):
    __tablename__ = "port_info"

    port = Column(Integer, primary_key=True)
    service_name = Column(String(100), nullable=False)  # "Video Stream" not "RTSP"
    technical_name = Column(String(100))  # "RTSP" for nerds
    risk_level = Column(String(20), nullable=False)  # "good", "ok", "caution", "warning", "danger"
    description = Column(Text, nullable=False)  # "This lets devices stream video"
    what_to_do = Column(Text)  # "If you don't have a camera, something's wrong"
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class ScanReport(Base):
    """Anonymized, aggregated scan data from users."""
    __tablename__ = "scan_reports"

    id = Column(Integer, primary_key=True, autoincrement=True)
    mac_prefix = Column(String(8), nullable=False, index=True)
    port_signature = Column(String(255))
    device_type_guess = Column(String(50))
    region = Column(String(10))  # Country code only, no precise location
    reported_at = Column(DateTime, server_default=func.now())
