# Social Memory Vault

An explainable **sparse graph-vector memory layer** for large-language-model systems.

Social Memory Vault combines two retrieval signals:

- a **vector layer** for similarity between a query and stored memory text,
- a **graph layer** for typed, weighted relationships between memories.

The result is a small GraphRAG-style research prototype that can explain not only which memory was retrieved, but which graph path contributed to that result.

## Status

**Research prototype, version 0.1.0.**

The core implementation and validation tests exist. It is designed to make the retrieval model inspectable and reproducible, not to serve as a production database.

## Why this exists

Plain similarity search can find text that resembles a query while missing structurally related information. A graph can preserve those relationships, but graph traversal alone does not know which part of the graph is semantically relevant to the current query.

Social Memory Vault joins the two:

```text
query
  ↓
embedding similarity seed, s₀
  ↓
graph diffusion through typed, weighted edges
  ↓
ranked memories + explanation paths
  ↓
LLM-ready context block
```

For a bidirectional graph matrix `B`, the prototype diffuses the semantic seed over a configurable number of hops:

```text
s_graph = s₀ + λB s₀ + λ²B² s₀ + ...
```

The final score can combine raw semantic similarity, graph diffusion, confidence, and recency.

## What is included

| File or module | Responsibility |
| --- | --- |
| `social_memory_vault/models.py` | Memory nodes, relationships, retrieval configuration, results, and explanations |
| `social_memory_vault/embeddings.py` | Embedder protocol and deterministic hashing embedder |
| `social_memory_vault/vault.py` | Sparse storage, graph matrices, diffusion, ranking, explanations, and context assembly |
| `demo.py` | Small Chris → AI → Neuron example showing retrieval and explanations |
| `tests/` | Validation gates and exact diffusion-math checks |

The runtime core uses only the Python standard library. `pytest` is used for development validation.

## Quick start

Requirements:

- Python 3.10 or newer

```bash
python -m venv .venv
source .venv/bin/activate          # Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements.txt

python demo.py
python -m pytest
```

## Minimal example

```python
from social_memory_vault import RetrievalConfig, SparseGraphVectorMemory

memory = SparseGraphVectorMemory()

memory.add_node(
    "ai",
    "Artificial Intelligence",
    type="field",
    text="Artificial intelligence studies machine intelligence.",
)
memory.add_node(
    "neuron",
    "Neuron",
    type="biological_system",
    text="A neuron processes and transmits information.",
)
memory.add_edge(
    "ai",
    "relates_to",
    "neuron",
    weight=0.8,
    evidence="AI systems are often compared with biological information processing.",
)

results = memory.retrieve(
    "AI and neurons",
    top_k=2,
    config=RetrievalConfig(lam=0.5, hops=2),
)

for result in results:
    print(result.node.label, result.score)

print(memory.explain("AI and neurons", "neuron").describe())
```

## Design properties

- **Sparse storage:** only actual nodes and edges are stored.
- **Typed relationships:** edges preserve relationship meaning rather than reducing the graph to anonymous proximity.
- **Weighted diffusion:** graph influence is explicit and configurable.
- **Explainable retrieval:** results retain direct similarity and graph-path evidence.
- **Pluggable embeddings:** replace the deterministic hashing embedder with a production embedding backend through the `Embedder` protocol.
- **No network requirement:** the included implementation runs locally without an API key or model download.

## Verification

The test suite checks the core behavioral gates, including exact diffusion values for the reference graph. This makes changes to graph math visible rather than relying on qualitative model output.

Run:

```bash
python -m pytest
```

## Current limitations

- The included `HashingEmbedder` captures lexical overlap, not deep semantic meaning.
- Storage is in memory; persistence and migrations are not implemented.
- Dense matrix views are derived for inspection and math clarity, not optimized for very large graphs.
- Retrieval quality has not been benchmarked against production vector or graph databases.
- There is no authentication, multi-user boundary, or service API.

These are intentional prototype boundaries, not hidden production claims.

## Possible next steps

- Add a persistent storage adapter.
- Integrate a real local or hosted embedding model.
- Benchmark retrieval quality and latency against vector-only baselines.
- Add relation-type weighting and constrained traversal policies.
- Expose the vault through an MCP server for controlled agent memory access.
- Add provenance, conflict handling, and memory expiration policies.

## AI-assisted engineering disclosure

AI tools assisted with implementation and documentation. The project is presented as an inspectable prototype: claims should be evaluated against the source, tests, and stated limitations rather than model-generated confidence.

## License

No license has been selected yet. Until one is added, the source remains all-rights-reserved by default.
