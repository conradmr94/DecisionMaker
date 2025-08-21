import SwiftUI
import SwiftData

struct DecisionSetDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var set: DecisionSet

    @State private var newChoiceText = ""

    @State private var picked: String?
    @State private var isPicking = false

    @State private var adventurousness: Double = 0.30
    @State private var recentPicks: [String] = []
    private let recentLimit = 3

    @State private var showClearConfirm = false

    @Query(sort: \ChoicePref.title, order: .forward) private var prefs: [ChoicePref]
    @Query(sort: \ChoiceLog.decidedAt, order: .reverse) private var logs: [ChoiceLog]

    var body: some View {
        VStack(spacing: 0) {
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
                                    let score = SmartPicker.betaMean(success: s.success, failure: s.failure)
                                    Text(String(format: "★ %.2f", score))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteChoices)
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("Add an option (e.g., Sushi Bar)", text: $newChoiceText)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { addChoice() }
                Button { addChoice() } label: {
                    Image(systemName: "plus.circle.fill").imageScale(.large)
                }
                .disabled(newChoiceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

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

    // MARK: - Actions / helpers
    private func addChoice() {
        let t = newChoiceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        set.choices.append(Choice(title: t))
        _ = pref(for: t, createIfMissing: true)
        newChoiceText = ""
        try? context.save()
    }

    private func deleteChoices(at offsets: IndexSet) {
        for i in offsets { context.delete(set.choices[i]) }
        set.choices.remove(atOffsets: offsets)
        try? context.save()
        if let p = picked, !set.choices.map(\.title).contains(p) { picked = nil }
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

        let titles = set.choices.map(\.title)
        let avoid = Set(recentPicks)
        let candidates = titles.filter { !avoid.contains($0) }
        let pool = candidates.isEmpty ? titles : candidates

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
        if let p = pref(for: title, createIfMissing: true) { p.success += 1; p.lastUsed = Date() }
        try? context.save()
        picked = nil
    }

    private func skipChoice(_ title: String) {
        if let p = pref(for: title, createIfMissing: true) { p.failure += 1 }
        try? context.save()
        pushRecent(title)
        pickOne()
    }

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
