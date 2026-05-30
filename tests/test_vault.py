"""Validation gate for the Sparse Graph-Vector Memory Layer.

Implements the five-point "Mathematical Validation Test" from the design note:

1. Direct semantic matches rank high.
2. Connected graph memories are pulled in.
3. Unrelated memories remain low.
4. The system can explain which edge caused retrieval.
5. Storage stays sparse (nodes + edges only).
"""

import pytest

from social_memory_vault import RetrievalConfig, SparseGraphVectorMemory


@pytest.fixture
def vault() -> SparseGraphVectorMemory:
    m = SparseGraphVectorMemory()
    m.add_node("chris", "Chris", type="person",
               text="Chris studies artificial intelligence.")
    m.add_node("elantra", "2017 Hyundai Elantra", type="vehicle",
               text="A 2017 Hyundai Elantra car.")
    m.add_node("ai", "Artificial Intelligence", type="field",
               text="Artificial intelligence and machine learning.")
    m.add_node("neuron", "Neuron", type="biological_system",
               text="A neuron is a biological cell that transmits information.")
    m.add_edge("chris", "owns", "elantra", 1.0)
    m.add_edge("chris", "studies", "ai", 1.0)
    m.add_edge("ai", "relates_to", "neuron", 0.8)
    return m


def _by_id(results):
    return {r.node.id: r for r in results}


# --- The diffusion math must match the design note exactly ----------------- #
def test_diffusion_matches_design_note():
    """With the note's seed scores, diffusion reproduces the published
    expanded scores [0.7100, 0.2625, 1.6845, 1.3180]."""
    m = SparseGraphVectorMemory()
    for nid in ("chris", "elantra", "ai", "neuron"):
        m.add_node(nid, nid)
    m.add_edge("chris", "owns", "elantra", 1.0)
    m.add_edge("chris", "studies", "ai", 1.0)
    m.add_edge("ai", "relates_to", "neuron", 0.8)

    # Order is insertion order: chris, elantra, ai, neuron
    s0 = [0.05, 0.00, 0.95, 0.80]
    s = m.diffuse(s0, RetrievalConfig(lam=0.5, hops=2))
    expected = [0.7100, 0.2625, 1.6845, 1.3180]
    for got, exp in zip(s, expected):
        assert got == pytest.approx(exp, abs=1e-4)


def test_bidirectional_matrix_is_symmetric(vault):
    B = vault.bidirectional()
    assert len(B) == 4
    for i in range(4):
        for j in range(4):
            assert B[i][j] == B[j][i]


# --- Gate point 1: direct semantic matches rank high ----------------------- #
def test_semantic_match_ranks_high(vault):
    results = vault.retrieve("artificial intelligence", top_k=4)
    assert results[0].node.id == "ai"


# --- Gate point 2: connected graph memories are pulled in ------------------ #
def test_graph_pulls_in_connected(vault):
    results = vault.retrieve("artificial intelligence neuron", top_k=4)
    by_id = _by_id(results)
    # Neuron is connected to AI and should outrank the unrelated Elantra.
    assert by_id["neuron"].score > by_id["elantra"].score


# --- Gate point 3: unrelated memories remain low --------------------------- #
def test_unrelated_stays_low(vault):
    results = vault.retrieve("artificial intelligence neuron", top_k=4)
    by_id = _by_id(results)
    assert by_id["elantra"].rank == max(r.rank for r in results)


# --- Gate point 4: explanation names the causing edge ---------------------- #
def test_explain_direct_semantic(vault):
    exp = vault.explain("artificial intelligence", "ai")
    assert exp.semantic > 0
    assert "semantic match" in exp.describe().lower()


def test_explain_via_edge(vault):
    # Query that matches AI; neuron should be explained via the AI->neuron edge.
    exp = vault.explain("artificial intelligence", "neuron")
    assert exp.seed == "ai"
    assert exp.path, "expected a graph path"
    assert exp.path[-1].relation == "relates_to"
    assert "relates_to" in exp.describe()


# --- Gate point 5: storage stays sparse ------------------------------------ #
def test_sparse_storage(vault):
    # Source of truth is nodes + edges, not a dense matrix.
    assert len(vault.nodes) == 4
    assert len(vault.edges) == 3


def test_exact_lookup(vault):
    n = vault.get_node("neuron")
    assert n is not None and n.type == "biological_system"
    assert vault.get_node("missing") is None


def test_add_edge_unknown_node(vault):
    with pytest.raises(KeyError):
        vault.add_edge("chris", "knows", "ghost")


def test_typed_tensor(vault):
    T, relations = vault.typed_tensor()
    assert len(T) == len(relations)
    ridx = relations.index("relates_to")
    ai_i = vault._index["ai"]
    neuron_i = vault._index["neuron"]
    assert T[ridx][ai_i][neuron_i] == pytest.approx(0.8)


def test_build_context_nonempty(vault):
    ctx = vault.build_context("artificial intelligence", top_k=2)
    assert "Artificial Intelligence" in ctx
