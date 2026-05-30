import Foundation

enum MemberFlowScene: String, Codable {
    case `default`
    case playbackComplete = "playback_complete"
    case shareSuccess = "share_success"
    case aiMonthly = "ai_monthly"
}

struct MemberCtaCopy: Codable, Equatable {
    let intro: String
    let quickAction: String
    let nudge: String
}

final class MemberFlowService {
    func ctaCopy(scene: MemberFlowScene) -> MemberCtaCopy {
        switch scene {
        case .playbackComplete:
            return MemberCtaCopy(
                intro: "把这周的生活轨迹长期留住，回看会更温柔。",
                quickAction: "保留这周生活轨迹",
                nudge: "想把这些生活切片长期留住？开通会员可自动云端留存。"
            )
        case .shareSuccess:
            return MemberCtaCopy(
                intro: "这张分享卡很温柔，继续留存每周生活卡会更有连续感。",
                quickAction: "持续留存每周生活卡",
                nudge: "分享完成啦，开通会员可持续留存每周生活卡。"
            )
        case .aiMonthly:
            return MemberCtaCopy(
                intro: "这次复盘只是开始，会员可解锁无限次生活复盘。",
                quickAction: "解锁无限次生活复盘",
                nudge: "想继续回看更多生活节奏？会员可解锁无限次复盘。"
            )
        case .default:
            return MemberCtaCopy(
                intro: "让记账更轻松、更省心。",
                quickAction: "立即开通年度会员（推荐）",
                nudge: "开通会员可持续留存生活记录，随时温柔回看。"
            )
        }
    }
}

