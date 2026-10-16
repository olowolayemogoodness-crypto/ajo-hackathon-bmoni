from functools import lru_cache
from typing import Literal

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="AJO_", extra="ignore")

    environment: Literal["local", "test", "staging", "production"] = "local"
    database_url: str = "postgresql+psycopg://localhost:5432/ajo"
    firebase_project_id: str = "ajo-hackathon"
    demo_mode: bool = False
    synthetic_data: bool = False
    demo_operator_firebase_uids: str = ""

    @property
    def demo_operator_uids(self) -> frozenset[str]:
        return frozenset(
            uid.strip() for uid in self.demo_operator_firebase_uids.split(",") if uid.strip()
        )

    @model_validator(mode="after")
    def validate_demo_configuration(self) -> "Settings":
        if self.demo_mode and (
            self.environment not in {"local", "test"}
            or not self.synthetic_data
            or not self.demo_operator_uids
        ):
            raise ValueError(
                "demo mode requires a local/test environment, synthetic data, "
                "and an explicit demo-operator UID allowlist"
            )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
