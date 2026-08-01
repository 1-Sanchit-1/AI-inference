def chunk_text(text: str, chunk_size_words: int, overlap_words: int) -> list[str]:
    """Split text into overlapping, word-bounded chunks."""
    words = text.split()
    if not words:
        return []

    if overlap_words < 0:
        raise ValueError("overlap_words must not be negative")
    if overlap_words >= chunk_size_words:
        raise ValueError("overlap_words must be smaller than chunk_size_words")

    stride = chunk_size_words - overlap_words
    chunks = []
    for start in range(0, len(words), stride):
        chunk = " ".join(words[start : start + chunk_size_words])
        if chunk:
            chunks.append(chunk)
        if start + chunk_size_words >= len(words):
            break
    return chunks
