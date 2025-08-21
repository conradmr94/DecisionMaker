import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context

    // Ad-hoc options
    @State private var options: [String] = []
    @State private var input: String = ""

    // Result & interaction
    @State private var picked: String?
    @State private var isPicking = false

    // Save/clear flows
    @State private var showSaveAsList = false
    @State private var newListName = ""
    @State private var showClearConfirm = false

    // Smart picker knobs
    @State private var adventurousness: Double = 0.30   // 0=exploit, 1=explore
    @State private var recentPicks: [String] = []       // no-repeat queue
    private let recentLimit = 3

    // SwiftData stores
    @Query(sort: \ChoicePref.title, order: .forward) private var prefs: [ChoicePref]
    @Query(sort: \ChoiceLog.decidedAt, order: .reverse) private var logs: [ChoiceLog]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // LIST (no TextField inside)
                List {
                    if options.isEmpty {
                        Section {
                            Text("No options yet. Add a few below, then tap Pick.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section("Options") {
                            ForEach(options, id: \.self) { o in
                                HStack {
                                    Text(o)
                                    Spacer()
                                    if let s = pref(for: o) {
                                        let score = SmartPicker.betaMean(success: s.success, failure: s.failure)
                                        Text(String(format: "★ %.2f", score))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .onDelete(perform: delete)
                            .onMove(perform: move)
                        }
                    }
                }

                Divider()

                // INPUT COMPOSER
                HStack(spacing: 8) {
                    TextField("Add an option (e.g., Korean Food)", text: $input)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit { add() }
                    Button { add() } label: {
                        Image(systemName: "plus.circle.fill").imageScale(.large)
                    }
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)

                // ADVENTURE SLIDER
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Adventurousness").font(.subheadline).bold()
                        Spacer()
                        Text(SmartPicker.adventureLabel(adventurousness))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Slider(value: $adventurousness, in: 0...1, step: 0.05)
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // ACTIONS / RESULT / FEEDBACK
                VStack(spacing: 10) {
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
                        VStack(spacing: 8) {
                            Text("Result: \(picked)")
                                .font(.title3).bold().id(picked)
                                .transition(.scale.combined(with: .opacity))

                            HStack(spacing: 12) {
                                Button { acceptChoice(picked) } label: {
                                    Label("Accept Choice", systemImage: "checkmark.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)

                                Button { skipChoice(picked) } label: {
                                    Label("Another", systemImage: "arrow.triangle.2.circlepath")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    HStack {
                        Button { showSaveAsList = true } label: {
                            Label("Save as List", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(options.isEmpty)

                        Button(role: .destructive) { showClearConfirm = true } label: {
                            Label("Clear", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal)
                .padding(.top, 6)
            }
            .navigationTitle("Decision Maker")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { DecisionSetListView() } label: {
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
    }

    // MARK: - Actions
    private func add() {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        options.append(t)
        _ = pref(for: t, createIfMissing: true) // ensure stats row exists
        input = ""
    }

    private func delete(at offsets: IndexSet) {
        let removed = offsets.map { options[$0] }
        options.remove(atOffsets: offsets)
        if let p = picked, removed.contains(p) { picked = nil }
    }

    private func move(from source: IndexSet, to destination: Int) {
        options.move(fromOffsets: source, toOffset: destination)
    }

    private func pickOne() {
        guard !isPicking, !options.isEmpty else { return }
        isPicking = true

        // Avoid immediate repeats
        let avoid = Set(recentPicks)
        let candidates = options.filter { !avoid.contains($0) }
        let pool = candidates.isEmpty ? options : candidates

        let generator = UIImpactFeedbackGenerator(style: .light); generator.prepare()

        Task {
            let rounds = min(12, max(6, pool.count * 2))
            for i in 0..<rounds {
                try? await Task.sleep(nanoseconds: UInt64(80_000_000 + i * 8_000_000))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.1)) { picked = pool.randomElement() }
                    generator.impactOccurred(intensity: 0.6)
                }
            }

            let final = SmartPicker.pick(from: pool, adventure: adventurousness) { title in
                if let p = pref(for: title) {
                    return SmartPicker.betaMean(success: p.success, failure: p.failure)
                } else {
                    return 0.5
                }
            }
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { picked = final }
                if let final {
                    pushRecent(final)
                    if let p = pref(for: final) { p.lastUsed = Date(); try? context.save() }
                }
                isPicking = false
            }
        }
    }

    private func acceptChoice(_ title: String) {
        context.insert(ChoiceLog(title: title))
        if let p = pref(for: title, createIfMissing: true) {
            p.success += 1
            p.lastUsed = Date()
        }
        try? context.save()
        picked = nil
    }

    private func skipChoice(_ title: String) {
        if let p = pref(for: title, createIfMissing: true) {
            p.failure += 1
        }
        try? context.save()
        pushRecent(title)
        pickOne()
    }

    private func saveCurrentAsList() {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !options.isEmpty else { return }
        let set = DecisionSet(name: name, choices: options.map { Choice(title: $0) })
        context.insert(set)
        try? context.save()
        newListName = ""
    }

    // MARK: - Pref/helpers
    private func pref(for title: String, createIfMissing: Bool = false) -> ChoicePref? {
        if let existing = prefs.first(where: { $0.title == title }) { return existing }
        guard createIfMissing else { return nil }
        let row = ChoicePref(title: title)
        context.insert(row)
        try? context.save()
        return row
    }

    private func pushRecent(_ title: String) {
        recentPicks.removeAll(where: { $0 == title })
        recentPicks.append(title)
        if recentPicks.count > recentLimit {
            recentPicks.removeFirst(recentPicks.count - recentLimit)
        }
    }
}

#Preview {
    let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: DecisionSet.self, Choice.self, ChoicePref.self, ChoiceLog.self,
        configurations: cfg
    )
    return HomeView().modelContainer(container)
}
