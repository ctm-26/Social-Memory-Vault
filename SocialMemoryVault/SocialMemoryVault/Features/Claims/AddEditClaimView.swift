import SwiftUI
import SwiftData

struct AddEditClaimView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let existingClaim: Claim?
    private let prefilledSubjectId: String?
    private let prefilledMemoryId: String?

    // MARK: - Subject
    @State private var subjectSearch: String = ""
    @State private var subjectResults: [Entity] = []
    @State private var selectedSubject: Entity? = nil
    @State private var subjectFieldFocused: Bool = false

    // MARK: - Predicate
    @State private var predicate: String = ""
    @State private var showPredicateSuggestions: Bool = false

    // MARK: - Object
    @State private var objectMode: ObjectMode = .literal
    @State private var objectSearch: String = ""
    @State private var objectResults: [Entity] = []
    @State private var selectedObjectEntity: Entity? = nil
    @State private var objectValue: String = ""
    @State private var objectFieldFocused: Bool = false

    // MARK: - Source Memory
    @State private var sourceMemoryId: String? = nil

    // MARK: - Validation
    @State private var validationErrors: [String] = []
    @State private var showValidationAlert: Bool = false

    // MARK: - Guard 1: Entity resolution on literal value field
    @State private var valueEntitySuggestion: Entity? = nil
    @State private var valueResolutionTask: Task<Void, Never>? = nil

    // MARK: - Guard 5: Source memory reminder on save
    @State private var showNoSourceWarning = false
    @State private var showMemoryPicker = false
    @State private var pendingCommitAfterMemoryPick = false

    @Query(sort: \Memory.createdAt, order: .reverse)
    private var allMemories: [Memory]

    enum ObjectMode: String, CaseIterable {
        case literal = "Literal Value"
        case entity = "Entity"
    }

    private static let commonPredicates: [String] = [
        "interested_in", "works_at", "owns", "lives_in", "knows",
        "friend_of", "uses_platform", "phone_number", "wants",
        "sibling_of", "is_into", "uses", "member_of"
    ]

    private var filteredPredicateSuggestions: [String] {
        if predicate.isEmpty { return Self.commonPredicates }
        return Self.commonPredicates.filter { $0.localizedCaseInsensitiveContains(predicate) }
    }

    private var isEditing: Bool { existingClaim != nil }
    private var navTitle: String { isEditing ? "Edit Claim" : "New Claim" }

    // MARK: - Inits

    /// New claim with optional prefills.
    init(subjectEntityId: String? = nil, memoryId: String? = nil) {
        self.existingClaim = nil
        self.prefilledSubjectId = subjectEntityId
        self.prefilledMemoryId = memoryId
    }

    /// Edit existing claim.
    init(claim: Claim) {
        self.existingClaim = claim
        self.prefilledSubjectId = nil
        self.prefilledMemoryId = nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Subject
                Section {
                    if let subject = selectedSubject {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(entityTypeColor(subject.entityTypeEnum).opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: subject.entityTypeEnum.systemImage)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(entityTypeColor(subject.entityTypeEnum))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(subject.canonicalName)
                                    .font(.subheadline.weight(.medium))
                                Text(subject.entityTypeEnum.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                selectedSubject = nil
                                subjectSearch = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                TextField("Search for an entity…", text: $subjectSearch)
                                    .autocorrectionDisabled()
                                    .onChange(of: subjectSearch) { _, v in
                                        subjectResults = EntityResolutionService.findMatches(for: v, in: modelContext)
                                    }
                            }
                        }
                    }
                } header: {
                    Text("Subject Entity")
                } footer: {
                    if selectedSubject == nil {
                        Text("Required. Who or what does this claim describe?")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                // Subject search results
                if !subjectResults.isEmpty && selectedSubject == nil {
                    Section {
                        ForEach(subjectResults) { entity in
                            Button {
                                selectedSubject = entity
                                subjectSearch = ""
                                subjectResults = []
                            } label: {
                                EntityPickerRow(entity: entity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // MARK: Predicate
                Section {
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("e.g. works_at, interested_in, owns…", text: $predicate)
                            .autocorrectionDisabled()
                            .autocapitalization(.none)
                            .onChange(of: predicate) { _, newValue in
                                showPredicateSuggestions = !newValue.isEmpty

                                // Guard 2: Predicate-aware field selection
                                let classification = PredicateClassificationService.classify(newValue)
                                switch classification {
                                case .entity:
                                    if objectValue.isEmpty && selectedObjectEntity == nil {
                                        objectMode = .entity
                                        valueEntitySuggestion = nil
                                    }
                                case .literal:
                                    if selectedObjectEntity == nil {
                                        objectMode = .literal
                                    }
                                case .unknown:
                                    break
                                }
                            }

                        if showPredicateSuggestions && !filteredPredicateSuggestions.isEmpty {
                            Divider().padding(.top, 8)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(filteredPredicateSuggestions, id: \.self) { suggestion in
                                        Button {
                                            predicate = suggestion
                                            showPredicateSuggestions = false
                                        } label: {
                                            Text(suggestion)
                                                .font(.caption.weight(.medium))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                                .foregroundStyle(.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                            }
                        }
                    }
                } header: {
                    Text("Predicate")
                } footer: {
                    Text("A verb-like label describing the relationship or attribute.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                // MARK: Object
                Section {
                    Picker("Object Type", selection: $objectMode) {
                        ForEach(ObjectMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                    .onChange(of: objectMode) { _, newMode in
                        if newMode == .entity {
                            valueEntitySuggestion = nil
                        }
                    }

                    if objectMode == .literal {
                        TextField("Value (e.g. a name, number, description)", text: $objectValue)
                            .autocorrectionDisabled()
                            .onChange(of: objectValue) { _, newValue in
                                // Guard 1: Entity resolution on literal value field
                                valueResolutionTask?.cancel()
                                if newValue.isEmpty {
                                    valueEntitySuggestion = nil
                                    return
                                }
                                guard newValue.count >= 2, selectedObjectEntity == nil else { return }
                                valueResolutionTask = Task {
                                    try? await Task.sleep(nanoseconds: 300_000_000)
                                    guard !Task.isCancelled else { return }
                                    let match = EntityResolutionService.findExactMatch(for: newValue, in: modelContext)
                                    await MainActor.run {
                                        valueEntitySuggestion = match
                                    }
                                }
                            }

                        // Guard 1: Inline suggestion banner
                        if let suggestion = valueEntitySuggestion,
                           selectedObjectEntity == nil,
                           objectMode == .literal {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundStyle(.accentColor)
                                        .font(.subheadline)
                                    Text("\"\(suggestion.canonicalName)\" already exists as a \(suggestion.entityTypeEnum.displayName). Link as entity instead of literal value?")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                HStack(spacing: 10) {
                                    Button("Link as entity") {
                                        objectMode = .entity
                                        selectedObjectEntity = suggestion
                                        objectValue = ""
                                        valueEntitySuggestion = nil
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)

                                    Button("Keep as text") {
                                        valueEntitySuggestion = nil
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        if let objectEntity = selectedObjectEntity {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(entityTypeColor(objectEntity.entityTypeEnum).opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: objectEntity.entityTypeEnum.systemImage)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(entityTypeColor(objectEntity.entityTypeEnum))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(objectEntity.canonicalName)
                                        .font(.subheadline.weight(.medium))
                                    Text(objectEntity.entityTypeEnum.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    selectedObjectEntity = nil
                                    objectSearch = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        } else {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                TextField("Search for object entity…", text: $objectSearch)
                                    .autocorrectionDisabled()
                                    .onChange(of: objectSearch) { _, v in
                                        objectResults = EntityResolutionService.findMatches(for: v, in: modelContext)
                                    }
                            }
                        }
                    }
                } header: {
                    Text("Object")
                } footer: {
                    Text("The value or entity that the predicate points to.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                // Object entity search results
                if objectMode == .entity && !objectResults.isEmpty && selectedObjectEntity == nil {
                    Section {
                        ForEach(objectResults) { entity in
                            Button {
                                selectedObjectEntity = entity
                                objectSearch = ""
                                objectResults = []
                            } label: {
                                EntityPickerRow(entity: entity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // MARK: Source Memory
                Section {
                    Picker("Source Memory", selection: $sourceMemoryId) {
                        Text("None").tag(String?.none)
                        ForEach(allMemories) { memory in
                            Text(memory.body.prefix(60))
                                .lineLimit(1)
                                .tag(Optional(memory.id))
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Source Memory")
                } footer: {
                    Text("Optional. Link this claim to a memory where it was recorded.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Cannot Save", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationErrors.joined(separator: "\n"))
            }
            .confirmationDialog("No Source Memory", isPresented: $showNoSourceWarning, titleVisibility: .visible) {
                Button("Attach Memory") {
                    showMemoryPicker = true
                }
                Button("Save Without Source") {
                    commitSave()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This claim has no source memory. Claims with evidence are easier to verify later. Attach one?")
            }
            .sheet(isPresented: $showMemoryPicker) {
                MemoryPickerView(
                    subjectEntityId: selectedSubject?.id,
                    sourceMemoryId: $sourceMemoryId,
                    onSelect: { commitSave() }
                )
            }
            .onAppear { prefill() }
        }
    }

    // MARK: - Logic

    private func prefill() {
        if let existing = existingClaim {
            predicate = existing.predicate
            objectValue = existing.value ?? ""
            sourceMemoryId = existing.memoryId
            if let oid = existing.objectEntityId {
                selectedObjectEntity = EntityResolutionService.findEntity(byId: oid, in: modelContext)
                objectMode = .entity
            }
            selectedSubject = EntityResolutionService.findEntity(byId: existing.subjectEntityId, in: modelContext)
        } else {
            if let sid = prefilledSubjectId {
                selectedSubject = EntityResolutionService.findEntity(byId: sid, in: modelContext)
            }
            sourceMemoryId = prefilledMemoryId
        }
    }

    private func save() {
        let subjectId = selectedSubject?.id ?? ""
        let objectEntityId = objectMode == .entity ? selectedObjectEntity?.id : nil
        let literalValue = objectMode == .literal
            ? (objectValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : objectValue.trimmingCharacters(in: .whitespacesAndNewlines))
            : nil

        let errors = Validation.validateClaim(
            subjectEntityId: subjectId,
            predicate: predicate.trimmingCharacters(in: .whitespacesAndNewlines),
            objectEntityId: objectEntityId,
            value: literalValue
        )

        guard errors.isEmpty else {
            validationErrors = errors
            showValidationAlert = true
            return
        }

        // Guard 5: Source memory reminder
        if sourceMemoryId == nil && prefilledMemoryId == nil {
            showNoSourceWarning = true
            return
        }

        commitSave()
    }

    private func commitSave() {
        let subjectId = selectedSubject?.id ?? ""
        let objectEntityId = objectMode == .entity ? selectedObjectEntity?.id : nil
        let literalValue = objectMode == .literal
            ? (objectValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : objectValue.trimmingCharacters(in: .whitespacesAndNewlines))
            : nil

        if let existing = existingClaim {
            existing.subjectEntityId = subjectId
            existing.predicate = predicate.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.objectEntityId = objectEntityId
            existing.value = literalValue
            existing.memoryId = sourceMemoryId
            existing.updatedAt = Date()
        } else {
            let claim = Claim(
                subjectEntityId: subjectId,
                predicate: predicate.trimmingCharacters(in: .whitespacesAndNewlines),
                objectEntityId: objectEntityId,
                value: literalValue,
                memoryId: sourceMemoryId
            )
            modelContext.insert(claim)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Sub-views

private struct EntityPickerRow: View {
    let entity: Entity

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(entityTypeColor(entity.entityTypeEnum).opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: entity.entityTypeEnum.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(entityTypeColor(entity.entityTypeEnum))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(entity.canonicalName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(entity.entityTypeEnum.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "plus.circle")
                .foregroundStyle(.accentColor)
                .font(.subheadline)
        }
        .contentShape(Rectangle())
    }
}

private struct MemoryPickerView: View {
    let subjectEntityId: String?
    @Binding var sourceMemoryId: String?
    let onSelect: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Memory.createdAt, order: .reverse) private var allMemories: [Memory]
    @Query private var allLinks: [MemoryEntityLink]

    private var filteredMemories: [Memory] {
        guard let sid = subjectEntityId else { return Array(allMemories.prefix(30)) }
        let linkedMemoryIds = Set(allLinks.filter { $0.entityId == sid }.map { $0.memoryId })
        return allMemories.filter { linkedMemoryIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List(filteredMemories) { memory in
                Button {
                    sourceMemoryId = memory.id
                    dismiss()
                    onSelect()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(memory.body)
                            .font(.subheadline)
                            .lineLimit(3)
                            .foregroundStyle(.primary)
                        Text(DateUtils.display(memory.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("New Claim") {
    AddEditClaimView()
        .modelContainer(DatabaseController.previewContainer())
}
