"""Download and ingest the IEEE OUI database (30K+ manufacturers)."""
import asyncio
import csv
import io
import httpx
from app.database import engine, async_session, Base
from app.models.tables import Manufacturer
from app.config import OUI_UPDATE_URL


MIRRORS = [
    OUI_UPDATE_URL,
    "https://raw.githubusercontent.com/wireshark/wireshark/master/manuf",
    "https://linuxnet.ca/ieee/oui.txt",
]


async def download_oui() -> str:
    """Try IEEE first, fall back to mirrors, fall back to Wireshark manuf format."""
    headers = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"}

    async with httpx.AsyncClient(timeout=60, headers=headers, follow_redirects=True) as client:
        # Try CSV first
        try:
            print(f"Trying {OUI_UPDATE_URL}...")
            resp = await client.get(OUI_UPDATE_URL)
            resp.raise_for_status()
            print(f"Downloaded {len(resp.text)} bytes")
            return resp.text
        except Exception as e:
            print(f"IEEE direct failed: {e}")

        # Try Wireshark manuf (always available)
        wireshark_url = "https://gitlab.com/wireshark/wireshark/-/raw/master/manuf"
        try:
            print(f"Trying Wireshark manuf...")
            resp = await client.get(wireshark_url)
            resp.raise_for_status()
            print(f"Downloaded {len(resp.text)} bytes from Wireshark")
            return "WIRESHARK:" + resp.text  # Prefix to signal different format
        except Exception as e:
            print(f"Wireshark failed: {e}")

    raise RuntimeError("Could not download OUI database from any source")


def parse_oui(content: str) -> list[dict]:
    """Parse OUI data from either IEEE CSV or Wireshark manuf format."""
    if content.startswith("WIRESHARK:"):
        return parse_wireshark_manuf(content[len("WIRESHARK:"):])
    return parse_ieee_csv(content)


def parse_wireshark_manuf(content: str) -> list[dict]:
    """Parse Wireshark manuf format: XX:XX:XX<tab>ShortName<tab>FullName"""
    entries = []
    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        parts = line.split("\t")
        if len(parts) < 2:
            continue

        mac_raw = parts[0].strip()
        # Only take 24-bit OUI entries (XX:XX:XX), skip longer ones
        if len(mac_raw) != 8 or mac_raw.count(":") != 2:
            continue

        short_name = parts[1].strip() if len(parts) > 1 else ""
        full_name = parts[2].strip() if len(parts) > 2 else short_name

        if not short_name:
            continue

        name = simplify_name(full_name) if full_name else short_name

        entries.append({
            "mac_prefix": mac_raw.upper(),
            "name": name,
            "full_name": full_name or short_name,
        })

    return entries


def parse_ieee_csv(content: str) -> list[dict]:
    """Parse IEEE OUI CSV format."""
    entries = []
    reader = csv.reader(io.StringIO(content))

    header = next(reader, None)
    if not header:
        return entries

    for row in reader:
        if len(row) < 3:
            continue

        assignment = row[1].strip()
        org_name = row[2].strip()

        if not assignment or not org_name:
            continue

        if len(assignment) == 6:
            mac_prefix = f"{assignment[0:2]}:{assignment[2:4]}:{assignment[4:6]}"
        else:
            continue

        name = simplify_name(org_name)

        entries.append({
            "mac_prefix": mac_prefix.upper(),
            "name": name,
            "full_name": org_name,
        })

    return entries


def simplify_name(full_name: str) -> str:
    """Simplify corporate names to consumer-friendly versions."""
    mappings = {
        "apple, inc.": "Apple",
        "samsung electronics co.,ltd": "Samsung",
        "google, inc.": "Google",
        "google llc": "Google",
        "amazon technologies inc.": "Amazon",
        "amazon.com, llc": "Amazon",
        "microsoft corporation": "Microsoft",
        "sony interactive entertainment inc.": "Sony PlayStation",
        "sony group corporation": "Sony",
        "nintendo co.,ltd": "Nintendo",
        "tp-link technologies co.,ltd.": "TP-Link",
        "netgear": "Netgear",
        "asus computer inc.": "ASUS",
        "asustek computer inc.": "ASUS",
        "ubiquiti inc": "Ubiquiti",
        "ubiquiti networks inc.": "Ubiquiti",
        "sonos, inc.": "Sonos",
        "roku, inc.": "Roku",
        "lg electronics (mobile communications)": "LG",
        "lg electronics": "LG",
        "intel corporate": "Intel",
        "espressif inc.": "Espressif (IoT)",
        "tuya smart inc.": "Tuya (IoT)",
        "shenzhen bilian electronic co.,ltd": "Smart Device",
        "hp inc.": "HP",
        "hewlett packard": "HP",
        "canon inc.": "Canon",
        "epson": "Epson",
        "seiko epson corporation": "Epson",
        "brother industries, ltd.": "Brother",
        "ring llc": "Amazon Ring",
        "wyze labs inc": "Wyze",
        "signify b.v.": "Philips Hue",
        "raspberry pi (trading) ltd": "Raspberry Pi",
        "raspberry pi ltd": "Raspberry Pi",
        "cisco systems, inc": "Cisco",
        "arris group, inc.": "Arris",
        "huawei technologies co.,ltd": "Huawei",
        "xiaomi communications co ltd": "Xiaomi",
        "realtek semiconductor corp.": "Realtek",
        "qualcomm inc.": "Qualcomm",
        "dell inc.": "Dell",
        "lenovo": "Lenovo",
    }

    lower = full_name.lower().strip()
    if lower in mappings:
        return mappings[lower]

    # General cleanup
    name = full_name
    for suffix in [", Inc.", ", LLC", " Co.,Ltd", " Corporation", " Corp.", " Ltd.", " Inc", " GmbH", " S.A."]:
        name = name.replace(suffix, "")
    return name.strip()


async def ingest():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    content = await download_oui()
    entries = parse_oui(content)
    print(f"Parsed {len(entries)} OUI entries")

    async with async_session() as db:
        count = 0
        for entry in entries:
            existing = await db.get(Manufacturer, entry["mac_prefix"])
            if existing:
                existing.name = entry["name"]
                existing.full_name = entry["full_name"]
            else:
                db.add(Manufacturer(
                    mac_prefix=entry["mac_prefix"],
                    name=entry["name"],
                    full_name=entry["full_name"],
                ))
            count += 1

            # Commit in batches
            if count % 1000 == 0:
                await db.commit()
                print(f"  Ingested {count}/{len(entries)}...")

        await db.commit()
        print(f"Done. Ingested {count} manufacturers.")


if __name__ == "__main__":
    asyncio.run(ingest())
