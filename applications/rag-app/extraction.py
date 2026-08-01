from io import BytesIO

from docx import Document
from pypdf import PdfReader

SUPPORTED_EXTENSIONS = {".txt", ".md", ".pdf", ".docx"}


def extract_text(filename: str, content: bytes) -> str:
    """Extract plain text from an uploaded file's raw bytes based on its extension."""
    suffix = _suffix(filename)
    if suffix in (".txt", ".md"):
        return content.decode("utf-8", errors="ignore")
    if suffix == ".pdf":
        return _extract_pdf(content)
    if suffix == ".docx":
        return _extract_docx(content)
    raise ValueError(
        f"Unsupported file type '{suffix or filename}'. Supported: {', '.join(sorted(SUPPORTED_EXTENSIONS))}"
    )


def _suffix(filename: str) -> str:
    if "." not in filename:
        return ""
    return "." + filename.rsplit(".", 1)[-1].lower()


def _extract_pdf(content: bytes) -> str:
    reader = PdfReader(BytesIO(content))
    pages = (page.extract_text() or "" for page in reader.pages)
    return "\n\n".join(page_text for page_text in pages if page_text.strip())


def _extract_docx(content: bytes) -> str:
    document = Document(BytesIO(content))
    return "\n\n".join(p.text for p in document.paragraphs if p.text.strip())
