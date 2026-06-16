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
                intro: "这周已经有自己的节奏了，后面还可以继续回看。",
                quickAction: "继续回看周记",
                nudge: "想让每周都这样被整理出来？会员可无限回看周记和月记。"
            )
        case .shareSuccess:
            return MemberCtaCopy(
                intro: "这张周记摘页已经保存，连续生成会更有时间感。",
                quickAction: "继续生成生活摘页",
                nudge: "分享完成啦，会员可持续生成周记、月章和故事图。"
            )
        case .aiMonthly:
            return MemberCtaCopy(
                intro: "这个月已经能看出一点生活结构了，继续整理会更完整。",
                quickAction: "继续整理月记",
                nudge: "想继续回看更多月份？会员可解锁更多月记和生活回放。"
            )
        case .default:
            return MemberCtaCopy(
                intro: "适合已经开始连续记录的人。",
                quickAction: "立即开通年度会员（推荐）",
                nudge: "会员解锁不限 OCR、更多回放和持续生活总结。"
            )
        }
    }
}

