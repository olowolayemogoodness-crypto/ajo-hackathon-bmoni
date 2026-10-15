from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="AJO_", extra="ignore")

    environment: Literal["local", "test", "staging", "production"] = "local"
    database_url: str = "postgresql+psycopg://localhost:5432/ajo"
    firebase_project_id: str = "ajo-hackathon"


@lru_cache
def get_settings() -> Settings:
    return Settings()
