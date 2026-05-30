"""Embedding backends for the memory layer.

The vault depends only on the :class:`Embedder` protocol: anything with an
``embed(text) -> vector`` method (returning a list of floats) works. A
dependency-free, deterministic :class:`HashingEmbedder` is provided so the
layer runs anywhere (no API key, no network, no model download, no numpy).
Swap in a real embedder (OpenAI, Anthropic, sentence-transformers, ...) for
production-quality semantics.
"""

from __future__ import annotations

import hashlib
import math
import re
from typing import List, Protocol, Sequence, runtime_checkable

_TOKEN_RE = re.compile(r"[a-z0-9]+")

Vector = List[float]


def tokenize(text: str) -> List[str]:
    return _TOKEN_RE.findall(text.lower())


@runtime_checkable
class Embedder(Protocol):
    """Anything that turns text into a fixed-length vector."""

    dim: int

    def embed(self, text: str) -> Vector:
        ...


class HashingEmbedder:
    """Deterministic bag-of-words embedder via the hashing trick.

    Each token is hashed into ``dim`` buckets with a signed contribution,
    giving a stable vector with no training, no network and no extra deps.
    It captures lexical overlap (shared words -> higher cosine), which is
    enough to demonstrate and test the retrieval math. It is *not* a
    semantic model; use a real embedder for nuanced meaning.
    """

    def __init__(self, dim: int = 256):
        if dim <= 0:
            raise ValueError("dim must be positive")
        self.dim = dim

    def _bucket(self, token: str) -> tuple[int, float]:
        h = hashlib.sha1(token.encode("utf-8")).digest()
        idx = int.from_bytes(h[:4], "big") % self.dim
        sign = 1.0 if h[4] & 1 else -1.0
        return idx, sign

    def embed(self, text: str) -> Vector:
        vec = [0.0] * self.dim
        for tok in tokenize(text):
            idx, sign = self._bucket(tok)
            vec[idx] += sign
        norm = math.sqrt(sum(x * x for x in vec))
        if norm > 0:
            vec = [x / norm for x in vec]
        return vec


def dot(a: Sequence[float], b: Sequence[float]) -> float:
    return sum(x * y for x, y in zip(a, b))


def cosine(a: Sequence[float], b: Sequence[float]) -> float:
    """Cosine similarity, safe against zero vectors."""
    na = math.sqrt(dot(a, a))
    nb = math.sqrt(dot(b, b))
    if na == 0.0 or nb == 0.0:
        return 0.0
    return dot(a, b) / (na * nb)
