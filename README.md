# AI-inference

A self-hosted, GPU-accelerated AI platform on Kubernetes: an OpenAI-compatible
LLM served by [vLLM](https://github.com/vllm-project/vllm), a
retrieval-augmented generation (RAG) application backed by
[Qdrant](https://qdrant.tech/), and a full observability stack (Prometheus,
Grafana, Loki, Tempo, OpenTelemetry Collector).

Everything is deployed as Kubernetes manifests on [MicroK8s](https://microk8s.io/)
running on a single NVIDIA GPU node, and driven by a set of numbered,
idempotent shell scripts — one per phase of the deployment.

## Architecture

See [`docs/architecture.md`](docs/architecture.md) for the full diagram and
component rationale.

```
Client -> Open WebUI / RAG App -> vLLM (GPU) -> OpenAI-compatible response
                RAG App -> Qdrant (vector search)
                RAG App -> OTel Collector -> Tempo (traces)
                Prometheus -> scrapes vLLM / RAG App / Qdrant -> Grafana
                Promtail -> Loki (logs) -> Grafana
```

## Repository layout

```
.
├── applications/rag-app/     # FastAPI RAG service (Qdrant retrieval + LLM generation)
├── manifests/                # Kubernetes manifests, one directory per component
│   ├── vllm/
│   ├── openwebui/
│   ├── qdrant/
│   ├── rag-app/
│   └── observability/        # prometheus, grafana, loki, promtail, tempo, otel-collector
├── deploy/docker/            # Config files for the docker-compose stack (below)
├── docker-compose.yml        # Local, single-machine stack (Ollama + lightweight model)
├── scripts/                  # Numbered phase scripts (01-20) + run-all.sh, for the k8s path
├── runbooks/                 # Full deployment runbook (k8s / GPU path)
└── docs/                     # Architecture documentation
```

## Run it locally with Docker (lightweight, CPU-friendly)

No GPU or Kubernetes required. `docker-compose.yml` swaps vLLM for
[Ollama](https://ollama.com) running a small quantized model (default:
`qwen2.5:1.5b`, ~1GB), so the whole stack runs comfortably on a laptop.

```bash
cp .env.example .env   # optional: change OLLAMA_MODEL, or override *_HOST_PORT vars if you have a port conflict
docker compose up -d
```

This starts Ollama (pulls the model on first run), Qdrant, the RAG app, and
Open WebUI:

| Service | Default URL | Override via |
|---|---|---|
| Open WebUI (chat) | http://localhost:8080 | `OPEN_WEBUI_HOST_PORT` |
| RAG app | http://localhost:8001 | `RAG_APP_HOST_PORT` |
| Qdrant dashboard | http://localhost:6333/dashboard | — |
| Ollama API | http://localhost:11434 | `OLLAMA_HOST_PORT` |

If a port is already taken by something else on your machine (e.g. another
service already listening on 8001/8080/11434), set the corresponding
`*_HOST_PORT` variable in `.env` — this only changes the host-side port;
containers still talk to each other over the internal Docker network
regardless of these values.

Try the RAG flow (adjust the port if you overrode `RAG_APP_HOST_PORT`):

```bash
curl -X POST localhost:8001/ingest -H "Content-Type: application/json" \
  -d '{"text": "The AI platform runs on Ollama locally with the qwen2.5:1.5b model.", "source": "demo"}'

curl -X POST localhost:8001/query -H "Content-Type: application/json" \
  -d '{"question": "What model runs the AI platform locally?"}'
```

Add the full observability stack (Prometheus, Grafana, Loki, Tempo, OTel Collector):

```bash
docker compose --profile observability up -d
```

Grafana: http://localhost:3000 (`admin` / value of `GRAFANA_ADMIN_PASSWORD`, default `admin`).

Stop everything: `docker compose down` (add `--volumes` to also wipe model/data volumes).

## Run it on a GPU / Kubernetes (production path)

Prerequisites: an Ubuntu 24.04 host with an NVIDIA GPU (validated on an AWS
`g5.xlarge`), and `sudo` access.

```bash
git clone https://github.com/1-Sanchit-1/AI-inference.git
cd AI-inference/scripts
./run-all.sh
```

Or step through phases individually — see
[`runbooks/full-deployment-runbook.md`](runbooks/full-deployment-runbook.md)
for the full phase-by-phase breakdown, port-forward commands, and
troubleshooting notes.

## RAG application

The RAG service (`applications/rag-app`) exposes:

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Liveness/readiness check |
| `/ingest` | POST | Chunk, embed, and store a document in Qdrant |
| `/query` | POST | Embed a question, retrieve context from Qdrant, generate a grounded answer via the configured OpenAI-compatible backend (vLLM or Ollama) |
| `/metrics` | GET | Prometheus metrics |

Example:

```bash
curl -X POST localhost:8001/ingest \
  -H "Content-Type: application/json" \
  -d '{"text": "...", "source": "my-doc"}'

curl -X POST localhost:8001/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What does my-doc say about X?"}'
```

## License

[MIT](LICENSE)
