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
    var automaticCooldownUntil: Date?

    static let empty = MemberNudgeState(
        lastShownAt: nil,
        dailyDayKey: "",
        dailyCount: 0,
        sceneCooldownUntil: [:],
        automaticCooldownUntil: nil
    )
}

enum MemberNudgePresentationSource: Equatable {
    case automatic
    case explicitUserAction
}

enum MemberNudgeEligibilityPolicy {
    static func canPresent(
        source: MemberNudgePresentationSource,
        scene: String,
        policy: MemberNudgePolicy,
        state: MemberNudgeState,
        now: Date
    ) -> Bool {
        if source == .explicitUserAction { return true }

        let today = MemberNudgePolicyService.dayKey(for: now)
        if state.dailyDayKey == today, state.dailyCount >= policy.prodDailyLimit { return false }
        if let until = state.automaticCooldownUntil, until > now { return false }
        if let until = state.sceneCooldownUntil[scene], until > now { return false }
        return true
    }
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

    func canShow(
        scene: String,
        source: MemberNudgePresentationSource = .automatic,
        now: Date = Date()
    ) -> Bool {
        let policy = loadPolicy()
        let state = loadState()
        return MemberNudgeEligibilityPolicy.canPresent(
            source: source,
            scene: scene,
            policy: policy,
            state: state,
            now: now
        )
    }

    func markShown(scene: String, now: Date = Date()) {
        var state = loadState()
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

    func markDismissed(scene: String, now: Date = Date()) {
        let policy = loadPolicy()
        var state = loadState()
        let cooldownDays = max(1, policy.prodSceneCooldownDays)
        let cooldownUntil = Calendar.current.date(byAdding: .day, value: cooldownDays, to: now)
        state.sceneCooldownUntil[scene] = cooldownUntil
        state.automaticCooldownUntil = cooldownUntil
        saveState(state)
    }

    private func saveState(_ state: MemberNudgeState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: stateKey)
    }

    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

