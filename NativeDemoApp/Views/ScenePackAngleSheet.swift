import SwiftUI
import UIKit
import UniformTypeIdentifiers

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
        let pendingLifeMarkReward: LifeMarkSceneReward?
        let activeLifeMarkReward: LifeMarkSceneReward?
        let isInFirstWeek: Bool
        let daysUntilExtensionLock: Int
        let canReplacePackCombination: Bool
        let nextReplaceAvailableAt: TimeInterval
        let isReplaceWindowActive: Bool
        let replaceWindowEndsAt: TimeInterval
        let scenePackDesc: (ScenePackDefinition) -> String
        let isExtensionLockedPack: (ScenePackDefinition) -> Bool
        let onReorderFreePacks: (_ orderedPackIds: [String]) -> Void
        let onSelectFreePack: (ScenePackDefinition) -> Void
        let onReplaceFreePack: (_ slot: Int, _ oldId: String, _ newPack: ScenePackDefinition) -> Void
        let onClaimLifeMarkReward: (LifeMarkSceneReward) -> Void
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
    @State private var selectedReplaceSlot: Int?
    @State private var pendingReplacement: PendingReplacement?
    @State private var inlineNotice: String?
    @State private var freeCandidatesManuallyExpanded = false
    @State private var draggingMemberPackID: String?
    @State private var claimedLifeMarkRewardID: String?

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
        pendingLifeMarkReward: LifeMarkSceneReward? = nil,
        activeLifeMarkReward: LifeMarkSceneReward? = nil,
        isInFirstWeek: Bool,
        daysUntilExtensionLock: Int,
        canReplacePackCombination: Bool,
        nextReplaceAvailableAt: TimeInterval,
        isReplaceWindowActive: Bool,
        replaceWindowEndsAt: TimeInterval,
        scenePackDesc: @escaping (ScenePackDefinition) -> String,
        isExtensionLockedPack: @escaping (ScenePackDefinition) -> Bool,
        onReorderFreePacks: @escaping (_ orderedPackIds: [String]) -> Void,
        onSelectFreePack: @escaping (ScenePackDefinition) -> Void,
        onReplaceFreePack: @escaping (_ slot: Int, _ oldId: String, _ newPack: ScenePackDefinition) -> Void,
        onClaimLifeMarkReward: @escaping (LifeMarkSceneReward) -> Void,
        onShowMemberPricing: @escaping () -> Void
    ) {
        mode = .free(
            FreeConfiguration(
                freeScenePacks: freeScenePacks,
                moreScenePacks: moreScenePacks,
                replaceableScenePacks: replaceableScenePacks,
                lockedSceneHint: lockedSceneHint,
                pendingLifeMarkReward: pendingLifeMarkReward,
                activeLifeMarkReward: activeLifeMarkReward,
                isInFirstWeek: isInFirstWeek,
                daysUntilExtensionLock: daysUntilExtensionLock,
                canReplacePackCombination: canReplacePackCombination,
                nextReplaceAvailableAt: nextReplaceAvailableAt,
                isReplaceWindowActive: isReplaceWindowActive,
                replaceWindowEndsAt: replaceWindowEndsAt,
                scenePackDesc: scenePackDesc,
                isExtensionLockedPack: isExtensionLockedPack,
                onReorderFreePacks: onReorderFreePacks,
                onSelectFreePack: onSelectFreePack,
                onReplaceFreePack: onReplaceFreePack,
                onClaimLifeMarkReward: onClaimLifeMarkReward,
                onShowMemberPricing: onShowMemberPricing
            )
        )
    }

    var body: some View {
        NavigationStack {
            switch mode {
            case .member(let configuration):
                memberSheet(configuration)
                .navigationTitle("换个角度")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { closeToolbar }
            case .free(let configuration):
                freeSheet(configuration)
                    .navigationTitle("调整免费场景包")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { closeToolbar }
            }
        }
        .presentationDetents([.medium, .large])
        .overlay {
            if let pendingReplacement {
                replacementConfirmOverlay(pendingReplacement)
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: pendingReplacement?.id)

    }


    private func replacementConfirmOverlay(_ replacement: PendingReplacement) -> some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture { pendingReplacement = nil }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.accent.opacity(0.92))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(AppColors.accent.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 7) {
                        Text("æ¿æ¢åºæ¯å")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColors.text)
                        Text("ç¡®å®æ¢ä¸ã\(replacement.newPack.label)ãï¼è¿ä¼å¼å¯ 24 å°æ¶è°æ´çªå£ï¼çªå£åè¿å¯ä»¥ç»§ç»­è°æ´å¦å¤ä¸¤ä¸ªåè´¹åºæ¯åã")
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.text.opacity(0.76))
                            .lineSpacing(4)
                    }
                }
                HStack(spacing: 10) {
                    Button("åæ³æ³") { pendingReplacement = nil }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.text.opacity(0.82))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color.white.opacity(0.72), in: Capsule(style: .continuous))
                    Button("ç¡®å®æ¢ä¸") {
                        let replacement = replacement
                        pendingReplacement = nil
                        confirmReplacement(replacement)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(AppColors.accent.opacity(0.88), in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.58), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.16), radius: 28, y: 14)
            .padding(.horizontal, 24)
        }
    }

    @ToolbarContentBuilder
    private var closeToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("关闭") { dismiss() }
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

    private func memberSheet(_ configuration: MemberConfiguration) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                memberScenePackModule(configuration)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(
            LinearGradient(
                colors: [AppColors.bg, AppColors.paperMist.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func memberScenePackModule(_ configuration: MemberConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("场景包")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.text)
                    Text("常用靠前，少用的会静默收起")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                }
                Spacer()
                Text("\(memberDisplayedScenePacks(configuration).count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(AppColors.accent.opacity(0.12)))
            }

            reorderHint

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(memberDisplayedScenePacks(configuration), id: \.id) { pack in
                    memberPackCard(pack, configuration: configuration)
                }
            }

            if !configuration.secondaryScenePacks.isEmpty {
                memberMoreToggle(configuration)
            }
        }
        .padding(14)
        .background(moduleBackground)
    }

    private func memberPackCard(
        _ pack: ScenePackDefinition,
        configuration: MemberConfiguration
    ) -> some View {
        let packs = memberDisplayedScenePacks(configuration)
        let index = packs.firstIndex { $0.id == pack.id } ?? 0
        let canMoveUp = index > 0
        let canMoveDown = index < packs.count - 1
        let style = ScenePackVisualStyles.style(for: pack)
        return VStack(alignment: .leading, spacing: 9) {
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
                VStack(alignment: .leading, spacing: 9) {
                    scenePackVisual(pack, compact: false)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pack.label)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppColors.text)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(configuration.scenePackDesc(pack))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.subtext)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                memberMoveButton(systemName: "arrow.up", isEnabled: canMoveUp) {
                    moveMemberPack(pack, delta: -1, configuration: configuration)
                }
                memberMoveButton(systemName: "arrow.down", isEnabled: canMoveDown) {
                    moveMemberPack(pack, delta: 1, configuration: configuration)
                }
                Spacer()
                Image(systemName: selectedPackID == pack.id ? "checkmark.circle.fill" : "line.3.horizontal")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(selectedPackID == pack.id ? AppColors.accent : AppColors.subtext.opacity(0.62))
                    .onDrag {
                        draggingMemberPackID = pack.id
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        return NSItemProvider(object: pack.id as NSString)
                    }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
        .background(scenePackCardBackground(tint: style.colors.first ?? AppColors.accent, isSelected: selectedPackID == pack.id))
        .overlay(scenePackCardBorder(tint: style.colors.first ?? AppColors.accent, isSelected: selectedPackID == pack.id))
        .onDrop(
            of: [UTType.plainText],
            delegate: ScenePackMemberDropDelegate(
                targetPack: pack,
                displayedPacks: packs,
                draggingPackID: $draggingMemberPackID,
                onReorder: configuration.onReorderPacks
            )
        )
    }

    private func memberMoveButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isEnabled ? AppColors.text.opacity(0.78) : AppColors.subtext.opacity(0.46))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isEnabled ? AppColors.panelStrong.opacity(0.84) : AppColors.surfaceMuted.opacity(0.48))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isEnabled ? 0.62 : 0.24), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.48)
    }

    private func memberMoreToggle(_ configuration: MemberConfiguration) -> some View {
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
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(AppColors.paperWarm.opacity(0.50))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(AppColors.line.opacity(0.48), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func freeSheet(_ configuration: FreeConfiguration) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                if let hint = configuration.lockedSceneHint {
                    lockedSceneHintCard(hint, configuration: configuration)
                }

                if let reward = configuration.pendingLifeMarkReward,
                   claimedLifeMarkRewardID != reward.id {
                    pendingLifeMarkRewardCard(reward, configuration: configuration)
                }

                freeStatusCard(configuration)
                activeFreeModule(configuration)
                candidateFreeModule(configuration)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(
            LinearGradient(
                colors: [AppColors.bg, AppColors.paperMist.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func freeStatusCard(_ configuration: FreeConfiguration) -> some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: statusIcon(configuration))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(statusTint(configuration))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(statusTint(configuration).opacity(0.12)))

                VStack(alignment: .leading, spacing: 5) {
                    Text(statusTitle(configuration, now: context.date))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                    Text(statusSubtitle(configuration, now: context.date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.panel.opacity(0.92))
                    .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppColors.line.opacity(0.6), lineWidth: 1)
            )
        }
    }

    private func activeFreeModule(_ configuration: FreeConfiguration) -> some View {
        let activeCount = activeFreePackCount(configuration)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("正在使用的 \(activeCount) 个")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.text)
                    Text(activeModuleSubtitle(configuration))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                }
                Spacer()
                Text("\(activeCount)/\(activeCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(AppColors.accent.opacity(0.12)))
            }

            activeAvailabilityPill(configuration)

            VStack(spacing: 10) {
                ForEach(Array(configuration.freeScenePacks.enumerated()), id: \.element.id) { index, pack in
                    activePackCard(pack, slot: index, configuration: configuration)
                }
                if let reward = configuration.activeLifeMarkReward,
                   let pack = activeRewardPack(for: reward, configuration: configuration) {
                    activeRewardPackRow(pack, configuration: configuration)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.accent.opacity(0.82))
                Text("点右侧按钮先移下一个，再从下面换上来")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                Spacer()
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(moduleBackground)
    }

    private func candidateFreeModule(_ configuration: FreeConfiguration) -> some View {
        let candidatePacks = candidateScenePacks(configuration)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("下面可替换的 \(candidatePacks.count) 个")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.text)
                    Text(candidateModuleSubtitle(configuration))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                }
                Spacer()
            }

            if shouldExpandFreeCandidates(configuration) {
                candidateAvailabilityPill(configuration)
            } else {
                freeCandidateFoldedToggle(configuration)
            }

            if shouldExpandFreeCandidates(configuration), let inlineNotice {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(inlineNotice)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(AppColors.accent)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.accent.opacity(0.10))
                )
            }

            if shouldExpandFreeCandidates(configuration),
               let selectedReplaceSlot,
               configuration.freeScenePacks.indices.contains(selectedReplaceSlot) {
                movedDownPackStrip(configuration.freeScenePacks[selectedReplaceSlot])
            }

            if shouldExpandFreeCandidates(configuration) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(candidatePacks, id: \.id) { pack in
                        candidatePackCard(pack, configuration: configuration)
                    }
                }
                memberUnlockCard(configuration)
            }
        }
        .padding(14)
        .background(moduleBackground)
    }

    private func shouldExpandFreeCandidates(_ configuration: FreeConfiguration) -> Bool {
        configuration.isInFirstWeek
            || configuration.isReplaceWindowActive
            || selectedReplaceSlot != nil
            || freeCandidatesManuallyExpanded
    }

    private func freeCandidateFoldedToggle(_ configuration: FreeConfiguration) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                freeCandidatesManuallyExpanded = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: configuration.canReplacePackCombination ? "arrow.triangle.2.circlepath" : "chevron.down.circle")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(AppColors.accent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("展开可替换场景包")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                    Text("\(candidateScenePacks(configuration).count) 个未选场景包和会员引导已收起")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.subtext)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.paperWarm.opacity(0.50))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppColors.line.opacity(0.50), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func activeAvailabilityPill(_ configuration: FreeConfiguration) -> some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            infoPill(
                icon: "clock",
                text: activeAvailabilityText(configuration, now: context.date),
                tint: statusTint(configuration)
            )
        }
    }

    private func candidateAvailabilityPill(_ configuration: FreeConfiguration) -> some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            infoPill(
                icon: configuration.canReplacePackCombination || configuration.isInFirstWeek ? "checkmark.circle" : "lock.clock",
                text: candidateAvailabilityText(configuration, now: context.date),
                tint: statusTint(configuration)
            )
        }
    }

    private func infoPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    private func memberUnlockCard(_ configuration: FreeConfiguration) -> some View {
        Button {
            openMemberPricingAfterDismiss(configuration)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.lockGold)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(AppColors.lockGold.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text("会员不用等冷却")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                    Text("全部场景包可随时启用，旅行、家庭照护和兴趣装备都会跟着记录变化。")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.subtext)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.lockGold.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppColors.lockGold.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func scenePackCardBackground(
        tint: Color,
        isSelected: Bool = false,
        isLocked: Bool = false
    ) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(AppColors.panelStrong.opacity(isLocked ? 0.46 : (isSelected ? 0.88 : 0.72)))
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isLocked ? 0.18 : 0.34),
                        AppColors.paperWarm.opacity(isLocked ? 0.18 : 0.28),
                        tint.opacity(isSelected ? 0.16 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            .overlay(alignment: .bottomTrailing) {
                RadialGradient(
                    colors: [
                        (isLocked ? AppColors.lockGold : tint).opacity(isSelected ? 0.16 : 0.10),
                        Color.clear
                    ],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 120
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
    }

    private func scenePackCardBorder(
        tint: Color,
        isSelected: Bool = false,
        isLocked: Bool = false
    ) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isLocked ? 0.24 : 0.62),
                        (isLocked ? AppColors.lockGold : tint).opacity(isSelected || isLocked ? 0.34 : 0.18),
                        AppColors.line.opacity(0.52)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isSelected ? 1.2 : 1
            )
    }

    private var moduleBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppColors.panel.opacity(0.94))
            .shadow(color: Color.black.opacity(0.055), radius: 18, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppColors.line.opacity(0.62), lineWidth: 1)
            )
    }

    private func activePackCard(
        _ pack: ScenePackDefinition,
        slot: Int,
        configuration: FreeConfiguration
    ) -> some View {
        let isOpenSlot = selectedReplaceSlot == slot
        let canReplace = configuration.isInFirstWeek || configuration.canReplacePackCombination
        let style = ScenePackVisualStyles.style(for: pack)
        return HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selectedPackID = pack.id
                configuration.onSelectFreePack(pack)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    dismiss()
                }
            } label: {
                HStack(spacing: 10) {
                    scenePackVisual(pack, compact: true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(pack.label)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.text)
                            .lineLimit(1)
                        Text(isOpenSlot ? "已移到下面，选一个新场景包补上来" : configuration.scenePackDesc(pack))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isOpenSlot ? AppColors.accent : AppColors.subtext)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .disabled(isOpenSlot)

            if isOpenSlot {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedReplaceSlot = nil
                        inlineNotice = nil
                    }
                } label: {
                    Image(systemName: "arrow.uturn.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.subtext)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(AppColors.surfaceMuted.opacity(0.8)))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    guard canReplace else {
                        showCooldownNotice(configuration)
                        return
                    }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedReplaceSlot = slot
                        inlineNotice = "现在从下面选一个换上来"
                    }
                } label: {
                    Image(systemName: canReplace ? "arrow.down.circle.fill" : "clock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(canReplace ? AppColors.accent : AppColors.subtext.opacity(0.62))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill((canReplace ? AppColors.accent : AppColors.surfaceMuted).opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(11)
        .background(scenePackCardBackground(tint: style.colors.first ?? AppColors.accent, isSelected: isOpenSlot))
        .overlay(scenePackCardBorder(tint: style.colors.first ?? AppColors.accent, isSelected: isOpenSlot))
        .contentShape(Rectangle())
    }

    private func candidatePackCard(
        _ pack: ScenePackDefinition,
        configuration: FreeConfiguration
    ) -> some View {
        let isLocked = isLockedMorePack(pack, configuration: configuration)
        let canReplaceThisPack = configuration.replaceableScenePacks.contains { $0.id == pack.id }
        let style = ScenePackVisualStyles.style(for: pack)
        return Button {
            handleCandidateTap(pack, isLocked: isLocked, canReplaceThisPack: canReplaceThisPack, configuration: configuration)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                scenePackVisual(pack, compact: false)

                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(candidateSubtitle(for: pack, isLocked: isLocked, configuration: configuration))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isLocked ? AppColors.lockGold : AppColors.subtext)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Spacer()
                    Image(systemName: isLocked ? "lock.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isLocked ? AppColors.lockGold : AppColors.accent)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
            .background(scenePackCardBackground(tint: style.colors.first ?? AppColors.accent, isLocked: isLocked))
            .overlay(scenePackCardBorder(tint: style.colors.first ?? AppColors.accent, isLocked: isLocked))
        }
        .buttonStyle(.plain)
    }

    private func scenePackVisual(_ pack: ScenePackDefinition, compact: Bool) -> some View {
        let style = ScenePackVisualStyles.style(for: pack)
        return ZStack(alignment: .bottomLeading) {
            ScenePackVisualBackdrop(style: style, compact: compact)

            HStack(spacing: 7) {
                Text(pack.emoji)
                    .font(.system(size: compact ? 22 : 24))
                if !compact {
                    Text(style.keyword)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .padding(compact ? 8 : 10)
        }
        .frame(width: compact ? 70 : nil, height: compact ? 58 : 76)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 15 : 16, style: .continuous))
    }

    private func movedDownPackStrip(_ pack: ScenePackDefinition) -> some View {
        HStack(spacing: 8) {
            Text(pack.emoji)
                .font(.system(size: 16))
            Text("已移下：\(pack.label)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
            Spacer()
            Text("待补位")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.accent)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(AppColors.accent.opacity(0.08))
        )
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

    private func moveMemberPack(
        _ pack: ScenePackDefinition,
        delta: Int,
        configuration: MemberConfiguration
    ) {
        var packs = memberDisplayedScenePacks(configuration)
        guard let currentIndex = packs.firstIndex(where: { $0.id == pack.id }) else { return }
        let nextIndex = currentIndex + delta
        guard packs.indices.contains(nextIndex) else { return }
        packs.swapAt(currentIndex, nextIndex)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        configuration.onReorderPacks(packs.map(\.id), [pack.id])
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

    private func pendingLifeMarkRewardCard(
        _ reward: LifeMarkSceneReward,
        configuration: FreeConfiguration
    ) -> some View {
        let pack = scenePack(for: reward.packId, configuration: configuration)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(AppColors.accent.opacity(0.12)))

                VStack(alignment: .leading, spacing: 5) {
                    Text("有 1 次生活印记奖励待领取")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.text)
                    Text("奖励一次免费体验")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                    Text(pack.map { "领取后可体验「\($0.label)」7 天，不占用当前 3 个免费场景包。" } ?? reward.detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                configuration.onClaimLifeMarkReward(reward)
                withAnimation(.easeInOut(duration: 0.18)) {
                    claimedLifeMarkRewardID = reward.id
                    inlineNotice = pack.map { "已领取「\($0.label)」7 天体验" } ?? "已领取 7 天体验"
                }
            } label: {
                Text("领取体验")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.accent.opacity(0.18), lineWidth: 1)
        )
    }

    private func activeRewardPackRow(
        _ pack: ScenePackDefinition,
        configuration: FreeConfiguration
    ) -> some View {
        let style = ScenePackVisualStyles.style(for: pack)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedPackID = pack.id
            configuration.onSelectFreePack(pack)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                dismiss()
            }
        } label: {
            HStack(spacing: 10) {
                scenePackVisual(pack, compact: true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(pack.label)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.text)
                            .lineLimit(1)
                        Text("7天体验中")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.accent.opacity(0.12)))
                    }
                    Text("生活印记奖励，不占基础免费名额")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Text("使用")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(Capsule().fill(AppColors.accent))
            }
            .padding(11)
            .background(scenePackCardBackground(tint: style.colors.first ?? AppColors.accent, isSelected: selectedPackID == pack.id))
            .overlay(scenePackCardBorder(tint: AppColors.accent, isSelected: true))
        }
        .buttonStyle(.plain)
    }

    private func scenePack(
        for packId: String,
        configuration: FreeConfiguration
    ) -> ScenePackDefinition? {
        (configuration.freeScenePacks + configuration.moreScenePacks)
            .first { $0.id == packId }
            ?? ScenePackCopyPool.definitions.first { $0.id == packId }
    }

    private func activeRewardPack(
        for reward: LifeMarkSceneReward,
        configuration: FreeConfiguration
    ) -> ScenePackDefinition? {
        guard !configuration.freeScenePacks.contains(where: { $0.id == reward.packId }) else {
            return nil
        }
        return scenePack(for: reward.packId, configuration: configuration)
    }

    private func activeFreePackCount(_ configuration: FreeConfiguration) -> Int {
        guard let reward = configuration.activeLifeMarkReward,
              activeRewardPack(for: reward, configuration: configuration) != nil else {
            return configuration.freeScenePacks.count
        }
        return configuration.freeScenePacks.count + 1
    }

    private func candidateScenePacks(_ configuration: FreeConfiguration) -> [ScenePackDefinition] {
        guard let reward = configuration.activeLifeMarkReward,
              activeRewardPack(for: reward, configuration: configuration) != nil else {
            return configuration.moreScenePacks
        }
        return configuration.moreScenePacks.filter { $0.id != reward.packId }
    }

    private func lockedSceneHintCard(
        _ hint: LockedSceneHint,
        configuration: FreeConfiguration
    ) -> some View {
        Button {
            openMemberPricingAfterDismiss(configuration)
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text("了解会员")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.lockGold)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.lockGold.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppColors.lockGold.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

    private func handleCandidateTap(
        _ pack: ScenePackDefinition,
        isLocked: Bool,
        canReplaceThisPack: Bool,
        configuration: FreeConfiguration
    ) {
        if isLocked {
            openMemberPricingAfterDismiss(configuration)
            return
        }

        guard configuration.isInFirstWeek || configuration.canReplacePackCombination else {
            showCooldownNotice(configuration)
            return
        }

        guard let slot = selectedReplaceSlot,
              configuration.freeScenePacks.indices.contains(slot) else {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                inlineNotice = "基础免费名额已满，先把一个移下来"
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }

        guard canReplaceThisPack else { return }
        let oldPack = configuration.freeScenePacks[slot]
        let replacement = PendingReplacement(slot: slot, oldId: oldPack.id, newPack: pack)
        if configuration.isInFirstWeek {
            confirmReplacement(replacement)
        } else {
            pendingReplacement = replacement
        }
    }

    private func confirmReplacement(_ replacement: PendingReplacement) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if case .free(let configuration) = mode {
            configuration.onReplaceFreePack(replacement.slot, replacement.oldId, replacement.newPack)
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedReplaceSlot = nil
            inlineNotice = "已换上「\(replacement.newPack.label)」"
        }
    }

    private func showCooldownNotice(_ configuration: FreeConfiguration) {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            inlineNotice = "还在冷却中，\(cooldownBriefText(configuration, now: Date()))后可开启调整窗口"
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func isLockedMorePack(
        _ pack: ScenePackDefinition,
        configuration: FreeConfiguration
    ) -> Bool {
        configuration.isExtensionLockedPack(pack) && !configuration.isInFirstWeek
    }

    private func activeModuleSubtitle(_ configuration: FreeConfiguration) -> String {
        if selectedReplaceSlot != nil {
            return "已经空出一个位置，从下面选一个补上来"
        }
        if activeFreePackCount(configuration) > configuration.freeScenePacks.count {
            return "3 个基础免费包，加上奖励体验一起可用"
        }
        if configuration.isInFirstWeek {
            return "首周可以自由试，找到最常用的三个"
        }
        if configuration.isReplaceWindowActive {
            return "24 小时调整窗口内，还能继续换"
        }
        if configuration.canReplacePackCombination {
            return "先把一个移下来，再从下面换上一个"
        }
        return "基础免费包仍可正常使用，替换区在冷却"
    }

    private func candidateModuleSubtitle(_ configuration: FreeConfiguration) -> String {
        if configuration.isInFirstWeek {
            return "首周可任意换上去，扩展包锁定前先试试"
        }
        if configuration.isReplaceWindowActive {
            return "窗口内可以继续换，直到倒计时结束"
        }
        if configuration.canReplacePackCombination {
            return "第一次换上去后，才开始 24 小时调整倒计时"
        }
        return "替换区每 30 天开放一次；不足一天时显示时分秒"
    }

    private func activeAvailabilityText(_ configuration: FreeConfiguration, now: Date) -> String {
        if configuration.isInFirstWeek {
            return "首周自由调整，现在换不进冷却"
        }
        if configuration.isReplaceWindowActive {
            return "调整窗口还剩 \(countdownText(until: configuration.replaceWindowEndsAt, now: now))"
        }
        if configuration.canReplacePackCombination {
            return "可换到：现在，第一次换上去后开始 24 小时窗口"
        }
        return "可换到：\(countdownText(until: configuration.nextReplaceAvailableAt, now: now))后"
    }

    private func candidateAvailabilityText(_ configuration: FreeConfiguration, now: Date) -> String {
        let count = candidateScenePacks(configuration).count
        if configuration.isInFirstWeek {
            return "下面 \(count) 个首周都可以试"
        }
        if configuration.isReplaceWindowActive {
            return "下面 \(count) 个可继续替换，窗口还剩 \(countdownText(until: configuration.replaceWindowEndsAt, now: now))"
        }
        if configuration.canReplacePackCombination {
            return "下面 \(count) 个可替换，换上第一个才开始倒计时"
        }
        return "下面替换区 30 天冷却还剩 \(countdownText(until: configuration.nextReplaceAvailableAt, now: now))"
    }

    private func candidateSubtitle(
        for pack: ScenePackDefinition,
        isLocked: Bool,
        configuration: FreeConfiguration
    ) -> String {
        if isLocked {
            return lockedPackSubtitle(for: pack)
        }
        if configuration.isInFirstWeek, configuration.isExtensionLockedPack(pack) {
            return extensionLockCountdownText(configuration)
        }
        return configuration.scenePackDesc(pack)
    }

    private func statusIcon(_ configuration: FreeConfiguration) -> String {
        if configuration.isInFirstWeek { return "sparkles" }
        if configuration.isReplaceWindowActive { return "timer" }
        if configuration.canReplacePackCombination { return "arrow.triangle.2.circlepath" }
        return "lock.clock"
    }

    private func statusTint(_ configuration: FreeConfiguration) -> Color {
        if configuration.isInFirstWeek { return AppColors.accent }
        if configuration.isReplaceWindowActive { return AppColors.accent }
        if configuration.canReplacePackCombination { return AppColors.accent }
        return AppColors.lockGold
    }

    private func statusTitle(_ configuration: FreeConfiguration, now: Date) -> String {
        if configuration.isInFirstWeek {
            return "首周试用中"
        }
        if configuration.isReplaceWindowActive {
            return "24 小时调整窗口还剩 \(countdownText(until: configuration.replaceWindowEndsAt, now: now))"
        }
        if configuration.canReplacePackCombination {
            return "现在可换，第一次换上去后开始计时"
        }
        return "替换区冷却中，还剩 \(countdownText(until: configuration.nextReplaceAvailableAt, now: now))"
    }

    private func statusSubtitle(_ configuration: FreeConfiguration, now: Date) -> String {
        if configuration.isInFirstWeek {
            return "\(extensionLockCountdownText(configuration))。现在调整不进入 30 天冷却。"
        }
        if configuration.isReplaceWindowActive {
            return "这 24 小时是调整窗口，换完后上方不会再显示可换倒计时。"
        }
        if configuration.canReplacePackCombination {
            return "先移下上面一个，再从下面换上一个；从第一次换上去开始算 24 小时窗口。"
        }
        return "上面的场景包还能继续用；下面的替换区到期后，会重新开放一天调整窗口。"
    }

    private func cooldownBriefText(_ configuration: FreeConfiguration, now: Date) -> String {
        countdownText(until: configuration.nextReplaceAvailableAt, now: now)
    }

    private func countdownText(until timestamp: TimeInterval, now: Date) -> String {
        guard timestamp > 0 else { return "0:00:00" }
        let seconds = max(0, Int(ceil(timestamp - now.timeIntervalSince1970)))
        if seconds >= 86_400 {
            return "\(Int(ceil(Double(seconds) / 86_400.0))) 天"
        }
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let restSeconds = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, restSeconds)
    }

    private func extensionLockCountdownText(_ configuration: FreeConfiguration) -> String {
        let days = max(0, configuration.daysUntilExtensionLock)
        return days <= 1 ? "出去玩、娃和毛孩等扩展角度今天后锁定" : "出去玩、娃和毛孩等扩展角度还有 \(days) 天锁定"
    }

    private func openMemberPricingAfterDismiss(_ configuration: FreeConfiguration) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            configuration.onShowMemberPricing()
        }
    }

    private func lockedPackSubtitle(for pack: ScenePackDefinition) -> String {
        switch pack.id {
        case "travel":
            return "会员可用：把路费、住宿、门票放回行程里"
        case "family":
            return "会员可用：奶粉尿不湿、宠物粮猫砂都是照护节奏"
        default:
            return "会员可解锁更多生活语境"
        }
    }

    private func scenePackStyle(for pack: ScenePackDefinition) -> (colors: [Color], symbols: [String], keyword: String) {
        switch pack.id {
        case "commute":
            return ([Color(red: 0.24, green: 0.50, blue: 0.86), Color(red: 0.42, green: 0.78, blue: 0.74)], ["tram.fill", "car.fill"], "出门")
        case "food":
            return ([Color(red: 0.95, green: 0.43, blue: 0.35), Color(red: 0.98, green: 0.72, blue: 0.38)], ["cup.and.saucer.fill", "fork.knife"], "干饭")
        case "supply":
            return ([Color(red: 0.30, green: 0.63, blue: 0.48), Color(red: 0.79, green: 0.74, blue: 0.42)], ["basket.fill", "shippingbox.fill"], "补货")
        case "shopping":
            return ([Color(red: 0.58, green: 0.45, blue: 0.86), Color(red: 0.94, green: 0.54, blue: 0.68)], ["bag.fill", "camera.fill"], "快递")
        case "care":
            return ([Color(red: 0.22, green: 0.64, blue: 0.66), Color(red: 0.60, green: 0.74, blue: 0.88)], ["heart.fill", "figure.strengthtraining.traditional"], "身体")
        case "home":
            return ([Color(red: 0.58, green: 0.54, blue: 0.46), Color(red: 0.77, green: 0.64, blue: 0.47)], ["house.fill", "wrench.and.screwdriver.fill"], "住处")
        case "social":
            return ([Color(red: 0.88, green: 0.35, blue: 0.48), Color(red: 0.93, green: 0.68, blue: 0.36)], ["gift.fill", "person.2.fill"], "人情")
        case "travel":
            return ([Color(red: 0.24, green: 0.47, blue: 0.82), Color(red: 0.62, green: 0.74, blue: 0.50)], ["airplane", "map.fill"], "出走")
        case "family":
            return ([Color(red: 0.94, green: 0.52, blue: 0.55), Color(red: 0.62, green: 0.57, blue: 0.86)], ["pawprint.fill", "figure.and.child.holdinghands"], "照护")
        default:
            return ([AppColors.accent, AppColors.heroGradientTeal], ["sparkles"], "生活")
        }
    }
}

private struct ScenePackMemberDropDelegate: DropDelegate {
    let targetPack: ScenePackDefinition
    let displayedPacks: [ScenePackDefinition]
    @Binding var draggingPackID: String?
    let onReorder: (_ orderedPackIds: [String], _ movedPackIds: Set<String>) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingPackID,
              draggingPackID != targetPack.id,
              let sourceIndex = displayedPacks.firstIndex(where: { $0.id == draggingPackID }),
              let targetIndex = displayedPacks.firstIndex(where: { $0.id == targetPack.id }) else {
            return
        }

        var nextPacks = displayedPacks
        nextPacks.move(
            fromOffsets: IndexSet(integer: sourceIndex),
            toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
        )
        onReorder(nextPacks.map(\.id), [draggingPackID])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingPackID = nil
        return true
    }
}
