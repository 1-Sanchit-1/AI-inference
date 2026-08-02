import io
import logging

import fitz  # PyMuPDF
import pytesseract
from docx import Document
from PIL import Image
from pypdf import PdfReader

logger = logging.getLogger("rag-app.extraction")

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".tiff", ".bmp"}
SUPPORTED_EXTENSIONS = {".txt", ".md", ".pdf", ".docx"} | IMAGE_EXTENSIONS

# Below this average characters-per-page, a PDF's text layer is treated as
# absent (e.g. a scanned document) and OCR is used instead.
MIN_CHARS_PER_PAGE_BEFORE_OCR = 20

OCR_RENDER_DPI = 300


def extract_text(filename: str, content: bytes, force_ocr: bool = False) -> str:
    """Extract plain text from an uploaded file's raw bytes based on its extension.

    Images are always OCR'd. PDFs use their embedded text layer unless it's
    too sparse (or force_ocr is set), in which case each page is rasterized
    and OCR'd instead.
    """
    suffix = _suffix(filename)
    if suffix in (".txt", ".md"):
        return content.decode("utf-8", errors="ignore")
    if suffix in IMAGE_EXTENSIONS:
        return _ocr_image_bytes(content)
    if suffix == ".pdf":
        return _extract_pdf(content, force_ocr=force_ocr)
    if suffix == ".docx":
        return _extract_docx(content)
    raise ValueError(
        f"Unsupported file type '{suffix or filename}'. Supported: {', '.join(sorted(SUPPORTED_EXTENSIONS))}"
    )


def _suffix(filename: str) -> str:
    if "." not in filename:
        return ""
    return "." + filename.rsplit(".", 1)[-1].lower()


def _ocr_image_bytes(content: bytes) -> str:
    image = Image.open(io.BytesIO(content))
    return pytesseract.image_to_string(image)


def _extract_pdf(content: bytes, force_ocr: bool = False) -> str:
    reader = PdfReader(io.BytesIO(content))
    native_pages = [page.extract_text() or "" for page in reader.pages]
    native_text = "\n\n".join(p for p in native_pages if p.strip())

    avg_chars_per_page = len(native_text) / max(len(reader.pages), 1)
    if not force_ocr and avg_chars_per_page >= MIN_CHARS_PER_PAGE_BEFORE_OCR:
        return native_text

    logger.info(
        "Using OCR for PDF (force_ocr=%s, avg_chars_per_page=%.1f)", force_ocr, avg_chars_per_page
    )
    return _ocr_pdf(content)


def _ocr_pdf(content: bytes) -> str:
    doc = fitz.open(stream=content, filetype="pdf")
    try:
        page_texts = []
        for page in doc:
            pixmap = page.get_pixmap(dpi=OCR_RENDER_DPI)
            image = Image.open(io.BytesIO(pixmap.tobytes("png")))
            page_text = pytesseract.image_to_string(image)
            if page_text.strip():
                page_texts.append(page_text)
        return "\n\n".join(page_texts)
    finally:
        doc.close()


def _extract_docx(content: bytes) -> str:
    document = Document(io.BytesIO(content))
    return "\n\n".join(p.text for p in document.paragraphs if p.text.strip())
