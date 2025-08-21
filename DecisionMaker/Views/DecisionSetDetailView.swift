import SwiftUI
import SwiftData

struct DecisionSetDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var set: DecisionSet

    @State private var newChoiceText = ""
    @State private var isPicking = false
    @State private var picked: String?
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    HStack {
                        TextField("Add an option (e.g., Sushi Bar)", text: $newChoiceText, onCommit: addChoice)
                            .textInputAutocapitalization(.words)
                        Button { addChoice() } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newChoiceText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if set.choices.isEmpty {
                    Section {
                        Text("No options yet. Add a few above, then tap Pick.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Options") {
                        ForEach(set.choices) { choice in
                            Text(choice.title)
                        }
                        .onDelete(perform: deleteChoices)
                    }
                }
            }

            Divider()

            VStack(spacing: 12) {
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
                    Text("Result: \(picked)")
                        .font(.title3).bold()
                        .padding(.top, 4)
                        .transition(.scale.combined(with: .opacity))
                        .id(picked)
                }

                if let last = set.lastPicked, !last.isEmpty {
                    Text("Last picked: \(last)")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Button(role: .destructive) { showClearConfirm = true } label: {
                    Text("Clear All Options").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.bottom, 8)
            }
            .padding()
        }
        .navigationTitle(set.name)
        .confirmationDialog("Remove all options?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Remove All", role: .destructive) { clearAll() }
            Button("Cancel", role: .cancel) {}
        }
        .animation(.snappy, value: set.choices.count)
        .animation(.snappy, value: picked)
    }

    // MARK: Actions
    private func addChoice() {
        let t = newChoiceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        set.choices.append(Choice(title: t))
        newChoiceText = ""
        try? context.save()
    }

    private func deleteChoices(at offsets: IndexSet) {
        for i in offsets { context.delete(set.choices[i]) }
        try? context.save()
    }

    private func clearAll() {
        for c in set.choices { context.delete(c) }
        set.choices.removeAll()
        picked = nil
        set.lastPicked = nil
        try? context.save()
    }

    private func pickOne() {
        guard !isPicking, set.choices.count >= 1 else { return }
        isPicking = true

        let rounds = min(12, max(6, set.choices.count * 2))
        var currentIndex = 0
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        Task {
            for i in 0..<rounds {
                try? await Task.sleep(nanoseconds: UInt64(80_000_000 + i * 8_000_000))
                currentIndex = Int.random(in: 0..<set.choices.count)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        picked = set.choices[currentIndex].title
                    }
                    generator.impactOccurred(intensity: 0.6)
                }
            }
            let final = set.choices.randomElement()!.title
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    picked = final
                }
                set.lastPicked = final
                try? context.save()
                isPicking = false
            }
        }
    }
}

