from pydantic import BaseSettings

class Settings(BaseSettings):
    app_name: str = "Aether One Pi5 Stack"
    mqtt_broker: str = "localhost"
    mqtt_port: int = 1883
    mqtt_client_id: str = "aether-pi5"
    lr_enabled: bool = True

    # TrustCore v0.1 (attestation)
    attestation_enabled: bool = True
    attestation_interval: int = 60  # seconds
    attestation_server_url: str = "http://localhost:5000"
    attestation_policy_id: str = "policy_demo"

    class Config:
        env_prefix = "AETHER_"
        env_file = ".env"

settings = Settings()
