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
            ZStack {
                // Main content
                ScrollView {
                    VStack(spacing: 24) {
                        // Options Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "list.bullet.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.title2)
                                Text("Options")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                if !options.isEmpty {
                                    Text("\(options.count)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            if options.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.secondary)
                                    Text("No options yet")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                    Text("Add a few options below, then tap Pick One to make a decision")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .stroke(.quaternary, lineWidth: 1)
                                )
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(Array(options.enumerated()), id: \.element) { index, option in
                                        OptionCard(
                                            option: option,
                                            index: index,
                                            score: {
                                                if let pref = pref(for: option) {
                                                    return SmartPicker.betaMean(success: pref.success, failure: pref.failure)
                                                }
                                                return nil
                                            }(),
                                            onDelete: { delete(at: IndexSet(integer: index)) }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // Input Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title2)
                                Text("Add Option")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            HStack(spacing: 12) {
                                TextField("Add an option (e.g., Korean Food)", text: $input)
                                    .textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.words)
                                    .submitLabel(.done)
                                    .onSubmit { add() }
                                
                                Button { add() } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.green)
                                }
                                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Adventure Slider Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "dice.fill")
                                    .foregroundStyle(.orange)
                                    .font(.title2)
                                Text("Adventurousness")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                Text(SmartPicker.adventureLabel(adventurousness))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.orange.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Safe")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("Adventurous")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Slider(value: $adventurousness, in: 0...1, step: 0.05)
                                    .tint(.orange)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Decision Section
                        VStack(spacing: 16) {
                            Button(action: pickOne) {
                                HStack(spacing: 12) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.title2)
                                    Text("Pick One")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(options.count < 2)
                            .scaleEffect(options.count < 2 ? 0.95 : 1.0)
                            .opacity(options.count < 2 ? 0.6 : 1.0)

                            // Utility Buttons
                            HStack(spacing: 16) {
                                Button { showSaveAsList = true } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.and.arrow.down")
                                        Text("Save as List")
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(.ultraThinMaterial)
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(.quaternary, lineWidth: 1)
                                    )
                                }
                                .disabled(options.isEmpty)

                                Button(role: .destructive) { showClearConfirm = true } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "trash")
                                        Text("Clear All")
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(.red.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(.red.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
                .background(Color(.systemGroupedBackground))

                // Result Overlay - always visible when there's a result
                if let picked {
                    // Background overlay to shade out main content
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    // Result card in center
                    VStack(spacing: 16) {
                        // Result Card
                        VStack(spacing: 12) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.yellow)
                                .symbolEffect(.bounce, options: .repeating)
                            
                            Text("Your Decision")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Text(picked)
                                .font(.title)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .id(picked)
                                .transition(.scale.combined(with: .opacity))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.thickMaterial)
                                .stroke(.yellow.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: .yellow.opacity(0.2), radius: 12, x: 0, y: 6)

                        // Action Buttons
                        HStack(spacing: 16) {
                            Button { acceptChoice(picked) } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Accept")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button { skipChoice(picked) } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Try Again")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.orange)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationTitle("Decision Maker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { DecisionSetListView() } label: {
                        Label("Lists", systemImage: "list.bullet")
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .disabled(options.isEmpty)
                        .font(.headline)
                        .foregroundStyle(.blue)
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

// MARK: - OptionCard Component
struct OptionCard: View {
    let option: String
    let index: Int
    let score: Double?
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Option number
            Text("\(index + 1)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
            
            // Option text
            Text(option)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(2)
            
            Spacer()
            
            // Score badge
            if let score = score {
                VStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.2f", score))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(.red.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .stroke(.quaternary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
