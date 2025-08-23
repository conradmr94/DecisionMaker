import SwiftUI
import SwiftData

struct DecisionSetListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DecisionSet.name, order: .forward) private var sets: [DecisionSet]
    @State private var showingNewList = false
    @State private var newListName = ""
    @State private var isEditMode = false
    @State private var listToDelete: DecisionSet?
    @State private var showingEditMenu = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if sets.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.circle")
                            .font(.system(size: 64))
                            .foregroundStyle(.blue)
                        
                        VStack(spacing: 8) {
                            Text("No Lists Yet")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            
                            Text("Create a decision list (e.g., \"Dinner Spots\") and add options to get started.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button { showingNewList = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Your First List")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .padding(.horizontal, 20)
                } else {
                    // Lists Grid
                    LazyVStack(spacing: 16) {
                        ForEach(sets) { set in
                            DecisionSetCard(
                                set: set,
                                isEditMode: isEditMode,
                                onDelete: { listToDelete = set }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Lists")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !sets.isEmpty {
                    if isEditMode {
                        // Show checkmark button to exit edit mode
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditMode = false
                            }
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        }
                    } else {
                        // Show pencil button with menu for add/edit options
                        Menu {
                            Button {
                                showingNewList = true
                            } label: {
                                Label("Add New List", systemImage: "plus.circle")
                            }
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditMode = true
                                }
                            } label: {
                                Label("Edit Lists", systemImage: "pencil")
                            }
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                    }
                } else {
                    Button {
                        showingNewList = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .alert("New List", isPresented: $showingNewList) {
            TextField("e.g., Dinner Spots", text: $newListName)
            Button("Create") { createList() }
                .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) { newListName = "" }
        } message: {
            Text("Give your list a short name.")
        }
        .confirmationDialog(
            "Delete List",
            isPresented: .constant(listToDelete != nil),
            presenting: listToDelete
        ) { set in
            Button("Delete \"\(set.name)\"", role: .destructive) {
                deleteList(set)
            }
            Button("Cancel", role: .cancel) {
                listToDelete = nil
            }
        } message: { set in
            Text("This will permanently delete the list and all its options. This action cannot be undone.")
        }
    }

    private func createList() {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        context.insert(DecisionSet(name: name))
        try? context.save()
        newListName = ""
    }

    private func deleteList(_ set: DecisionSet) {
        context.delete(set)
        try? context.save()
        listToDelete = nil
    }
}

// MARK: - DecisionSetCard Component
struct DecisionSetCard: View {
    let set: DecisionSet
    let isEditMode: Bool
    let onDelete: () -> Void
    
    var body: some View {
        if isEditMode {
            // Edit mode: show delete button
            HStack(spacing: 16) {
                // Icon and count
                VStack(spacing: 4) {
                    Image(systemName: "list.bullet.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                    
                    Text("\(set.choices.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue)
                        .clipShape(Capsule())
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(set.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    if let last = set.lastPicked, !last.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Last: \(last)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .stroke(.quaternary, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .scaleEffect(0.98)
            .animation(.easeInOut(duration: 0.2), value: isEditMode)
        } else {
            // Normal mode: wrap entire card in NavigationLink
            NavigationLink(destination: DecisionSetDetailView(set: set)) {
                HStack(spacing: 16) {
                    // Icon and count
                    VStack(spacing: 4) {
                        Image(systemName: "list.bullet.circle.fill")
                            .font(.title)
                            .foregroundStyle(.blue)
                        
                        Text("\(set.choices.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue)
                            .clipShape(Capsule())
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 6) {
                        Text(set.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        if let last = set.lastPicked, !last.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Last: \(last)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Navigation arrow
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 0.2), value: isEditMode)
        }
    }
}

#Preview {
    let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: DecisionSet.self, Choice.self, ChoicePref.self, ChoiceLog.self,
        configurations: cfg
    )
    return NavigationStack {
        DecisionSetListView().modelContainer(container)
    }
}
