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
├── applications/rag-app/     # FastAPI RAG service (Qdrant retrieval + vLLM generation)
├── manifests/                # Kubernetes manifests, one directory per component
│   ├── vllm/
│   ├── openwebui/
│   ├── qdrant/
│   ├── rag-app/
│   └── observability/        # prometheus, grafana, loki, promtail, tempo, otel-collector
├── scripts/                  # Numbered phase scripts (01-20) + run-all.sh
├── runbooks/                 # Full deployment runbook
└── docs/                     # Architecture documentation
```

## Quick start

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
| `/query` | POST | Embed a question, retrieve context from Qdrant, generate a grounded answer via vLLM |
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
