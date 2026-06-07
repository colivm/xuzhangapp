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
            header
            helperText
            quickGenerateButton
            toggleButton
            expandedPackList
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(AppColors.lockGold.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(AppColors.lockGold.opacity(0.2), lineWidth: 1))
    }

    private var header: some View {
        HStack {
            Text(isPetMode ? "小宠物的记账小帮手" : "生活备注小帮手")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(recordInk.opacity(0.88))
            Spacer()
            Text("会员专属")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule(style: .continuous).fill(AppColors.lockGold))
        }
    }

    private var helperText: some View {
        let text = isExpanded ? "点选场景包会同步调整分类。" : "金额填好后，可自动补一句备注。"
        return Text(text)
            .font(.system(size: 12))
            .foregroundStyle(AppColors.subtext.opacity(0.88))
    }

    private var quickGenerateButton: some View {
        Button(action: onQuickGenerate) {
            HStack(spacing: 4) {
                Text("✨ 一键生成备注")
                    .font(.system(size: 14, weight: .semibold))
                Text("保留当前分类")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.subtext.opacity(0.7))
            }
            .scenePackButtonStyle(
                foreground: recordInk.opacity(0.88),
                fill: AppColors.accent.opacity(0.14),
                stroke: AppColors.accent.opacity(0.28),
                verticalPadding: 10
            )
        }
        .buttonStyle(.plain)
    }

    private var toggleButton: some View {
        let title = isExpanded ? "收起更多场景" : "展开更多场景"
        let subtitle = isExpanded ? "回到简洁输入" : "手动选择备注风格"
        return Button(action: onToggleExpanded) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.subtext.opacity(0.7))
            }
            .scenePackButtonStyle(
                foreground: recordInk.opacity(0.74),
                fill: Color.white.opacity(0.62),
                stroke: Color.white.opacity(0.5),
                verticalPadding: 9
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var expandedPackList: some View {
        if isExpanded {
            ForEach(scenePacks, id: \.id) { pack in
                scenePackButton(pack)
            }
        }
    }

    private func scenePackButton(_ pack: ScenePackDefinition) -> some View {
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
            .scenePackButtonStyle(
                foreground: recordInk.opacity(0.88),
                fill: Color.white.opacity(0.72),
                stroke: Color.white.opacity(0.5),
                verticalPadding: 10
            )
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func scenePackButtonStyle(
        foreground: Color,
        fill: Color,
        stroke: Color,
        verticalPadding: CGFloat
    ) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, verticalPadding)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
    }
}
