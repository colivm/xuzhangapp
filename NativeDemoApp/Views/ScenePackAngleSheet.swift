import SwiftUI
import UIKit

struct ScenePackAngleSheet: View {
    private enum Mode {
        case member(MemberConfiguration)
        case free(FreeConfiguration)
    }

    private struct MemberConfiguration {
        let primaryScenePacks: [ScenePackDefinition]
        let secondaryScenePacks: [ScenePackDefinition]
        let isMoreExpanded: Binding<Bool>
        let scenePackDesc: (ScenePackDefinition) -> String
        let onReorderPacks: (_ orderedPackIds: [String], _ movedPackIds: Set<String>) -> Void
        let onSelectPack: (ScenePackDefinition) -> Void
    }

    private struct FreeConfiguration {
        let freeScenePacks: [ScenePackDefinition]
        let moreScenePacks: [ScenePackDefinition]
        let replaceableScenePacks: [ScenePackDefinition]
        let lockedSceneHint: LockedSceneHint?
        let isInFirstWeek: Bool
        let canReplacePackCombination: Bool
        let daysUntilNextReplace: Int
        let scenePackDesc: (ScenePackDefinition) -> String
        let isExtensionLockedPack: (ScenePackDefinition) -> Bool
        let onReorderFreePacks: (_ orderedPackIds: [String]) -> Void
        let onSelectFreePack: (ScenePackDefinition) -> Void
        let onReplaceFreePack: (_ slot: Int, _ oldId: String, _ newPack: ScenePackDefinition) -> Void
        let onShowMemberPricing: () -> Void
    }

    struct LockedSceneHint {
        let pack: ScenePackDefinition
        let title: String
        let detail: String
    }

    private struct PendingReplacement: Identifiable {
        let id = UUID()
        let slot: Int
        let oldId: String
        let newPack: ScenePackDefinition
    }

    private let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPackID: String?
    @State private var isReplacingPack = false
    @State private var selectedReplaceSlot: Int?
    @State private var pendingReplacement: PendingReplacement?

    init(
        primaryScenePacks: [ScenePackDefinition],
        secondaryScenePacks: [ScenePackDefinition],
        isMoreExpanded: Binding<Bool>,
        scenePackDesc: @escaping (ScenePackDefinition) -> String,
        onReorderPacks: @escaping (_ orderedPackIds: [String], _ movedPackIds: Set<String>) -> Void,
        onSelectPack: @escaping (ScenePackDefinition) -> Void
    ) {
        mode = .member(
            MemberConfiguration(
                primaryScenePacks: primaryScenePacks,
                secondaryScenePacks: secondaryScenePacks,
                isMoreExpanded: isMoreExpanded,
                scenePackDesc: scenePackDesc,
                onReorderPacks: onReorderPacks,
                onSelectPack: onSelectPack
            )
        )
    }

    init(
        freeScenePacks: [ScenePackDefinition],
        moreScenePacks: [ScenePackDefinition],
        replaceableScenePacks: [ScenePackDefinition],
        lockedSceneHint: LockedSceneHint? = nil,
        isInFirstWeek: Bool,
        canReplacePackCombination: Bool,
        daysUntilNextReplace: Int,
        scenePackDesc: @escaping (ScenePackDefinition) -> String,
        isExtensionLockedPack: @escaping (ScenePackDefinition) -> Bool,
        onReorderFreePacks: @escaping (_ orderedPackIds: [String]) -> Void,
        onSelectFreePack: @escaping (ScenePackDefinition) -> Void,
        onReplaceFreePack: @escaping (_ slot: Int, _ oldId: String, _ newPack: ScenePackDefinition) -> Void,
        onShowMemberPricing: @escaping () -> Void
    ) {
        mode = .free(
            FreeConfiguration(
                freeScenePacks: freeScenePacks,
                moreScenePacks: moreScenePacks,
                replaceableScenePacks: replaceableScenePacks,
                lockedSceneHint: lockedSceneHint,
                isInFirstWeek: isInFirstWeek,
                canReplacePackCombination: canReplacePackCombination,
                daysUntilNextReplace: daysUntilNextReplace,
                scenePackDesc: scenePackDesc,
                isExtensionLockedPack: isExtensionLockedPack,
                onReorderFreePacks: onReorderFreePacks,
                onSelectFreePack: onSelectFreePack,
                onReplaceFreePack: onReplaceFreePack,
                onShowMemberPricing: onShowMemberPricing
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                switch mode {
                case .member(let configuration):
                    memberContent(configuration)
                case .free(let configuration):
                    freeContent(configuration)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("换个角度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .alert(item: $pendingReplacement) { replacement in
            Alert(
                title: Text("替换角度"),
                message: Text("确定替换？替换后 30 天内不可再换。"),
                primaryButton: .cancel(Text("再想想")),
                secondaryButton: .default(Text("确定替换")) {
                    confirmReplacement(replacement)
                }
            )
        }
    }

    @ViewBuilder
    private func memberContent(_ configuration: MemberConfiguration) -> some View {
        Section {
            reorderHint
        }

        Section("场景包") {
            ForEach(memberDisplayedScenePacks(configuration), id: \.id) { pack in
                memberPackRow(pack, configuration: configuration)
            }
            .onMove { source, destination in
                reorderMemberPacks(from: source, to: destination, configuration: configuration)
            }

            if !configuration.secondaryScenePacks.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        configuration.isMoreExpanded.wrappedValue.toggle()
                    }
                } label: {
                    HStack {
                        Text(configuration.isMoreExpanded.wrappedValue ? "收起未常用场景" : "展开未常用场景")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.text)
                        Text("\(configuration.secondaryScenePacks.count) 个未用或静默")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.subtext)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: configuration.isMoreExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppColors.subtext)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func freeContent(_ configuration: FreeConfiguration) -> some View {
        if isReplacingPack {
            replacementContent(configuration)
        } else {
            if let hint = configuration.lockedSceneHint {
                Section {
                    lockedSceneHintRow(hint, configuration: configuration)
                }
            }

            if configuration.isInFirstWeek {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.accent.opacity(0.78))
                        Text("首周可随意替换角度；首周结束后，每次替换会冷却 30 天")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.text.opacity(0.78))
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }

            Section {
                reorderHint
            }

            Section("我的 3 个角度") {
                ForEach(configuration.freeScenePacks, id: \.id) { pack in
                    freeSelectablePackRow(pack, configuration: configuration)
                }
                .onMove { source, destination in
                    reorderFreePacks(from: source, to: destination, configuration: configuration)
                }
            }

            if !configuration.moreScenePacks.isEmpty {
                Section("更多角度") {
                    ForEach(configuration.moreScenePacks, id: \.id) { pack in
                        morePackRow(pack, configuration: configuration)
                    }
                }
            }

            Section {
                replaceButton(configuration)
            } footer: {
                if configuration.isInFirstWeek {
                    Text("现在替换不会进入冷却。首周结束后，免费版每 30 天可换一次。")
                } else if configuration.canReplacePackCombination {
                    Text("替换后 30 天可再换 · 会员可随时用全部角度")
                } else {
                    Text("距离下次可替换还有 \(configuration.daysUntilNextReplace) 天")
                }
            }
        }
    }

    @ViewBuilder
    private func replacementContent(_ configuration: FreeConfiguration) -> some View {
        Section("选择要替换的角度") {
            ForEach(Array(configuration.freeScenePacks.enumerated()), id: \.element.id) { index, pack in
                replacementSlotRow(pack, slot: index)
            }
        }

        if selectedReplaceSlot != nil {
            Section("选择新的角度") {
                if configuration.replaceableScenePacks.isEmpty {
                    Text("暂无可替换的基础角度")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.subtext)
                } else {
                    ForEach(configuration.replaceableScenePacks, id: \.id) { pack in
                        replacementCandidateRow(pack, configuration: configuration)
                    }
                }
            }
        }

        Section {
            Button("取消替换") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isReplacingPack = false
                    selectedReplaceSlot = nil
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppColors.subtext)
        }
    }

    private var reorderHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.accent.opacity(0.82))
            Text("长按右侧拖动可调换顺序")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func memberDisplayedScenePacks(_ configuration: MemberConfiguration) -> [ScenePackDefinition] {
        configuration.isMoreExpanded.wrappedValue
            ? configuration.primaryScenePacks + configuration.secondaryScenePacks
            : configuration.primaryScenePacks
    }

    private func reorderMemberPacks(
        from source: IndexSet,
        to destination: Int,
        configuration: MemberConfiguration
    ) {
        let currentPacks = memberDisplayedScenePacks(configuration)
        let movedPackIds = Set(source.compactMap { index in
            currentPacks.indices.contains(index) ? currentPacks[index].id : nil
        })
        var reorderedPacks = currentPacks
        reorderedPacks.move(fromOffsets: source, toOffset: destination)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        configuration.onReorderPacks(reorderedPacks.map(\.id), movedPackIds)
    }

    private func reorderFreePacks(
        from source: IndexSet,
        to destination: Int,
        configuration: FreeConfiguration
    ) {
        var reorderedPacks = configuration.freeScenePacks
        reorderedPacks.move(fromOffsets: source, toOffset: destination)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        configuration.onReorderFreePacks(reorderedPacks.map(\.id))
    }

    private func memberPackRow(
        _ pack: ScenePackDefinition,
        configuration: MemberConfiguration
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.12)) {
                selectedPackID = pack.id
            }
            configuration.onSelectPack(pack)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                dismiss()
            }
        } label: {
            packRowContent(pack, subtitle: configuration.scenePackDesc(pack), isSelected: selectedPackID == pack.id)
        }
        .buttonStyle(.plain)
    }

    private func freeSelectablePackRow(
        _ pack: ScenePackDefinition,
        configuration: FreeConfiguration
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.12)) {
                selectedPackID = pack.id
            }
            configuration.onSelectFreePack(pack)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                dismiss()
            }
        } label: {
            packRowContent(pack, subtitle: configuration.scenePackDesc(pack), isSelected: selectedPackID == pack.id)
        }
        .buttonStyle(.plain)
    }

    private func morePackRow(
        _ pack: ScenePackDefinition,
        configuration: FreeConfiguration
    ) -> some View {
        let isLocked = isLockedMorePack(pack, configuration: configuration)
        return Button {
            if isLocked {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    configuration.onShowMemberPricing()
                }
            } else {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isReplacingPack = true
                }
            }
        } label: {
            HStack(spacing: 12) {
                Text(pack.emoji)
                    .font(.system(size: 22))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                    Text(isLocked ? lockedPackSubtitle(for: pack) : "可替换到我的 3 个角度")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isLocked ? "lock.fill" : "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isLocked ? AppColors.subtext.opacity(0.72) : AppColors.accent.opacity(0.72))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func isLockedMorePack(
        _ pack: ScenePackDefinition,
        configuration: FreeConfiguration
    ) -> Bool {
        configuration.isExtensionLockedPack(pack) && !configuration.isInFirstWeek
    }

    private func lockedSceneHintRow(
        _ hint: LockedSceneHint,
        configuration: FreeConfiguration
    ) -> some View {
        Button {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                configuration.onShowMemberPricing()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(hint.pack.emoji)
                    .font(.system(size: 22))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(hint.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                    Text(hint.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text("了解会员")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.lockGold)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.lockGold.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.lockGold.opacity(0.18), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func lockedPackSubtitle(for pack: ScenePackDefinition) -> String {
        switch pack.id {
        case "travel":
            return "把路费、住宿、门票放回行程里"
        case "pet":
            return "把毛孩子的日常也记得更像生活"
        case "baby":
            return "照护、奶粉、衣物不只是一笔支出"
        case "fitness":
            return "区分补给、装备、课程和恢复"
        default:
            return "会员可解锁更多生活语境"
        }
    }

    private func replacementSlotRow(_ pack: ScenePackDefinition, slot: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedReplaceSlot = slot
            }
        } label: {
            packRowContent(pack, subtitle: "当前角度", isSelected: selectedReplaceSlot == slot)
        }
        .buttonStyle(.plain)
    }

    private func replacementCandidateRow(
        _ pack: ScenePackDefinition,
        configuration: FreeConfiguration
    ) -> some View {
        Button {
            guard let slot = selectedReplaceSlot,
                  configuration.freeScenePacks.indices.contains(slot) else { return }
            let oldPack = configuration.freeScenePacks[slot]
            let replacement = PendingReplacement(slot: slot, oldId: oldPack.id, newPack: pack)
            if configuration.isInFirstWeek {
                confirmReplacement(replacement)
            } else {
                pendingReplacement = replacement
            }
        } label: {
            packRowContent(pack, subtitle: configuration.scenePackDesc(pack), isSelected: false)
        }
        .buttonStyle(.plain)
    }

    private func replaceButton(_ configuration: FreeConfiguration) -> some View {
        let canReplace = configuration.isInFirstWeek || configuration.canReplacePackCombination
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isReplacingPack = true
                selectedReplaceSlot = nil
            }
        } label: {
            HStack {
                Text("替换其中一个角度")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if configuration.isInFirstWeek {
                    Text("首周自由换")
                        .font(.system(size: 12, weight: .medium))
                } else if !configuration.canReplacePackCombination {
                    Text("还有 \(configuration.daysUntilNextReplace) 天")
                        .font(.system(size: 12, weight: .medium))
                } else {
                    Text("换后冷却 30 天")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundStyle(canReplace ? AppColors.accent : AppColors.subtext.opacity(0.58))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canReplace)
    }

    private func packRowContent(
        _ pack: ScenePackDefinition,
        subtitle: String,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Text(pack.emoji)
                .font(.system(size: 22))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(pack.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? AppColors.accent.opacity(0.13) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private func confirmReplacement(_ replacement: PendingReplacement) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if case .free(let configuration) = mode {
            configuration.onReplaceFreePack(replacement.slot, replacement.oldId, replacement.newPack)
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedReplaceSlot = nil
            isReplacingPack = false
        }
    }
}
