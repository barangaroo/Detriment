import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

# On Vercel, the DB is bundled read-only at the project root
_db_path = Path(__file__).resolve().parent.parent / "detriment.db"
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite+aiosqlite:///{_db_path}")
OUI_UPDATE_URL = "https://standards-oui.ieee.org/oui/oui.csv"
CVE_API_URL = "https://services.nvd.nist.gov/rest/json/cves/2.0"
