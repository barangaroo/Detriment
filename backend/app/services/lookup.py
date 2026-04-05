from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.tables import Manufacturer, DeviceProfile, Vulnerability, PortInfo, ScanReport
from app.models.schemas import (
    DeviceLookupRequest, DeviceLookupResponse,
    PortDetail, VulnerabilityInfo
)


async def lookup_device(db: AsyncSession, req: DeviceLookupRequest) -> DeviceLookupResponse:
    prefix = normalize_prefix(req.mac_prefix)

    # 1. Manufacturer lookup
    manufacturer = await get_manufacturer(db, prefix)

    # 2. Device profile lookup (MAC prefix + port fingerprint)
    port_sig = ",".join(str(p) for p in sorted(req.open_ports))
    profile = await get_device_profile(db, prefix, port_sig)

    # 3. Port details
    ports = await get_port_details(db, req.open_ports)

    # 4. Vulnerabilities for this manufacturer
    vulns = []
    if manufacturer:
        vulns = await get_vulnerabilities(db, manufacturer)

    # 5. Calculate risk score
    risk_score = calculate_risk(ports, profile, manufacturer, vulns)

    # 6. Generate tips
    tips = generate_tips(manufacturer, profile, ports, vulns)

    return DeviceLookupResponse(
        mac_prefix=prefix,
        manufacturer=manufacturer,
        device_type=profile.device_type if profile else None,
        device_model=profile.device_model if profile else None,
        device_description=profile.device_description if profile else None,
        risk_score=risk_score,
        ports=ports,
        vulnerabilities=[
            VulnerabilityInfo(
                title=v.title,
                severity=v.severity,
                description=v.description,
                fix=v.fix,
            ) for v in vulns
        ],
        tips=tips,
    )


def normalize_prefix(mac: str) -> str:
    """Normalize MAC prefix to XX:XX:XX format."""
    clean = mac.upper().replace("-", ":").replace(".", ":")
    parts = clean.split(":")
    if len(parts) >= 3:
        return ":".join(parts[:3])
    return clean[:8]


async def get_manufacturer(db: AsyncSession, prefix: str) -> str | None:
    result = await db.execute(
        select(Manufacturer.name).where(Manufacturer.mac_prefix == prefix)
    )
    row = result.scalar_one_or_none()
    return row


async def get_device_profile(db: AsyncSession, prefix: str, port_sig: str) -> DeviceProfile | None:
    # Try exact match first
    result = await db.execute(
        select(DeviceProfile)
        .where(DeviceProfile.mac_prefix == prefix, DeviceProfile.port_signature == port_sig)
        .order_by(DeviceProfile.confidence.desc())
        .limit(1)
    )
    profile = result.scalar_one_or_none()
    if profile:
        return profile

    # Fall back to MAC prefix only
    result = await db.execute(
        select(DeviceProfile)
        .where(DeviceProfile.mac_prefix == prefix)
        .order_by(DeviceProfile.confidence.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def get_port_details(db: AsyncSession, ports: list[int]) -> list[PortDetail]:
    if not ports:
        return []
    result = await db.execute(
        select(PortInfo).where(PortInfo.port.in_(ports))
    )
    rows = result.scalars().all()

    details = []
    known_ports = {r.port: r for r in rows}

    for port in sorted(ports):
        if port in known_ports:
            r = known_ports[port]
            details.append(PortDetail(
                port=port,
                service_name=r.service_name,
                risk_level=r.risk_level,
                description=r.description,
                what_to_do=r.what_to_do,
            ))
        else:
            details.append(PortDetail(
                port=port,
                service_name=f"Service on port {port}",
                risk_level="caution",
                description=f"Something is running on port {port}. We're not sure what it is.",
                what_to_do="If you don't recognize this, it might be worth investigating.",
            ))

    return details


async def get_vulnerabilities(db: AsyncSession, manufacturer: str) -> list[Vulnerability]:
    # Try exact match first
    result = await db.execute(
        select(Vulnerability)
        .where(
            func.lower(Vulnerability.manufacturer) == manufacturer.lower(),
            Vulnerability.is_active == True,
        )
        .order_by(Vulnerability.severity.desc())
        .limit(5)
    )
    vulns = list(result.scalars().all())
    if vulns:
        return vulns

    # Fuzzy match — but only match the core brand name, not generic parents
    # e.g. "Hikvision" should match "Hangzhou Hikvision Digital Technology"
    # but "Amazon" (Echo) should NOT match "Amazon Ring" (different product line)
    result = await db.execute(
        select(Vulnerability)
        .where(Vulnerability.is_active == True)
    )
    all_vulns = list(result.scalars().all())
    matched = []
    mfr_lower = manufacturer.lower()
    for v in all_vulns:
        v_name = v.manufacturer.lower()
        # Skip if vuln is for a specific sub-brand that doesn't match
        # e.g. "Amazon Ring" vuln shouldn't match generic "Amazon" device
        if " " in v_name and v_name not in mfr_lower and mfr_lower not in v_name:
            continue
        # Only match if the vuln brand is a substring of the device manufacturer
        # but not the other way (avoids "Amazon" matching "Amazon Ring")
        if v_name in mfr_lower:
            matched.append(v)
        elif mfr_lower in v_name and " " not in v_name:
            # Only match reverse if vuln manufacturer is a single word
            matched.append(v)

    return sorted(matched, key=lambda v: v.severity or "", reverse=True)[:5]


def calculate_risk(
    ports: list[PortDetail],
    profile: DeviceProfile | None,
    manufacturer: str | None,
    vulns: list[Vulnerability],
) -> int:
    score = 0

    # Port risk
    risk_weights = {"danger": 25, "warning": 15, "caution": 8, "ok": 2, "good": 0}
    for p in ports:
        score += risk_weights.get(p.risk_level, 5)

    # Unknown manufacturer
    if not manufacturer:
        score += 15

    # Unknown device type
    if not profile:
        score += 10

    # Vulnerabilities
    sev_weights = {"critical": 20, "high": 15, "medium": 8, "low": 3}
    for v in vulns:
        score += sev_weights.get(v.severity, 5)

    return min(100, score)


def generate_tips(
    manufacturer: str | None,
    profile: DeviceProfile | None,
    ports: list[PortDetail],
    vulns: list[Vulnerability],
) -> list[str]:
    tips = []

    if not manufacturer:
        tips.append("We couldn't identify who made this device. If you don't recognize it, it might not belong on your WiFi.")

    if profile and profile.device_description:
        tips.append(profile.device_description)

    danger_ports = [p for p in ports if p.risk_level in ("danger", "warning")]
    if danger_ports:
        names = ", ".join(p.service_name for p in danger_ports)
        tips.append(f"This device has risky services running: {names}. Check if you actually need them.")

    if vulns:
        tips.append(f"This device's maker ({manufacturer}) has {len(vulns)} known security issue(s). Keep the firmware updated.")

    # Don't return a generic "looks fine" — the app handles that itself
    return tips


async def save_scan_report(db: AsyncSession, devices: list[DeviceLookupRequest], region: str | None):
    """Save anonymized scan data for crowdsourced intelligence."""
    for device in devices:
        prefix = normalize_prefix(device.mac_prefix)
        port_sig = ",".join(str(p) for p in sorted(device.open_ports))
        report = ScanReport(
            mac_prefix=prefix,
            port_signature=port_sig,
            region=region,
        )
        db.add(report)
    await db.commit()
