import Foundation

enum AIUsageLimiter {
    private static let monthKey = "ai_usage_month_key"
    private static let countKey = "ai_usage_count_key"

    static func canUseRemoteAI(limitPerMonth: Int) -> Bool {
        guard limitPerMonth > 0 else { return true }
        resetIfNeeded()
        return currentCount() < limitPerMonth
    }

    static func consumeOnce(limitPerMonth: Int) -> Bool {
        guard limitPerMonth > 0 else { return true }
        resetIfNeeded()
        let count = currentCount()
        guard count < limitPerMonth else { return false }
        UserDefaults.standard.set(count + 1, forKey: countKey)
        return true
    }

    static func usageText(limitPerMonth: Int) -> String {
        resetIfNeeded()
        return "\(currentCount())/\(max(limitPerMonth, 0))"
    }

    private static func resetIfNeeded() {
        let currentMonth = monthIdentifier()
        let storedMonth = UserDefaults.standard.string(forKey: monthKey)
        if storedMonth != currentMonth {
            UserDefaults.standard.set(currentMonth, forKey: monthKey)
            UserDefaults.standard.set(0, forKey: countKey)
        }
    }

    private static func currentCount() -> Int {
        UserDefaults.standard.integer(forKey: countKey)
    }

    private static func monthIdentifier() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: .now)
    }
}
