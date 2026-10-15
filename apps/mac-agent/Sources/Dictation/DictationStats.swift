import Foundation
import Observation

/// Counts for the dashboard. Never stores what was said: only word and dictation counts.
@MainActor
@Observable
final class DictationStats {
    private(set) var totalWords: Int
    private(set) var totalDictations: Int
    private(set) var todayWords: Int

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var todayKey: String

    private enum Keys {
        static let words = "stats.totalWords"
        static let dictations = "stats.totalDictations"
        static let todayWords = "stats.todayWords"
        static let today = "stats.today"
    }

    init() {
        totalWords = defaults.integer(forKey: Keys.words)
        totalDictations = defaults.integer(forKey: Keys.dictations)
        todayKey = Self.dayKey()
        todayWords = defaults.string(forKey: Keys.today) == todayKey ? defaults.integer(forKey: Keys.todayWords) : 0
    }

    func record(_ text: String) {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        guard words > 0 else { return }
        let key = Self.dayKey()
        if key != todayKey {
            todayKey = key
            todayWords = 0
        }
        totalWords += words
        totalDictations += 1
        todayWords += words
        defaults.set(totalWords, forKey: Keys.words)
        defaults.set(totalDictations, forKey: Keys.dictations)
        defaults.set(todayWords, forKey: Keys.todayWords)
        defaults.set(todayKey, forKey: Keys.today)
    }

    /// Typing at ~40 wpm versus speaking at ~150 wpm.
    var minutesSaved: Int {
        Int((Double(totalWords) / 40 - Double(totalWords) / 150).rounded())
    }

    private static func dayKey() -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
