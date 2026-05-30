"""Sparse Graph-Vector Memory Layer.

An external memory system for an LLM that combines two "brains":

* **Vector brain** - semantic similarity over embeddings (meaning).
* **Graph brain** - typed, weighted relationships (structure).

A query is embedded, scored against every node by cosine similarity, then the
score is *diffused* across the relationship graph so connected memories are
pulled in. The result is ranked, explainable, and can be turned into a text
context block to hand to an LLM (RAG / GraphRAG style).

Storage is sparse: nodes and edges only. The adjacency matrix ``A``, typed
tensor ``T`` and bidirectional matrix ``B = A + A^T`` are derived on demand.
Pure Python, no third-party dependencies.
"""

from __future__ import annotations

from collections import deque
from time import time
from typing import Deque, Dict, List, Optional, Sequence, Tuple

from .embeddings import Embedder, HashingEmbedder, cosine
from .models import (
    Explanation,
    MemoryNode,
    Relationship,
    RetrievalConfig,
    RetrievalResult,
)

Matrix = List[List[float]]


def _matvec(M: Matrix, v: Sequence[float]) -> List[float]:
    return [sum(row[j] * v[j] for j in range(len(v))) for row in M]


class SparseGraphVectorMemory:
    """The memory vault.

    Parameters
    ----------
    embedder:
        Any object implementing the :class:`Embedder` protocol. Defaults to
        the dependency-free :class:`HashingEmbedder`.
    config:
        Default :class:`RetrievalConfig`; can be overridden per query.
    """

    # Below this similarity a node is treated as not a direct semantic match.
    _SEMANTIC_EPS = 1e-9

    def __init__(
        self,
        embedder: Optional[Embedder] = None,
        config: Optional[RetrievalConfig] = None,
    ):
        self.embedder: Embedder = embedder or HashingEmbedder()
        self.config = config or RetrievalConfig()
        # Sparse source of truth.
        self._nodes: Dict[str, MemoryNode] = {}
        self._edges: List[Relationship] = []
        # Cache of the node-id -> matrix-index ordering, invalidated on write.
        self._order: List[str] = []
        self._index: Dict[str, int] = {}

    # ------------------------------------------------------------------ #
    # Writing
    # ------------------------------------------------------------------ #
    def add_node(
        self,
        id: str,
        label: Optional[str] = None,
        type: str = "concept",
        text: str = "",
        properties: Optional[dict] = None,
        confidence: float = 1.0,
        embedding: Optional[Sequence[float]] = None,
    ) -> MemoryNode:
        """Add or replace a memory node. Embeds ``text`` if no vector given."""
        label = label if label is not None else id
        if embedding is None:
            embed_src = text or label
            embedding = self.embedder.embed(embed_src)
        node = MemoryNode(
            id=id,
            label=label,
            type=type,
            text=text,
            properties=properties or {},
            embedding=[float(x) for x in embedding],
            confidence=confidence,
        )
        self._nodes[id] = node
        self._invalidate()
        return node

    def add_edge(
        self,
        source: str,
        relation: str,
        target: str,
        weight: float = 1.0,
        evidence: str = "",
        confidence: float = 1.0,
    ) -> Relationship:
        """Add a typed, weighted directed edge between two existing nodes."""
        if source not in self._nodes:
            raise KeyError(f"unknown source node: {source!r}")
        if target not in self._nodes:
            raise KeyError(f"unknown target node: {target!r}")
        rel = Relationship(
            source=source,
            relation=relation,
            target=target,
            weight=float(weight),
            evidence=evidence,
            confidence=confidence,
        )
        self._edges.append(rel)
        return rel

    def _invalidate(self) -> None:
        self._order = []
        self._index = {}

    # ------------------------------------------------------------------ #
    # Reading / exact lookup
    # ------------------------------------------------------------------ #
    def get_node(self, id: str) -> Optional[MemoryNode]:
        return self._nodes.get(id)

    @property
    def nodes(self) -> List[MemoryNode]:
        return list(self._nodes.values())

    @property
    def edges(self) -> List[Relationship]:
        return list(self._edges)

    def neighbors(self, id: str) -> List[Relationship]:
        """Outgoing edges from ``id``."""
        return [e for e in self._edges if e.source == id]

    # ------------------------------------------------------------------ #
    # Derived matrices (built on demand from sparse storage)
    # ------------------------------------------------------------------ #
    def _ensure_order(self) -> None:
        if self._order:
            return
        self._order = list(self._nodes.keys())
        self._index = {nid: i for i, nid in enumerate(self._order)}

    def adjacency(self) -> Matrix:
        """Dense ``A`` with ``A[i][j] = max relation weight i -> j``."""
        self._ensure_order()
        n = len(self._order)
        A = [[0.0] * n for _ in range(n)]
        for e in self._edges:
            i, j = self._index[e.source], self._index[e.target]
            if e.weight > A[i][j]:
                A[i][j] = e.weight
        return A

    def typed_tensor(self) -> Tuple[List[Matrix], List[str]]:
        """Dense ``T[i][r][j]`` and the ordered list of relation names.

        Returned as ``T[r]`` -> matrix for relation ``r`` (a list of
        per-relation adjacency matrices) plus the relation-name ordering.
        """
        self._ensure_order()
        relations = sorted({e.relation for e in self._edges})
        rindex = {r: k for k, r in enumerate(relations)}
        n = len(self._order)
        T = [[[0.0] * n for _ in range(n)] for _ in relations]
        for e in self._edges:
            i, j, k = self._index[e.source], self._index[e.target], rindex[e.relation]
            if e.weight > T[k][i][j]:
                T[k][i][j] = e.weight
        return T, relations

    def bidirectional(self) -> Matrix:
        """Symmetric ``B = A + A^T`` used for diffusion."""
        A = self.adjacency()
        n = len(A)
        return [[A[i][j] + A[j][i] for j in range(n)] for i in range(n)]

    # ------------------------------------------------------------------ #
    # Retrieval
    # ------------------------------------------------------------------ #
    def semantic_scores(self, query: str) -> List[float]:
        """Cosine similarity of the query against every node, clamped to
        [0, 1] so it can seed graph diffusion as a relevance mass."""
        self._ensure_order()
        q = self.embedder.embed(query)
        s = [0.0] * len(self._order)
        for nid, i in self._index.items():
            s[i] = max(0.0, cosine(q, self._nodes[nid].embedding))
        return s

    def diffuse(
        self, s0: Sequence[float], config: Optional[RetrievalConfig] = None
    ) -> List[float]:
        """Graph diffusion ``s = s0 + lam*B*s0 + lam^2*B^2*s0 + ...``."""
        cfg = config or self.config
        B = self.bidirectional()
        s = list(s0)
        term = list(s0)
        for _ in range(cfg.hops):
            term = [cfg.lam * x for x in _matvec(B, term)]
            s = [a + b for a, b in zip(s, term)]
        return s

    def _recency(self, now: Optional[float], config: RetrievalConfig) -> List[float]:
        self._ensure_order()
        now = time() if now is None else now
        hl = config.recency_halflife_s
        out = [0.0] * len(self._order)
        for nid, i in self._index.items():
            age = max(0.0, now - self._nodes[nid].created_at)
            out[i] = 0.5 ** (age / hl) if hl > 0 else 1.0
        return out

    def retrieve(
        self,
        query: str,
        top_k: int = 5,
        config: Optional[RetrievalConfig] = None,
        now: Optional[float] = None,
    ) -> List[RetrievalResult]:
        """Rank memories for a query combining semantic + graph signals."""
        cfg = config or self.config
        self._ensure_order()
        if not self._order:
            return []
        s_sem = self.semantic_scores(query)
        s_graph = self.diffuse(s_sem, cfg)
        rec = self._recency(now, cfg)
        s_final = []
        for i, nid in enumerate(self._order):
            conf = self._nodes[nid].confidence
            s_final.append(
                cfg.alpha * s_sem[i]
                + cfg.beta * s_graph[i]
                + cfg.gamma * conf
                + cfg.delta * rec[i]
            )
        ranked = sorted(range(len(self._order)), key=lambda i: s_final[i], reverse=True)
        results: List[RetrievalResult] = []
        for rank, i in enumerate(ranked[:top_k]):
            nid = self._order[i]
            results.append(
                RetrievalResult(
                    node=self._nodes[nid],
                    score=float(s_final[i]),
                    semantic=float(s_sem[i]),
                    graph=float(s_graph[i]),
                    rank=rank,
                )
            )
        return results

    # ------------------------------------------------------------------ #
    # Explainability
    # ------------------------------------------------------------------ #
    def explain(self, query: str, target_id: str) -> Explanation:
        """Explain why ``target_id`` scores for ``query``.

        If the target itself matches semantically, that's the reason.
        Otherwise we find the strongest-semantic node that can reach the
        target over the graph and return the shortest edge path, i.e. the
        edge(s) that diffused score into the target.
        """
        if target_id not in self._nodes:
            raise KeyError(target_id)
        self._ensure_order()
        s_sem = self.semantic_scores(query)
        ti = self._index[target_id]
        target_sem = float(s_sem[ti])
        s_graph = self.diffuse(s_sem)
        target_graph = float(s_graph[ti])

        # If the node matched the query on its own merits, that's the reason;
        # we only trace a graph path when it was genuinely pulled in.
        if target_sem > self._SEMANTIC_EPS:
            return Explanation(
                target=target_id,
                semantic=target_sem,
                graph=target_graph,
                seed=None,
                path=[],
            )

        # Seeds = nodes with meaningful direct semantic match.
        seeds = [
            self._order[i]
            for i in range(len(self._order))
            if s_sem[i] > 1e-9 and self._order[i] != target_id
        ]
        seeds.sort(key=lambda nid: s_sem[self._index[nid]], reverse=True)

        best_seed: Optional[str] = None
        best_path: List[Relationship] = []
        for seed in seeds:
            path = self._shortest_path(seed, target_id)
            if path is not None:
                best_seed = seed
                best_path = path
                break

        return Explanation(
            target=target_id,
            semantic=target_sem,
            graph=target_graph,
            seed=best_seed,
            path=best_path,
        )

    def _shortest_path(self, src: str, dst: str) -> Optional[List[Relationship]]:
        """BFS over the *undirected* view of the graph; returns the edge
        list (in traversal direction) or None if unreachable."""
        if src == dst:
            return []
        adj: Dict[str, List[Tuple[str, Relationship]]] = {}
        for e in self._edges:
            adj.setdefault(e.source, []).append((e.target, e))
            adj.setdefault(e.target, []).append((e.source, e))
        visited = {src}
        queue: Deque[Tuple[str, List[Relationship]]] = deque([(src, [])])
        while queue:
            node, path = queue.popleft()
            for nbr, rel in adj.get(node, []):
                if nbr in visited:
                    continue
                new_path = path + [rel]
                if nbr == dst:
                    return new_path
                visited.add(nbr)
                queue.append((nbr, new_path))
        return None

    # ------------------------------------------------------------------ #
    # LLM context assembly (RAG hand-off)
    # ------------------------------------------------------------------ #
    def build_context(
        self,
        query: str,
        top_k: int = 5,
        config: Optional[RetrievalConfig] = None,
    ) -> str:
        """Render the top memories as a text context block for an LLM."""
        results = self.retrieve(query, top_k=top_k, config=config)
        lines = ["# Retrieved memory context", ""]
        for r in results:
            n = r.node
            body = n.text or n.label
            lines.append(
                f"- ({n.type}) {n.label}: {body} "
                f"[score={r.score:.3f}, conf={n.confidence:g}]"
            )
        return "\n".join(lines)
