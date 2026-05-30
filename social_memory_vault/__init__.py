"""Social Memory Vault - a Sparse Graph-Vector Memory Layer for LLMs.

A structured external memory that stores facts as graph nodes with embeddings
and typed relationships as weighted edges, then retrieves them by combining
vector (semantic) and graph (structural) search - RAG / GraphRAG style.
"""

from .embeddings import Embedder, HashingEmbedder, cosine, dot, tokenize
from .models import (
    Explanation,
    MemoryNode,
    Relationship,
    RetrievalConfig,
    RetrievalResult,
)
from .vault import SparseGraphVectorMemory

__all__ = [
    "SparseGraphVectorMemory",
    "MemoryNode",
    "Relationship",
    "RetrievalConfig",
    "RetrievalResult",
    "Explanation",
    "Embedder",
    "HashingEmbedder",
    "cosine",
    "dot",
    "tokenize",
]

__version__ = "0.1.0"
