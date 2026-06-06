import SwiftUI

struct ScenePackSectionView: View {
    let scenePacks: [ScenePackDefinition]
    let isExpanded: Bool
    let isPetMode: Bool
    let recordInk: Color
    let onQuickGenerate: () -> Void
    let onToggleExpanded: () -> Void
    let onSelectPack: (ScenePackDefinition) -> Void
    let scenePackDesc: (ScenePackDefinition) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(isPetMode ? "小宠物的记账小帮手" : "生活备注小帮手")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(recordInk.opacity(0.88))
                Spacer()
                Text("会员专属")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(AppColors.lockGold))
            }
            Text(isExpanded
                 ? "点选场景包会同步调整分类。"
                 : "金额填好后，可自动补一句备注。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.88))

            Button {
                onQuickGenerate()
            } label: {
                HStack(spacing: 4) {
                    Text("✨ 一键生成备注")
                        .font(.system(size: 14, weight: .semibold))
                    Text("保留当前分类")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.subtext.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.accent.opacity(0.14)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.accent.opacity(0.28), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                onToggleExpanded()
            } label: {
                HStack {
                    Text(isExpanded ? "收起更多场景" : "展开更多场景")
                        .font(.system(size: 13))
                    Text(isExpanded ? "回到简洁输入" : "手动选择备注风格")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.subtext.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(recordInk.opacity(0.74))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.62)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(scenePacks, id: \.id) { pack in
                    Button {
                        onSelectPack(pack)
                    } label: {
                        HStack {
                            Text("\(pack.emoji) \(pack.label)")
                                .font(.system(size: 14, weight: .medium))
                            Text(scenePackDesc(pack))
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.subtext.opacity(0.7))
                                .lineLimit(1)
                            Spacer()
                        }
                        .foregroundStyle(recordInk.opacity(0.88))
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.72)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(AppColors.lockGold.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(AppColors.lockGold.opacity(0.2), lineWidth: 1))
    }
}
