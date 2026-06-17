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
                intro: "这段生活已经被整理出来了，连续回看会更有时间感。",
                quickAction: "让回望继续留下",
                nudge: "会员可以持续整理周记和月章，不用刚听出节奏就停下来。"
            )
        case .shareSuccess:
            return MemberCtaCopy(
                intro: "这张摘页已经把一周留住了，连续生成会更像一本生活册。",
                quickAction: "继续留下生活摘页",
                nudge: "会员可持续生成周记、月章和故事图，让记录不只停在这一张。"
            )
        case .aiMonthly:
            return MemberCtaCopy(
                intro: "这个月已经能看出一点生活结构了，继续整理会更完整。",
                quickAction: "继续整理月章",
                nudge: "会员会把更多月份接着整理出来，帮你看见长期生活节奏。"
            )
        case .default:
            return MemberCtaCopy(
                intro: "适合已经开始连续记录的人。",
                quickAction: "让账本更懂我的生活",
                nudge: "会员让记录更连续、更懂场景，也不会在想整理时被次数打断。"
            )
        }
    }
}

