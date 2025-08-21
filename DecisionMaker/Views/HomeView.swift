import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context

    // Ad-hoc options (not saved as lists)
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
    @State private var recentPicks: [String] = []        // no-repeat queue
    private let recentLimit = 3

    // SwiftData: persisted per-option stats and logs
    @Query(sort: \ChoicePref.title, order: .forward) private var prefs: [ChoicePref]
    @Query(sort: \ChoiceLog.decidedAt, order: .reverse) private var logs: [ChoiceLog]  // not shown yet, but handy

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // --- LIST OF CURRENT OPTIONS ---
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
                                        let score = betaMean(success: s.success, failure: s.failure)
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

                // --- INPUT COMPOSER (OUTSIDE LIST) ---
                HStack(spacing: 8) {
                    TextField("Add an option (e.g., Korean Food)", text: $input)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit { add() }

                    Button {
                        add()
                    } label: {
                        Image(systemName: "plus.circle.fill").imageScale(.large)
                    }
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)

                // --- ADVENTURE SLIDER ---
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Adventurousness")
                            .font(.subheadline).bold()
                        Spacer()
                        Text(adventureLabel(adventurousness))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $adventurousness, in: 0...1, step: 0.05)
                        .accessibilityLabel("Adventurousness")
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // --- ACTIONS / RESULT / FEEDBACK ---
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
                                .font(.title3).bold()
                                .transition(.scale.combined(with: .opacity))
                                .id(picked)

                            // Accept logs the choice + increments success.
                            // Another means “not this one now” → increments failure.
                            HStack(spacing: 12) {
                                Button {
                                    acceptChoice(picked)
                                } label: {
                                    Label("Accept Choice", systemImage: "checkmark.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    skipChoice(picked)
                                } label: {
                                    Label("Another", systemImage: "arrow.triangle.2.circlepath")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
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
                .padding(.top, 6)
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
        // .toolbar(.hidden, for: .keyboard) // enable if you still see keyboard constraint logs
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

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        Task {
            let rounds = min(12, max(6, pool.count * 2))
            for i in 0..<rounds {
                try? await Task.sleep(nanoseconds: UInt64(80_000_000 + i * 8_000_000))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        picked = pool.randomElement()
                    }
                    generator.impactOccurred(intensity: 0.6)
                }
            }

            let final = smartPick(from: pool, adventure: adventurousness)
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    picked = final
                }
                if let final {
                    pushRecent(final)
                    if let p = pref(for: final) {
                        p.lastUsed = Date()
                        try? context.save()
                    }
                }
                isPicking = false
            }
        }
    }

    private func acceptChoice(_ title: String) {
        // Log + reward the choice
        context.insert(ChoiceLog(title: title))
        if let p = pref(for: title, createIfMissing: true) {
            p.success += 1
            p.lastUsed = Date()
        }
        try? context.save()
        // Optional: clear current pick so user can start fresh
        picked = nil
    }

    private func skipChoice(_ title: String) {
        // Penalize the choice and immediately roll again
        if let p = pref(for: title, createIfMissing: true) {
            p.failure += 1
        }
        try? context.save()

        // Add to recent to avoid immediate re-suggest; re-pick
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

    // MARK: - Learning helpers
    private func pref(for title: String, createIfMissing: Bool = false) -> ChoicePref? {
        if let existing = prefs.first(where: { $0.title == title }) { return existing }
        guard createIfMissing else { return nil }
        let row = ChoicePref(title: title)
        context.insert(row)
        try? context.save()
        return row
    }

    // Preference-biased pick: Beta mean → softmax → mix with uniform by adventurousness
    private func smartPick(from pool: [String], adventure: Double) -> String? {
        guard !pool.isEmpty else { return nil }
        let scores = pool.map { t in
            if let p = pref(for: t) { return betaMean(success: p.success, failure: p.failure) }
            return 0.5
        }
        let tau = max(0.15, 0.55 - 0.45 * (1 - adventure)) // lower tau when less adventurous
        let prefProb = softmax(scores, temperature: tau)

        let n = Double(pool.count)
        let uniform = Array(repeating: 1.0 / n, count: pool.count)
        let mixed = zip(prefProb, uniform).map { (p, u) in max(1e-9, (1 - adventure) * p + adventure * u) }
        let norm = mixed.reduce(0, +)
        let probs = mixed.map { $0 / norm }
        let idx = categoricalSample(probs)
        return pool[idx]
    }

    private func betaMean(success: Int, failure: Int) -> Double {
        let a = Double(success + 1)
        let b = Double(failure + 1)
        return a / (a + b)
    }

    private func softmax(_ x: [Double], temperature tau: Double) -> [Double] {
        guard let maxX = x.max() else { return [] }
        let scaled = x.map { ($0 - maxX) / tau }
        let exps = scaled.map { exp($0) }
        let sum = exps.reduce(0, +)
        return exps.map { $0 / max(sum, 1e-12) }
    }

    private func categoricalSample(_ probs: [Double]) -> Int {
        let r = Double.random(in: 0..<1)
        var cum = 0.0
        for (i, p) in probs.enumerated() {
            cum += p
            if r < cum { return i }
        }
        return max(0, probs.count - 1)
    }

    private func pushRecent(_ title: String) {
        recentPicks.removeAll(where: { $0 == title })
        recentPicks.append(title)
        if recentPicks.count > recentLimit {
            recentPicks.removeFirst(recentPicks.count - recentLimit)
        }
    }

    private func adventureLabel(_ a: Double) -> String {
        switch a {
        case ..<0.05:  return "No Adventure"
        case ..<0.25:  return "Low"
        case ..<0.50:  return "Balanced-"
        case ..<0.75:  return "Balanced+"
        case ..<0.95:  return "High"
        default:        return "Surprise Me"
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: DecisionSet.self, Choice.self, ChoicePref.self, ChoiceLog.self,
        configurations: config
    )
    return HomeView().modelContainer(container)
}
