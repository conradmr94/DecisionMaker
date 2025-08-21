import Foundation

enum SmartPicker {

    // Public API: pick a title from pool using preference scores and an adventurousness knob [0,1].
    static func pick(
        from pool: [String],
        adventure: Double,
        score: (String) -> Double   // e.g., Beta mean from your stats store
    ) -> String? {
        guard !pool.isEmpty else { return nil }
        let scores = pool.map(score)

        // Lower temperature when less adventurous → more peaky on favorites.
        let tau = max(0.15, 0.55 - 0.45 * (1 - adventure))
        let prefProb = softmax(scores, temperature: tau)

        // Mix preference with uniform randomness by adventurousness.
        let mixed = mixWithUniform(prefProb, weight: adventure)
        let idx = sampleCategorical(mixed)
        return pool[idx]
    }

    static func adventureLabel(_ a: Double) -> String {
        switch a {
        case ..<0.05:  return "No Adventure"
        case ..<0.25:  return "Low"
        case ..<0.50:  return "Balanced-"
        case ..<0.75:  return "Balanced+"
        case ..<0.95:  return "High"
        default:        return "Surprise Me"
        }
    }

    // MARK: - Scoring helpers (Beta mean for successes/failures)
    static func betaMean(success: Int, failure: Int) -> Double {
        let a = Double(success + 1)
        let b = Double(failure + 1)
        return a / (a + b)
    }

    // MARK: - Internals
    private static func softmax(_ x: [Double], temperature tau: Double) -> [Double] {
        guard let maxX = x.max() else { return [] }
        let scaled = x.map { ($0 - maxX) / tau }
        let exps = scaled.map { exp($0) }
        let sum = exps.reduce(0, +)
        return exps.map { $0 / max(sum, 1e-12) }
    }

    private static func mixWithUniform(_ probs: [Double], weight w: Double) -> [Double] {
        guard !probs.isEmpty else { return [] }
        let n = Double(probs.count)
        let uniform = 1.0 / n
        let mixed = probs.map { max(1e-9, (1 - w) * $0 + w * uniform) }
        let s = mixed.reduce(0, +)
        return mixed.map { $0 / s }
    }

    private static func sampleCategorical(_ probs: [Double]) -> Int {
        let r = Double.random(in: 0..<1)
        var cum = 0.0
        for (i, p) in probs.enumerated() {
            cum += p
            if r < cum { return i }
        }
        return probs.count - 1
    }
}
