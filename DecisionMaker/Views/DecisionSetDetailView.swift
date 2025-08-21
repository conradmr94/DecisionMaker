import SwiftUI
import SwiftData

struct DecisionSetDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var set: DecisionSet

    // Input composer
    @State private var newChoiceText = ""

    // Result & interaction
    @State private var picked: String?
    @State private var isPicking = false

    // Learning knobs
    @State private var adventurousness: Double = 0.30   // 0=exploit, 1=explore
    @State private var recentPicks: [String] = []       // no-repeat queue
    private let recentLimit = 3

    // Modals
    @State private var showClearConfirm = false

    // SwiftData: persisted per-option stats and logs
    @Query(sort: \ChoicePref.title, order: .forward) private var prefs: [ChoicePref]
    @Query(sort: \ChoiceLog.decidedAt, order: .reverse) private var logs: [ChoiceLog]

    var body: some View {
        VStack(spacing: 0) {
            // --- LIST OF OPTIONS (no TextField here) ---
            List {
                if set.choices.isEmpty {
                    Section {
                        Text("No options yet. Add a few below, then tap Pick.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Options") {
                        ForEach(set.choices) { choice in
                            HStack {
                                Text(choice.title)
                                Spacer()
                                if let s = pref(for: choice.title) {
                                    let score = betaMean(success: s.success, failure: s.failure)
                                    Text(String(format: "★ %.2f", score))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteChoices)
                        // Reorder if you like:
                        // .onMove(perform: moveChoices)
                    }
                }
            }

            Divider()

            // --- INPUT COMPOSER (OUTSIDE LIST) ---
            HStack(spacing: 8) {
                TextField("Add an option (e.g., Sushi Bar)", text: $newChoiceText)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { addChoice() }

                Button {
                    addChoice()
                } label: {
                    Image(systemName: "plus.circle.fill").imageScale(.large)
                }
                .disabled(newChoiceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                .disabled(set.choices.count < 2)

                if let picked {
                    VStack(spacing: 8) {
                        Text("Result: \(picked)")
                            .font(.title3).bold()
                            .transition(.scale.combined(with: .opacity))
                            .id(picked)

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

                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Text("Clear All Options")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.bottom, 8)
            }
            .padding(.horizontal)
            .padding(.top, 6)
        }
        .navigationTitle(set.name)
        .confirmationDialog("Remove all options?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Remove All", role: .destructive) { clearAll() }
            Button("Cancel", role: .cancel) {}
        }
        .animation(.snappy, value: set.choices.count)
        .animation(.snappy, value: picked)
    }

    // MARK: - Actions
    private func addChoice() {
        let t = newChoiceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        set.choices.append(Choice(title: t))
        _ = pref(for: t, createIfMissing: true) // ensure stats row exists
        newChoiceText = ""
        try? context.save()
    }

    private func deleteChoices(at offsets: IndexSet) {
        for i in offsets {
            context.delete(set.choices[i])
        }
        set.choices.remove(atOffsets: offsets)
        try? context.save()
        if let p = picked, !set.choices.map(\.title).contains(p) {
            picked = nil
        }
    }

    private func clearAll() {
        for c in set.choices { context.delete(c) }
        set.choices.removeAll()
        picked = nil
        try? context.save()
    }

    private func pickOne() {
        guard !isPicking, !set.choices.isEmpty else { return }
        isPicking = true

        // Avoid immediate repeats
        let titles = set.choices.map(\.title)
        let avoid = Set(recentPicks)
        let candidates = titles.filter { !avoid.contains($0) }
        let pool = candidates.isEmpty ? titles : candidates

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
        // Log + reward
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

    // MARK: - Learning helpers (shared logic)
    private func pref(for title: String, createIfMissing: Bool = false) -> ChoicePref? {
        if let existing = prefs.first(where: { $0.title == title }) { return existing }
        guard createIfMissing else { return nil }
        let row = ChoicePref(title: title)
        context.insert(row)
        try? context.save()
        return row
    }

    private func smartPick(from pool: [String], adventure: Double) -> String? {
        guard !pool.isEmpty else { return nil }
        let scores = pool.map { t in
            if let p = pref(for: t) { return betaMean(success: p.success, failure: p.failure) }
            return 0.5
        }
        let tau = max(0.15, 0.55 - 0.45 * (1 - adventure)) // sharper when less adventurous
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
