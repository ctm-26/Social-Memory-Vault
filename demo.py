"""Toy demo of the Sparse Graph-Vector Memory Layer.

Reproduces the design-note example:

    Chris --owns--> Elantra          (1.0)
    Chris --studies--> AI            (1.0)
    AI    --relates_to--> Neuron     (0.8)

Run:  python demo.py
"""

from social_memory_vault import RetrievalConfig, SparseGraphVectorMemory


def build_vault() -> SparseGraphVectorMemory:
    m = SparseGraphVectorMemory()

    m.add_node("chris", "Chris", type="person",
               text="Chris is a person who studies artificial intelligence.")
    m.add_node("elantra", "2017 Hyundai Elantra", type="vehicle",
               text="A 2017 Hyundai Elantra car owned by Chris.")
    m.add_node("ai", "Artificial Intelligence", type="field",
               text="Artificial intelligence is the study of machine intelligence.")
    m.add_node("neuron", "Neuron", type="biological_system",
               text="A neuron is a biological cell that processes and transmits information.")

    m.add_edge("chris", "owns", "elantra", weight=1.0,
               evidence="Chris owns the Elantra.")
    m.add_edge("chris", "studies", "ai", weight=1.0,
               evidence="Chris studies AI.")
    m.add_edge("ai", "relates_to", "neuron", weight=0.8,
               evidence="User connected AI efficiency to biological neurons.")
    return m


def main() -> None:
    m = build_vault()

    print("=== Exact lookup ===")
    print(m.get_node("neuron").label, "->", m.get_node("neuron").text)

    print("\n=== Adjacency matrix A (max weight per pair) ===")
    for row in m.adjacency():
        print("  ", row)

    query = "AI and neurons"
    print(f"\n=== Retrieval for query: {query!r} ===")
    cfg = RetrievalConfig(lam=0.5, hops=2)
    for r in m.retrieve(query, top_k=4, config=cfg):
        print(f"  {r.rank + 1}. {r.node.label:24s} "
              f"score={r.score:.4f}  semantic={r.semantic:.4f}  graph={r.graph:.4f}")

    print("\n=== Why was 'Neuron' retrieved? ===")
    print("  " + m.explain(query, "neuron").describe())

    print("\n=== Why was 'Elantra' retrieved? ===")
    print("  " + m.explain(query, "elantra").describe())

    print("\n=== LLM context block ===")
    print(m.build_context(query, top_k=3, config=cfg))


if __name__ == "__main__":
    main()
