from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration, read from environment / .env (spec §14.8)."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+psycopg://tupik9:tupik9@db:5432/tupik9"
    secret_key: str = "dev-secret-change-me"

    min_client_version: str = "0.0.1"
    sim_versions_supported: str = "1"
    global_scale: float = 1.0

    validator_url: str = "http://validator:8081"
    validator_timeout_s: float = 2.0

    cors_origins: str = "https://shimmirpgbot.ru"
    cors_origin_regex: str = r"^https://([a-z0-9-]+\.)*(itch\.io|itch\.zone|hwcdn\.net)$"

    default_rate_limit_per_min: int = 60
    telemetry_min_interval_s: int = 30
    telemetry_max_window_s: int = 900
    save_max_bytes: int = 600 * 1024

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def sim_versions(self) -> list[int]:
        return [int(x) for x in self.sim_versions_supported.split(",") if x.strip()]


settings = Settings()