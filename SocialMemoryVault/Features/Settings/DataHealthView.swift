import SwiftUI
import SwiftData

struct DataHealthView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var scanResults: [StrandedValueService.ScanResult] = []
    @State private var isScanning = false
    @State private var hasScanned = false
    @State private var prefilledEntityName: String = ""
    @State private var showCreateEntity = false

    var body: some View {
        List {
            // Scan button section
            Section {
                Button {
                    runScan()
                } label: {
                    HStack {
                        Image(systemName: isScanning ? "hourglass" : "magnifyingglass.circle.fill")
                            .foregroundStyle(isScanning ? .secondary : .accentColor)
                        Text(isScanning ? "Scanning…" : "Scan for Stranded Values")
                            .foregroundStyle(isScanning ? .secondary : .primary)
                    }
                }
                .disabled(isScanning)
            } footer: {
                Text("Finds claims where the value field contains text that matches an existing entity. You can promote these to proper entity links.")
                    .font(.caption)
            }

            // Results
            if hasScanned {
                if scanResults.isEmpty {
                    Section {
                        Label("No stranded values found. Data looks clean.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Section {
                        Text("\(scanResults.count) stranded value\(scanResults.count == 1 ? "" : "s") found.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(scanResults) { result in
                        StrandedResultRow(
                            result: result,
                            onPromote: { entity in
                                StrandedValueService.promote(claim: result.claim, to: entity, context: modelContext)
                                // Refresh scan
                                scanResults = StrandedValueService.scan(context: modelContext)
                            },
                            onCreateEntity: { name in
                                prefilledEntityName = name
                                showCreateEntity = true
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data Health")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreateEntity) {
            AddEditEntityView()
        }
    }

    private func runScan() {
        isScanning = true
        // Small delay for visual feedback
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await MainActor.run {
                scanResults = StrandedValueService.scan(context: modelContext)
                hasScanned = true
                isScanning = false
            }
        }
    }
}

// MARK: - Stranded Result Row

private struct StrandedResultRow: View {
    let result: StrandedValueService.ScanResult
    let onPromote: (Entity) -> Void
    let onCreateEntity: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Claim info
            VStack(alignment: .leading, spacing: 3) {
                Text("Claim value:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(result.claim.value ?? "")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text("predicate: \(result.claim.predicate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Match info and actions
            switch result.matchKind {
            case .strong(let entity):
                VStack(alignment: .leading, spacing: 6) {
                    Label("Strong match: \(entity.canonicalName) (\(entity.entityTypeEnum.displayName))", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    Button("Promote to entity link") {
                        onPromote(entity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

            case .soft(let entity, let distance):
                VStack(alignment: .leading, spacing: 6) {
                    Label("Soft match (distance \(distance)): \(entity.canonicalName) — verify?", systemImage: "questionmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Button("Promote (matches \(entity.canonicalName) — verify?)") {
                        onPromote(entity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

            case .none:
                VStack(alignment: .leading, spacing: 6) {
                    Label("No matching entity found.", systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Create new entity from this value") {
                        onCreateEntity(result.claim.value ?? "")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DataHealthView()
    }
    .modelContainer(DatabaseController.previewContainer())
}
