import logging
import uuid

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastembed import TextEmbedding
from openai import OpenAI
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel, Field
from qdrant_client import QdrantClient
from qdrant_client.http import models as qmodels

from chunking import chunk_text
from config import settings
from extraction import extract_text
from telemetry import setup_tracing

MAX_UPLOAD_BYTES = 20 * 1024 * 1024

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("rag-app")

app = FastAPI(title="RAG Application", version="1.0.0")

Instrumentator().instrument(app).expose(app, endpoint="/metrics")
setup_tracing(app)

qdrant = QdrantClient(url=settings.qdrant_url)
embedder = TextEmbedding(model_name=settings.embedding_model)
llm_client = OpenAI(base_url=settings.vllm_base_url, api_key=settings.vllm_api_key)


class IngestRequest(BaseModel):
    text: str = Field(..., min_length=1)
    source: str = "unknown"


class IngestResponse(BaseModel):
    source: str
    chunks_ingested: int


class QueryRequest(BaseModel):
    question: str = Field(..., min_length=1)
    top_k: int = Field(default=settings.default_top_k, ge=1, le=20)


class RetrievedChunk(BaseModel):
    text: str
    source: str
    score: float


class QueryResponse(BaseModel):
    answer: str
    sources: list[RetrievedChunk]


@app.on_event("startup")
def ensure_collection() -> None:
    existing = {c.name for c in qdrant.get_collections().collections}
    if settings.qdrant_collection not in existing:
        qdrant.create_collection(
            collection_name=settings.qdrant_collection,
            vectors_config=qmodels.VectorParams(
                size=settings.embedding_dim,
                distance=qmodels.Distance.COSINE,
            ),
        )
        logger.info("Created Qdrant collection '%s'", settings.qdrant_collection)


@app.get("/health")
def health() -> dict:
    qdrant.get_collections()
    return {"status": "ok"}


def _ingest_text(text: str, source: str) -> int:
    chunks = chunk_text(
        text,
        chunk_size_words=settings.chunk_size_words,
        overlap_words=settings.chunk_overlap_words,
    )
    if not chunks:
        raise HTTPException(status_code=400, detail="No content to ingest after chunking")

    vectors = list(embedder.embed(chunks))
    points = [
        qmodels.PointStruct(
            id=str(uuid.uuid4()),
            vector=vector.tolist(),
            payload={"text": chunk, "source": source},
        )
        for chunk, vector in zip(chunks, vectors)
    ]

    qdrant.upsert(collection_name=settings.qdrant_collection, points=points)
    return len(points)


@app.post("/ingest", response_model=IngestResponse)
def ingest(request: IngestRequest) -> IngestResponse:
    count = _ingest_text(request.text, request.source)
    return IngestResponse(source=request.source, chunks_ingested=count)


@app.post("/ingest/file", response_model=IngestResponse)
async def ingest_file(
    file: UploadFile = File(...),
    source: str | None = Form(default=None),
    force_ocr: bool = Form(default=False),
) -> IngestResponse:
    if not file.filename:
        raise HTTPException(status_code=400, detail="Uploaded file has no filename")

    content = await file.read()
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"File exceeds the {MAX_UPLOAD_BYTES // (1024 * 1024)}MB upload limit",
        )

    try:
        text = extract_text(file.filename, content, force_ocr=force_ocr)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    if not text.strip():
        raise HTTPException(status_code=400, detail="No extractable text found in file")

    resolved_source = source or file.filename
    count = _ingest_text(text, resolved_source)
    return IngestResponse(source=resolved_source, chunks_ingested=count)


@app.post("/query", response_model=QueryResponse)
def query(request: QueryRequest) -> QueryResponse:
    question_vectors = list(embedder.embed([request.question]))
    if not question_vectors:
        raise HTTPException(status_code=500, detail="Failed to embed the question")
    query_vector = question_vectors[0].tolist()

    hits = qdrant.search(
        collection_name=settings.qdrant_collection,
        query_vector=query_vector,
        limit=request.top_k,
    )
    if not hits:
        raise HTTPException(status_code=404, detail="No relevant documents found; ingest data first")

    retrieved = [
        RetrievedChunk(text=hit.payload["text"], source=hit.payload["source"], score=hit.score)
        for hit in hits
    ]
    context = "\n\n".join(f"[{c.source}] {c.text}" for c in retrieved)

    completion = llm_client.chat.completions.create(
        model=settings.vllm_model,
        messages=[
            {
                "role": "system",
                "content": (
                    "Answer the user's question using only the provided context. "
                    "If the context does not contain the answer, say you don't know."
                ),
            },
            {"role": "user", "content": f"Context:\n{context}\n\nQuestion: {request.question}"},
        ],
        max_tokens=512,
        temperature=0.2,
    )

    answer = completion.choices[0].message.content or ""
    return QueryResponse(answer=answer, sources=retrieved)
