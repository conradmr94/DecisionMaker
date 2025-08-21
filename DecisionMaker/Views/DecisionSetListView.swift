import SwiftUI
import SwiftData

struct DecisionSetListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DecisionSet.name, order: .forward) private var sets: [DecisionSet]
    @State private var showingNewList = false
    @State private var newListName = ""

    var body: some View {
        Group {
            if sets.isEmpty {
                ContentUnavailableView(
                    "No Lists Yet",
                    systemImage: "list.bullet",
                    description: Text("Create a decision list (e.g., “Dinner Spots”) and add options.")
                )
            } else {
                List {
                    ForEach(sets) { set in
                        NavigationLink(destination: DecisionSetDetailView(set: set)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(set.name).font(.headline)
                                    Text("\(set.choices.count) option\(set.choices.count == 1 ? "" : "s")")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let last = set.lastPicked, !last.isEmpty {
                                    Text("Last: \(last)")
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Lists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNewList = true } label: {
                    Label("New List", systemImage: "plus")
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
    }

    private func createList() {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        context.insert(DecisionSet(name: name))
        try? context.save()
        newListName = ""
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(sets[i]) }
        try? context.save()
    }
}
