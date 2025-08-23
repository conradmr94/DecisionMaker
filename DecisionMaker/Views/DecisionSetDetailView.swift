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
                            if !set.choices.isEmpty {
                                Text("\(set.choices.count)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        if set.choices.isEmpty {
                            EmptyOptionsView()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(set.choices.enumerated()), id: \.element.id) { index, choice in
                                    ChoiceCard(
                                        choice: choice,
                                        index: index,
                                        score: {
                                            if let pref = pref(for: choice.title) {
                                                return SmartPicker.betaMean(success: pref.success, failure: pref.failure)
                                            }
                                            return nil
                                        }(),
                                        onDelete: { deleteChoices(at: IndexSet(integer: index)) }
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
                            TextField("Add an option (e.g., Sushi Bar)", text: $newChoiceText)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.done)
                                .onSubmit { addChoice() }
                            
                            Button { addChoice() } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                            }
                            .disabled(newChoiceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                        .disabled(set.choices.count < 2)
                        .scaleEffect(set.choices.count < 2 ? 0.95 : 1.0)
                        .opacity(set.choices.count < 2 ? 0.6 : 1.0)

                        // Clear Button
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                Text("Clear All Options")
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
        .navigationTitle(set.name)
        .navigationBarTitleDisplayMode(.large)
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

// MARK: - Options Section Component
struct OptionsSection: View {
    let choices: [Choice]
    let onDelete: (IndexSet) -> Void
    let pref: (String) -> ChoicePref?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title2)
                Text("Options")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                if !choices.isEmpty {
                    Text("\(choices.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue)
                        .clipShape(Capsule())
                }
            }
            
            if choices.isEmpty {
                EmptyOptionsView()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                        ChoiceCard(
                            choice: choice,
                            index: index,
                            score: {
                                if let pref = pref(choice.title) {
                                    return SmartPicker.betaMean(success: pref.success, failure: pref.failure)
                                }
                                return nil
                            }(),
                            onDelete: { onDelete(IndexSet(integer: index)) }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Empty Options View Component
struct EmptyOptionsView: View {
    var body: some View {
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
    }
}

// MARK: - Input Section Component
struct InputSection: View {
    @Binding var text: String
    let onAdd: () -> Void
    
    var body: some View {
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
                TextField("Add an option (e.g., Sushi Bar)", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { onAdd() }
                
                Button { onAdd() } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Adventure Slider Section Component
struct AdventureSliderSection: View {
    @Binding var adventurousness: Double
    
    var body: some View {
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
    }
}

// MARK: - Decision Section Component
struct DecisionSection: View {
    let choices: [Choice]
    @Binding var picked: String?
    let onPick: () -> Void
    let onAccept: (String) -> Void
    let onSkip: (String) -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            PickButton(
                choices: choices,
                onPick: onPick
            )
            
            if let picked = picked {
                ResultCard(
                    picked: picked,
                    onAccept: onAccept,
                    onSkip: onSkip
                )
            }
            
            ClearButton(onClear: onClear)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Pick Button Component
struct PickButton: View {
    let choices: [Choice]
    let onPick: () -> Void
    
    var body: some View {
        Button(action: onPick) {
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
        .disabled(choices.count < 2)
        .scaleEffect(choices.count < 2 ? 0.95 : 1.0)
        .opacity(choices.count < 2 ? 0.6 : 1.0)
    }
}

// MARK: - Result Card Component
struct ResultCard: View {
    let picked: String
    let onAccept: (String) -> Void
    let onSkip: (String) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
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
                    .fill(.ultraThinMaterial)
                    .stroke(.yellow.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: .yellow.opacity(0.2), radius: 12, x: 0, y: 6)

            HStack(spacing: 16) {
                Button { onAccept(picked) } label: {
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

                Button { onSkip(picked) } label: {
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
    }
}

// MARK: - Clear Button Component
struct ClearButton: View {
    let onClear: () -> Void
    
    var body: some View {
        Button(role: .destructive, action: onClear) {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("Clear All Options")
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

// MARK: - ChoiceCard Component
struct ChoiceCard: View {
    let choice: Choice
    let index: Int
    let score: Double?
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Choice number
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
            
            // Choice text
            Text(choice.title)
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
    return NavigationStack {
        DecisionSetDetailView(set: DecisionSet(name: "Sample List")).modelContainer(container)
    }
}
