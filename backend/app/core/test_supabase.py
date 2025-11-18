import os
import sys
from supabase import create_client, Client
from pathlib import Path
from dotenv import load_dotenv

backend_path = Path(__file__).parent.parent.parent
sys.path.insert(0, str(backend_path))

env_path = backend_path / ".env"
load_dotenv(env_path)

url: str = os.environ.get("SUPABASE_URL")
key: str = os.environ.get("SUPABASE_KEY")
supabase: Client = create_client(url, key)

response = (
    supabase.table("users")
    .select("*")
    .execute()
)
