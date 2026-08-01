from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    qdrant_url: str = "http://qdrant.ai-platform.svc.cluster.local:6333"
    qdrant_collection: str = "documents"

    vllm_base_url: str = "http://vllm.ai-platform.svc.cluster.local:8000/v1"
    vllm_model: str = "Qwen/Qwen2.5-7B-Instruct"
    vllm_api_key: str = "not-needed"

    embedding_model: str = "BAAI/bge-small-en-v1.5"
    embedding_dim: int = 384

    otel_service_name: str = "rag-app"
    otel_exporter_otlp_endpoint: str = "http://otel-collector.observability.svc.cluster.local:4317"

    chunk_size_words: int = 200
    chunk_overlap_words: int = 40
    default_top_k: int = 4

    class Config:
        env_prefix = ""
        case_sensitive = False


settings = Settings()
