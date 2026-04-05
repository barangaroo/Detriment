"""Seed the port_info table with consumer-friendly port descriptions."""
import asyncio
from app.database import engine, async_session, Base
from app.models.tables import PortInfo


PORTS = [
    (20, "File Transfer", "FTP Data", "caution", "Used for sending files between devices.", "If you're not sharing files, this should be off."),
    (21, "File Transfer Login", "FTP", "warning", "An old way to share files. Passwords are sent without encryption.", "Use a more secure method to share files, or turn this off."),
    (22, "Remote Access", "SSH", "caution", "Lets someone control this device remotely via command line.", "Make sure it has a strong password. If you didn't set this up, turn it off."),
    (23, "Insecure Login", "Telnet", "danger", "A very old, completely insecure way to log in. Passwords are visible to anyone watching.", "Turn this off immediately. Use Remote Access (SSH) instead."),
    (25, "Email Sending", "SMTP", "caution", "Used to send emails.", "Unusual on home devices. Could mean spam is being sent."),
    (53, "Name Lookup", "DNS", "ok", "Translates website names to addresses. Normal for routers.", None),
    (80, "Web Page", "HTTP", "ok", "A basic web page. Many devices have a settings page here.", "Normal for routers and smart devices. Just make sure it needs a password."),
    (443, "Secure Web", "HTTPS", "good", "An encrypted web page. This is the secure version.", None),
    (445, "File Sharing", "SMB", "warning", "Windows file sharing. Often targeted by hackers.", "If you're not sharing files on purpose, turn this off."),
    (548, "Apple File Sharing", "AFP", "caution", "Apple's file sharing. Used by Macs to share folders.", "Fine if you set it up. If not, check why it's on."),
    (554, "Video Stream", "RTSP", "warning", "Streams video from cameras. Anyone on your WiFi could potentially watch.", "Make sure your camera has a password set. Update its firmware."),
    (631, "Printer", "IPP", "ok", "Internet printing. Normal for printers and computers.", None),
    (3389, "Remote Control", "RDP", "warning", "Lets someone see and control this device's screen remotely.", "If you didn't set this up, turn it off immediately. It's a common hacking target."),
    (5000, "Device Discovery", "UPnP", "caution", "Helps devices find each other automatically.", "Generally ok, but can be exploited. Disable on your router if not needed."),
    (5353, "Auto-Discovery", "mDNS", "ok", "Apple and others use this to find nearby devices.", None),
    (8080, "Web Service", "HTTP Alt", "caution", "An alternate web page. Sometimes used for device admin panels.", "Check what's running here. Make sure it needs a password."),
    (8443, "Secure Web Alt", "HTTPS Alt", "ok", "An alternate secure web page.", None),
    (8888, "Web Service", "HTTP Alt 2", "caution", "Another alternate web service.", "Check what's running here."),
    (9100, "Printer", "Raw Print", "ok", "Direct printing port. Normal for printers.", None),
    (62078, "iPhone Sync", "iphone-sync", "ok", "Used by iPhones to sync with computers.", None),
    (1883, "Smart Home Hub", "MQTT", "warning", "Used by smart home devices to talk to each other.", "If exposed to the internet, anyone could control your smart home."),
    (3000, "Web App", "Dev Server", "caution", "A web application is running here.", "Might be a development server left running."),
    (5900, "Screen Sharing", "VNC", "warning", "Lets someone see your screen remotely.", "Make sure this has a password. If you don't need it, turn it off."),
    (8000, "Web App", "HTTP Alt", "caution", "A web application running on an alternate port.", None),
    (8008, "Media Streaming", "HTTP Alt", "ok", "Often used by Chromecast and similar devices.", None),
    (8009, "Chromecast", "Cast", "ok", "Used by Google Chromecast.", None),
    (8060, "Roku", "Roku API", "ok", "Used by Roku devices for remote control.", None),
    (10000, "Admin Panel", "Webmin", "warning", "A server administration panel.", "If this is on a home device, something unusual is going on."),
    (32400, "Plex Media", "Plex", "ok", "Plex media server for streaming your movies and shows.", None),
    (49152, "Random Service", "Dynamic", "caution", "A dynamically assigned port. Could be anything.", "Might be a game, app, or something else using a temporary connection."),
]


async def seed():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with async_session() as db:
        for port, service, technical, risk, desc, what_to_do in PORTS:
            existing = await db.get(PortInfo, port)
            if existing:
                existing.service_name = service
                existing.technical_name = technical
                existing.risk_level = risk
                existing.description = desc
                existing.what_to_do = what_to_do
            else:
                db.add(PortInfo(
                    port=port,
                    service_name=service,
                    technical_name=technical,
                    risk_level=risk,
                    description=desc,
                    what_to_do=what_to_do,
                ))
        await db.commit()
        print(f"Seeded {len(PORTS)} ports")


if __name__ == "__main__":
    asyncio.run(seed())
