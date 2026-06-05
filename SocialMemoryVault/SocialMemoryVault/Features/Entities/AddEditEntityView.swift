import SwiftUI
import SwiftData

struct AddEditEntityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Editing mode when an entity is passed
    private let existingEntity: Entity?

    // MARK: - Form State

    @State private var canonicalName: String
    @State private var selectedType: EntityType
    @State private var notes: String
    @State private var validationErrors: [String] = []
    @State private var isSaving = false

    // MARK: - Guard 4: Notes-as-alias detector

    @State private var showAliasPrompt = false
    @State private var aliasPromptMessage = ""
    @State private var pendingAliasSuggestion: String? = nil

    // MARK: - Init

    init(entity: Entity? = nil) {
        self.existingEntity = entity
        _canonicalName = State(initialValue: entity?.canonicalName ?? "")
        _selectedType = State(initialValue: entity?.entityTypeEnum ?? .person)
        _notes = State(initialValue: entity?.notes ?? "")
    }

    // MARK: - Computed

    private var isEditing: Bool { existingEntity != nil }
    private var title: String { isEditing ? "Edit Entity" : "New Entity" }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Name field
                Section {
                    TextField("Name", text: $canonicalName, axis: .vertical)
                        .font(.body)
                        .autocorrectionDisabled(false)
                        .onChange(of: canonicalName) { _, _ in
                            clearFieldError("Name")
                        }
                } header: {
                    Text("Name")
                } footer: {
                    if let nameError = validationErrors.first(where: { $0.contains("Name") }) {
                        Text(nameError)
                            .foregroundStyle(.red)
                    }
                }

                // Entity type picker
                Section("Type") {
                    Picker("Entity Type", selection: $selectedType) {
                        ForEach(EntityType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.systemImage)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Notes field
                Section {
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Optional notes about this entity…")
                                .foregroundStyle(.tertiary)
                                .font(.body)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $notes)
                            .font(.body)
                            .frame(minHeight: 90)
                    }
                } header: {
                    Text("Notes")
                }

                // Validation errors
                if !validationErrors.isEmpty {
                    Section {
                        ForEach(validationErrors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(canonicalName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .disabled(isSaving)
            .confirmationDialog("Add as Alias?", isPresented: $showAliasPrompt, titleVisibility: .visible) {
                Button("Yes — add alias and clear notes") { commitSave(addAlias: true) }
                Button("No — keep in notes", role: .cancel) { commitSave(addAlias: false) }
            } message: {
                Text(aliasPromptMessage)
            }
        }
    }

    // MARK: - Save

    private func save() {
        let trimmedName = canonicalName.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        let errors = Validation.validateEntity(canonicalName: trimmedName, entityType: selectedType.rawValue)
        guard errors.isEmpty else { validationErrors = errors; return }

        validationErrors = []
        isSaving = true

        if !trimmedNotes.isEmpty {
            // Check A: Acronym alias
            if let suggestion = AcronymAliasDetector.checkAcronymAlias(canonicalName: trimmedName, notes: trimmedNotes) {
                pendingAliasSuggestion = suggestion
                aliasPromptMessage = "'\(suggestion)' looks like the full name of \(trimmedName). Add as alias?"
                showAliasPrompt = true
                isSaving = false
                return
            }

            // Check B: Short proper-noun
            if AcronymAliasDetector.checkShortProperNoun(notes: trimmedNotes) {
                pendingAliasSuggestion = trimmedNotes
                aliasPromptMessage = "This looks like an alternate name. Add '\(trimmedNotes)' as alias?"
                showAliasPrompt = true
                isSaving = false
                return
            }
        }

        commitSave(addAlias: false)
    }

    private func commitSave(addAlias: Bool) {
        let trimmedName = canonicalName.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let resolvedNotes: String? = addAlias ? nil : (trimmedNotes.isEmpty ? nil : trimmedNotes)

        if let existing = existingEntity {
            // Update existing entity
            existing.canonicalName = trimmedName
            existing.entityType = selectedType.rawValue
            existing.notes = resolvedNotes
            existing.updatedAt = Date()

            if addAlias, let alias = pendingAliasSuggestion {
                let entityAlias = EntityAlias(entityId: existing.id, alias: alias)
                modelContext.insert(entityAlias)
            }
        } else {
            // Create new entity
            let newEntity = Entity(
                entityType: selectedType,
                canonicalName: trimmedName,
                notes: resolvedNotes
            )
            modelContext.insert(newEntity)

            if addAlias, let alias = pendingAliasSuggestion {
                let entityAlias = EntityAlias(entityId: newEntity.id, alias: alias)
                modelContext.insert(entityAlias)
            }
        }

        pendingAliasSuggestion = nil

        do {
            try modelContext.save()
            dismiss()
        } catch {
            validationErrors = ["Failed to save: \(error.localizedDescription)"]
            isSaving = false
        }
    }

    // MARK: - Helpers

    private func clearFieldError(_ keyword: String) {
        validationErrors.removeAll { $0.contains(keyword) }
    }
}

// MARK: - Preview

#Preview("New Entity") {
    AddEditEntityView()
        .modelContainer(DatabaseController.previewContainer())
}

#Preview("Edit Entity") {
    let container = DatabaseController.previewContainer()
    let entity = Entity(entityType: .person, canonicalName: "Alice Smith", notes: "Old friend from university.")
    container.mainContext.insert(entity)

    return AddEditEntityView(entity: entity)
        .modelContainer(container)
}
