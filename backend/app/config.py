import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite+aiosqlite:///./detriment.db")
OUI_UPDATE_URL = "https://standards-oui.ieee.org/oui/oui.csv"
CVE_API_URL = "https://services.nvd.nist.gov/rest/json/cves/2.0"
