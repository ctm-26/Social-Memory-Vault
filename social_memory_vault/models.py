"""Core data structures for the Sparse Graph-Vector Memory Layer.

A memory is modeled as a graph ``G = (V, E)`` where each node ``v_i`` is a
:class:`MemoryNode` carrying an embedding ``e_i`` and each edge is a typed,
weighted :class:`Relationship`.

The graph is stored *sparsely* (only the nodes and edges that actually exist).
Dense matrices ``A`` / ``T`` are derived on demand by the vault, never stored,
so the layer scales to many nodes without paying for empty matrix cells.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from time import time
from typing import Any, Dict, List, Optional, Sequence


def _now() -> float:
    return time()


@dataclass
class MemoryNode:
    """A single memory object.

    Attributes mirror the "memory object" shape from the design note:
    an id, a human label, a type, free-form properties, the source text,
    its embedding, a creation timestamp and a confidence in [0, 1].
    """

    id: str
    label: str
    type: str = "concept"
    text: str = ""
    properties: Dict[str, Any] = field(default_factory=dict)
    embedding: Optional[Sequence[float]] = None
    created_at: float = field(default_factory=_now)
    confidence: float = 1.0

    def to_dict(self) -> Dict[str, Any]:
        d = {
            "id": self.id,
            "label": self.label,
            "type": self.type,
            "text": self.text,
            "properties": dict(self.properties),
            "created_at": self.created_at,
            "confidence": self.confidence,
        }
        if self.embedding is not None:
            d["embedding"] = list(self.embedding)
        return d


@dataclass
class Relationship:
    """A typed, weighted, directed edge ``(source, relation, target)``.

    ``weight`` expresses connection strength in [0, 1]; ``evidence`` records
    *why* the edge exists and ``confidence`` how sure we are it should.
    """

    source: str
    relation: str
    target: str
    weight: float = 1.0
    evidence: str = ""
    confidence: float = 1.0

    def to_dict(self) -> Dict[str, Any]:
        return {
            "source": self.source,
            "relation": self.relation,
            "target": self.target,
            "weight": self.weight,
            "evidence": self.evidence,
            "confidence": self.confidence,
        }


@dataclass
class RetrievalConfig:
    """Tunable knobs for retrieval.

    The final score for a node is::

        s_final = alpha * s_semantic
                + beta  * s_graph
                + gamma * confidence
                + delta * recency

    where ``s_graph`` is the graph-diffused score
    ``s0 + lambda*B*s0 + ... + lambda^hops * B^hops * s0``.

    Defaults reproduce the pure graph-diffusion behaviour from the design
    note (alpha=0 so the semantic seed isn't double-counted, since it is
    already the seed of ``s_graph``).
    """

    lam: float = 0.5          # graph spread strength (lambda)
    hops: int = 2             # diffusion order
    alpha: float = 0.0        # weight on raw semantic similarity
    beta: float = 1.0         # weight on graph-diffused score
    gamma: float = 0.0        # weight on node confidence
    delta: float = 0.0        # weight on recency
    recency_halflife_s: float = 7 * 24 * 3600.0  # 1 week half-life


@dataclass
class RetrievalResult:
    """One ranked memory plus the signals that produced its score."""

    node: MemoryNode
    score: float
    semantic: float
    graph: float
    rank: int

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.node.id,
            "label": self.node.label,
            "score": self.score,
            "semantic": self.semantic,
            "graph": self.graph,
            "rank": self.rank,
        }


@dataclass
class Explanation:
    """Why a memory was retrieved: its own semantic match plus the edge
    path from the strongest semantic seed that diffused score into it."""

    target: str
    semantic: float
    graph: float
    seed: Optional[str]
    path: List[Relationship] = field(default_factory=list)

    def describe(self) -> str:
        if not self.path:
            return (
                f"'{self.target}' was retrieved by direct semantic match "
                f"(similarity={self.semantic:.3f})."
            )
        hops = " -> ".join(
            f"{r.source} --{r.relation}({r.weight:g})--> {r.target}"
            for r in self.path
        )
        return (
            f"'{self.target}' was pulled in via the graph from seed "
            f"'{self.seed}': {hops}"
        )
