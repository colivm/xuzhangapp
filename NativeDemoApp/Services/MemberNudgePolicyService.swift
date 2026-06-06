import Foundation

struct MemberNudgePolicy: Codable, Equatable {
    var prodDailyLimit: Int
    var prodSceneCooldownDays: Int

    static let `default` = MemberNudgePolicy(
        prodDailyLimit: 1,
        prodSceneCooldownDays: 7
    )
}

struct MemberNudgeState: Codable, Equatable {
    var lastShownAt: Date?
    var dailyDayKey: String
    var dailyCount: Int
    var sceneCooldownUntil: [String: Date]

    static let empty = MemberNudgeState(
        lastShownAt: nil,
        dailyDayKey: "",
        dailyCount: 0,
        sceneCooldownUntil: [:]
    )
}

final class MemberNudgePolicyService {
    private let policyKey = "ios_member_nudge_policy_v1"
    private let stateKey = "ios_member_nudge_state_v1"

    func loadPolicy() -> MemberNudgePolicy {
        guard let data = UserDefaults.standard.data(forKey: policyKey) else { return .default }
        return (try? JSONDecoder().decode(MemberNudgePolicy.self, from: data)) ?? .default
    }

    @discardableResult
    func savePolicy(_ policy: MemberNudgePolicy) -> MemberNudgePolicy {
        if let data = try? JSONEncoder().encode(policy) {
            UserDefaults.standard.set(data, forKey: policyKey)
        }
        return policy
    }

    func loadState() -> MemberNudgeState {
        guard let data = UserDefaults.standard.data(forKey: stateKey) else { return .empty }
        return (try? JSONDecoder().decode(MemberNudgeState.self, from: data)) ?? .empty
    }

    func resetState() {
        saveState(.empty)
    }

    func canShow(scene: String) -> Bool {
        let policy = loadPolicy()
        let state = loadState()
        let now = Date()
        let today = Self.dayKey(for: now)
        if state.dailyDayKey == today, state.dailyCount >= policy.prodDailyLimit { return false }
        if let until = state.sceneCooldownUntil[scene], until > now { return false }
        return true
    }

    func markShown(scene: String) {
        var state = loadState()
        let now = Date()
        state.lastShownAt = now
        let today = Self.dayKey(for: now)
        if state.dailyDayKey == today {
            state.dailyCount += 1
        } else {
            state.dailyDayKey = today
            state.dailyCount = 1
        }
        saveState(state)
    }

    func markDismissed(scene: String) {
        let policy = loadPolicy()
        var state = loadState()
        let cooldownDays = max(1, policy.prodSceneCooldownDays)
        state.sceneCooldownUntil[scene] = Calendar.current.date(byAdding: .day, value: cooldownDays, to: Date())
        saveState(state)
    }

    private func saveState(_ state: MemberNudgeState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: stateKey)
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

