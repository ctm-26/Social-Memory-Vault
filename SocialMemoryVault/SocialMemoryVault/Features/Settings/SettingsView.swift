import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("defaultPrivacyLevel") private var defaultPrivacyLevelRaw: String = PrivacyLevel.normal.rawValue

    @State private var showExportImport = false
    @State private var showDeleteAllConfirmation = false
    @State private var showDeleteSuccessAlert = false
    @State private var deleteErrorMessage: String? = nil
    @State private var showDeleteErrorAlert = false

    private var defaultPrivacyLevel: Binding<PrivacyLevel> {
        Binding(
            get: { PrivacyLevel(rawValue: defaultPrivacyLevelRaw) ?? .normal },
            set: { defaultPrivacyLevelRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Data Section
                Section {
                    Button {
                        showExportImport = true
                    } label: {
                        Label("Export / Import", systemImage: "arrow.up.arrow.down.circle")
                            .foregroundStyle(.primary)
                    }

                    NavigationLink {
                        DataHealthView()
                    } label: {
                        Label("Data Health", systemImage: "stethoscope")
                            .foregroundStyle(.primary)
                    }

                    Button(role: .destructive) {
                        showDeleteAllConfirmation = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Export creates a JSON file with your vault data. Delete All Data permanently removes everything from this device.")
                        .font(.caption)
                }

                // MARK: Privacy Section
                Section {
                    Picker("Default Privacy Level", selection: defaultPrivacyLevel) {
                        ForEach(PrivacyLevel.allCases, id: \.self) { level in
                            Label(level.displayName, systemImage: level.systemImage).tag(level)
                        }
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    privacyFooter
                }

                // MARK: About Section
                Section {
                    HStack {
                        Text("App")
                        Spacer()
                        Text("Social Memory Vault")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Description")
                        Spacer()
                        Text("Private relationship memory vault")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Storage")
                        Spacer()
                        Label("On-Device Only", systemImage: "lock.icloud")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("All data is stored locally on your device. Nothing is sent to any server.")
                        .font(.caption)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showExportImport) {
                ExportImportView()
            }
            .confirmationDialog(
                "Delete All Data?",
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes all entities, memories, claims, and links from this device. This cannot be undone.")
            }
            .alert("Data Deleted", isPresented: $showDeleteSuccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("All vault data has been removed.")
            }
            .alert("Delete Failed", isPresented: $showDeleteErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteErrorMessage ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Privacy Footer

    @ViewBuilder
    private var privacyFooter: some View {
        switch defaultPrivacyLevel.wrappedValue {
        case .normal:
            Text("New memories will default to Normal — included in standard exports.")
                .font(.caption)
        case .sensitive:
            Text("New memories will default to Sensitive — excluded when \"Exclude Sensitive\" is enabled.")
                .font(.caption).foregroundStyle(.orange)
        case .doNotExport:
            Text("New memories will default to Do Not Export — never included in any export.")
                .font(.caption).foregroundStyle(.red)
        }
    }

    // MARK: - Delete All

    private func deleteAllData() {
        do {
            try modelContext.delete(model: MemoryEntityLink.self)
            try modelContext.delete(model: Claim.self)
            try modelContext.delete(model: Memory.self)
            try modelContext.delete(model: EntityAlias.self)
            try modelContext.delete(model: Entity.self)
            try modelContext.save()
            showDeleteSuccessAlert = true
        } catch {
            deleteErrorMessage = error.localizedDescription
            showDeleteErrorAlert = true
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(DatabaseController.previewContainer())
}
