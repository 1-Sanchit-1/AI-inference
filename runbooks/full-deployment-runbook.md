# Full Deployment Runbook

This runbook walks through standing up the full AI platform on a single
GPU-backed host: a self-hosted LLM served by vLLM, a retrieval-augmented
generation (RAG) application backed by Qdrant, and a complete observability
stack (metrics, logs, traces).

Each phase below corresponds to a script in [`scripts/`](../scripts), named
`NN-description.sh` so they can be run individually or all at once via
[`scripts/run-all.sh`](../scripts/run-all.sh). Every script is idempotent —
re-running a phase after a partial failure is safe.

## Prerequisites

- AWS EC2 `g5.xlarge` (1x NVIDIA A10G, 24GB VRAM) or equivalent
- Ubuntu 24.04 LTS
- A user with passwordless `sudo`
- Outbound internet access (to pull container images and model weights)
- `docker` installed locally if you intend to build the RAG app image (phase 11)

## Phases

| # | Phase | Script | Summary |
|---|-------|--------|---------|
| 1 | Host validation | `01-host-validation.sh` | Confirms OS, CPU/RAM, NVIDIA GPU presence, driver, and disk space |
| 2 | MicroK8s installation | `02-install-microk8s.sh` | Installs MicroK8s via snap, configures kubeconfig |
| 3 | Addon enablement | `03-enable-addons.sh` | Enables DNS, storage, ingress, metrics-server, Helm 3 |
| 4 | GPU Operator setup | `04-gpu-operator.sh` | Installs the NVIDIA GPU Operator so pods can request `nvidia.com/gpu` |
| 5 | CUDA validation | `05-validate-cuda.sh` | Runs a throwaway pod that calls `nvidia-smi` inside the cluster |
| 6 | vLLM deployment | `06-deploy-vllm.sh` | Deploys vLLM serving an OpenAI-compatible API on the GPU |
| 7 | vLLM validation | `07-validate-vllm.sh` | Exercises `/v1/models` and `/v1/chat/completions` |
| 8 | Open WebUI installation | `08-deploy-openwebui.sh` | Deploys a chat UI pointed at the vLLM endpoint |
| 9 | Open WebUI validation | `09-validate-openwebui.sh` | Confirms the UI is reachable and healthy |
| 10 | Qdrant deployment | `10-deploy-qdrant.sh` | Deploys the vector database used for retrieval |
| 11 | RAG application build | `11-build-rag-app.sh` | Builds the FastAPI RAG app image and imports it into MicroK8s |
| 12 | RAG application deployment | `12-deploy-rag-app.sh` | Deploys the RAG app |
| 13 | RAG validation | `13-validate-rag.sh` | Ingests a sample document and asks a question that requires it |
| 14 | Prometheus/Grafana deployment | `14-deploy-prometheus-grafana.sh` | Deploys metrics collection and dashboards, generates the Grafana admin secret |
| 15 | Loki setup | `15-deploy-loki.sh` | Deploys log aggregation storage |
| 16 | Promtail configuration | `16-configure-promtail.sh` | Deploys the log-shipping DaemonSet |
| 17 | Tempo tracing | `17-deploy-tempo.sh` | Deploys distributed trace storage |
| 18 | OpenTelemetry Collector | `18-deploy-otel-collector.sh` | Deploys the OTLP receiver that forwards traces to Tempo |
| 19 | Trace validation | `19-validate-tracing.sh` | Generates a request and confirms the resulting trace lands in Tempo |
| 20 | Resource verification | `20-verify-resources.sh` | Final sweep confirming every workload is healthy |

## Running it

```bash
git clone https://github.com/1-Sanchit-1/AI-inference.git
cd AI-inference/scripts
./run-all.sh
```

Or run phases individually, e.g. to redeploy just the RAG app after a code change:

```bash
./scripts/11-build-rag-app.sh
./scripts/12-deploy-rag-app.sh
./scripts/13-validate-rag.sh
```

## Accessing the services

None of the services are exposed outside the cluster by default; use
`kubectl port-forward` (as the validation scripts do) or add an Ingress if
you need external access.

| Service | Namespace | Port-forward command |
|---|---|---|
| vLLM (OpenAI API) | `ai-platform` | `kubectl -n ai-platform port-forward svc/vllm 8000:8000` |
| Open WebUI | `ai-platform` | `kubectl -n ai-platform port-forward svc/open-webui 8080:8080` |
| RAG app | `ai-platform` | `kubectl -n ai-platform port-forward svc/rag-app 8001:8001` |
| Qdrant | `ai-platform` | `kubectl -n ai-platform port-forward svc/qdrant 6333:6333` |
| Grafana | `observability` | `kubectl -n observability port-forward svc/grafana 3000:3000` |
| Prometheus | `observability` | `kubectl -n observability port-forward svc/prometheus 9090:9090` |
| Tempo | `observability` | `kubectl -n observability port-forward svc/tempo 3200:3200` |

Grafana's admin password is generated during phase 14 and stored in the
`grafana-admin` Secret in the `observability` namespace — it is never
committed to the repository:

```bash
kubectl -n observability get secret grafana-admin -o jsonpath='{.data.password}' | base64 -d
```

## Troubleshooting

- **vLLM pod stuck in `Pending`**: check `kubectl -n ai-platform describe pod -l app=vllm` — usually means the GPU Operator (phase 4) hasn't finished labeling the node with `nvidia.com/gpu` yet.
- **vLLM pod `CrashLoopBackOff` on startup**: model download can take several minutes on first boot; check `kubectl -n ai-platform logs -l app=vllm` before assuming failure — the readiness probe allows up to 10 failed checks before flagging.
- **RAG app returns 404 on `/query`**: no documents have been ingested yet, or the Qdrant collection was created with a mismatched embedding dimension — delete the `documents` collection and let the app recreate it.
- **No traces in Tempo**: confirm the RAG app's `OTEL_EXPORTER_OTLP_ENDPOINT` resolves to the OTel Collector Service, and that the Collector's `otlp/tempo` exporter is pointed at `tempo.observability.svc.cluster.local:4317`.
