from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    PROJECT_NAME: str = "ItDa Backend"
    API_V1_STR: str = "/api/v1"
    DATABASE_URL: str = "sqlite:///./test.db"

    # OpenAI
    OPENAI_API_KEY: str
    OPENAI_MODEL: str = "gpt-4o-mini"
    OPENAI_TEMPERATURE: float = 0.3
    OPENAI_MAX_TOKENS: int = 500

    # CORS
    BACKEND_CORS_ORIGINS: list = ["*"]

    # Google Places
    GOOGLE_PLACES_API_KEY: str = ""

    # Naver
    NAVER_CLIENT_ID: str = ""
    NAVER_CLIENT_SECRET: str = ""


    class Config:
        env_file = "C:/Users/w0106/SWP/ItDa/backend/.env"

@lru_cache()
def get_settings():
    return Settings()

settings = get_settings()