import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context

    @State private var options: [String] = []
    @State private var input: String = ""
    @State private var picked: String?
    @State private var isPicking = false
    @State private var showSaveAsList = false
    @State private var newListName = ""
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // --- OPTIONS LIST (no TextField inside the List) ---
                List {
                    if options.isEmpty {
                        Section {
                            Text("No options yet. Add a few below, then tap Pick.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section("Options") {
                            ForEach(options, id: \.self) { o in
                                Text(o)
                            }
                            .onDelete(perform: delete)
                            .onMove(perform: move)
                        }
                    }
                }

                Divider()

                // --- INPUT COMPOSER (moved OUT of the List) ---
                HStack(spacing: 8) {
                    TextField("Add an option (e.g., Korean Food)", text: $input)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit { add() }

                    Button {
                        add()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)

                Divider()

                // --- ACTIONS / RESULT ---
                VStack(spacing: 12) {
                    Button(action: pickOne) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Pick One").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(options.count < 2)

                    if let picked {
                        Text("Result: \(picked)")
                            .font(.title3).bold()
                            .padding(.top, 4)
                            .transition(.scale.combined(with: .opacity))
                            .id(picked)
                    }

                    HStack {
                        Button {
                            showSaveAsList = true
                        } label: {
                            Label("Save as List", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(options.isEmpty)

                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Label("Clear", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }
            .navigationTitle("Decision Maker")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        DecisionSetListView()
                    } label: {
                        Label("Lists", systemImage: "list.bullet")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton().disabled(options.isEmpty)
                }
            }
            .confirmationDialog("Remove all options?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Remove All", role: .destructive) {
                    options.removeAll()
                    picked = nil
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Save as New List", isPresented: $showSaveAsList) {
                TextField("List name (e.g., Dinner Spots)", text: $newListName)
                Button("Save") { saveCurrentAsList() }
                    .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || options.isEmpty)
                Button("Cancel", role: .cancel) { newListName = "" }
            } message: {
                Text("You can manage saved lists from the Lists screen.")
            }
            .animation(.snappy, value: options.count)
            .animation(.snappy, value: picked)
        }
        // If you still see keyboard constraint logs, you can also hide the keyboard accessory bar:
        // .toolbar(.hidden, for: .keyboard)
    }

    // MARK: - Actions
    private func add() {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        options.append(t)
        input = ""
    }

    private func delete(at offsets: IndexSet) {
        options.remove(atOffsets: offsets)
    }

    private func move(from source: IndexSet, to destination: Int) {
        options.move(fromOffsets: source, toOffset: destination)
    }

    private func pickOne() {
        guard !isPicking, options.count >= 1 else { return }
        isPicking = true

        let rounds = min(12, max(6, options.count * 2))
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        Task {
            for i in 0..<rounds {
                try? await Task.sleep(nanoseconds: UInt64(80_000_000 + i * 8_000_000))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        picked = options.randomElement()
                    }
                    generator.impactOccurred(intensity: 0.6)
                }
            }
            let final = options.randomElement()!
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    picked = final
                }
                isPicking = false
            }
        }
    }

    private func saveCurrentAsList() {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !options.isEmpty else { return }
        let set = DecisionSet(name: name, choices: options.map { Choice(title: $0) })
        context.insert(set)
        try? context.save()
        newListName = ""
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DecisionSet.self, Choice.self, configurations: config)
    return HomeView().modelContainer(container)
}
