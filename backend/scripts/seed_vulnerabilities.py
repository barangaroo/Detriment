"""Seed common consumer device vulnerabilities in plain English."""
import asyncio
from app.database import engine, async_session, Base
from app.models.tables import Vulnerability


VULNS = [
    # Hikvision
    ("Hikvision", "camera", "CVE-2021-36260", "critical",
     "Hikvision cameras can be taken over remotely",
     "A flaw lets hackers take full control of the camera without a password. This was widely exploited.",
     "Update your camera's firmware immediately from Hikvision's website."),

    ("Hikvision", "camera", "CVE-2023-28808", "high",
     "Hikvision camera access control bypass",
     "Attackers can bypass login on some Hikvision models and access video feeds.",
     "Update firmware. Change the default password if you haven't already."),

    # TP-Link
    ("TP-Link", "router", "CVE-2023-1389", "critical",
     "TP-Link routers can be hijacked",
     "Some TP-Link routers have a flaw that lets attackers take over your router completely.",
     "Update your router firmware. Check TP-Link's support page for your model."),

    # Netgear
    ("Netgear", "router", "CVE-2021-45388", "high",
     "Netgear routers vulnerable to remote attack",
     "Several Netgear routers can be attacked from inside your network without a password.",
     "Update your router firmware from the Netgear app or admin page."),

    # Ring
    ("Amazon Ring", "camera", None, "medium",
     "Ring cameras have had privacy concerns",
     "Ring cameras have had issues with employees accessing footage and sharing data with third parties.",
     "Enable end-to-end encryption in the Ring app. Review your sharing settings."),

    # Wyze
    ("Wyze", "camera", "CVE-2023-6321", "high",
     "Wyze cameras had a viewing glitch",
     "A bug let some Wyze users accidentally see other people's camera feeds.",
     "Make sure your Wyze app and camera firmware are fully updated."),

    # Smart home / IoT
    ("Espressif (IoT)", None, None, "medium",
     "Cheap smart home chips often lack security updates",
     "Devices using Espressif chips (common in budget smart home gadgets) rarely get security patches after purchase.",
     "Keep these devices on a separate WiFi network if possible. Consider replacing very old ones."),

    ("Tuya (IoT)", None, None, "medium",
     "Tuya smart devices send data to overseas servers",
     "Many Tuya-based devices send usage data to servers in China, even when you're not using them.",
     "If privacy is a concern, consider replacing with a brand that keeps data local."),

    # Roku
    ("Roku", "tv", None, "low",
     "Roku devices track viewing habits",
     "Roku collects data about what you watch and sells it to advertisers.",
     "Go to Settings > Privacy > Advertising and enable 'Limit Ad Tracking'."),

    # Samsung
    ("Samsung", None, None, "low",
     "Samsung smart devices collect usage data",
     "Samsung TVs and phones send usage statistics back to Samsung by default.",
     "Check privacy settings on your Samsung devices. You can opt out of most data collection."),

    # HP Printers
    ("HP", "printer", None, "medium",
     "HP printers can be accessed remotely if misconfigured",
     "HP printers with open web interfaces can be accessed by anyone on your network.",
     "Set an admin password on your printer. Access its settings page at its IP address."),

    # Philips Hue
    ("Philips Hue", None, "CVE-2020-6007", "medium",
     "Philips Hue bridge had a security flaw",
     "Attackers on your network could use your Hue bridge to access other devices.",
     "Update your Hue bridge firmware through the Hue app."),

    # Sonos
    ("Sonos", "speaker", None, "low",
     "Sonos speakers expose a control interface",
     "Sonos speakers have an open API that anyone on your WiFi can use to control playback.",
     "This is normal behavior. Just be aware anyone on your WiFi can change your music."),

    # Ubiquiti
    ("Ubiquiti", "router", "CVE-2021-22205", "high",
     "Ubiquiti had a major data breach",
     "Ubiquiti's cloud systems were breached, potentially exposing device configurations.",
     "Enable 2-factor authentication on your Ubiquiti account. Update all firmware."),
]


async def seed():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with async_session() as db:
        for mfr, dev_type, cve, severity, title, desc, fix in VULNS:
            db.add(Vulnerability(
                manufacturer=mfr,
                device_type=dev_type,
                cve_id=cve,
                severity=severity,
                title=title,
                description=desc,
                fix=fix,
                is_active=True,
            ))
        await db.commit()
        print(f"Seeded {len(VULNS)} vulnerabilities")


if __name__ == "__main__":
    asyncio.run(seed())
