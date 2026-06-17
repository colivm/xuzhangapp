import SwiftUI
import UIKit

struct ScenePackAngleSheet: View {
    let primaryScenePacks: [ScenePackDefinition]
    let secondaryScenePacks: [ScenePackDefinition]
    @Binding var isMoreExpanded: Bool
    var allowsReorder: Bool = true
    var lockedPackIds: Set<String> = []
    var moreCollapsedTitle: String = "展开未常用场景"
    var moreExpandedTitle: String = "收起未常用场景"
    var moreSubtitle: String?
    var lockedBadgeText: String?
    var selectionLimit: Int?
    var selectionIntroText: String?
    var confirmSelectionTitle: String = "选好这 3 个"
    var initialSelectedPackIds: [String] = []
    let scenePackDesc: (ScenePackDefinition) -> String
    let onReorderPacks: (_ orderedPackIds: [String], _ movedPackIds: Set<String>) -> Void
    let onSelectPack: (ScenePackDefinition) -> Void
    var onSelectLockedPack: ((ScenePackDefinition) -> Void)? = nil
    var onConfirmSelection: (([String]) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPackID: String?
    @State private var selectedPackIds: Set<String> = []
    @State private var didSeedSelection = false

    private var isSelectionMode: Bool {
        selectionLimit != nil
    }

    private var displayedScenePacks: [ScenePackDefinition] {
        isMoreExpanded ? primaryScenePacks + secondaryScenePacks : primaryScenePacks
    }

    var body: some View {
        NavigationStack {
            List {
                if let selectionIntroText {
                    Section {
                        Text(selectionIntroText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if allowsReorder {
                    Section {
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
                }

                Section("场景包") {
                    if allowsReorder {
                        ForEach(displayedScenePacks, id: \.id) { pack in
                            packRow(pack, isLocked: lockedPackIds.contains(pack.id))
                        }
                        .onMove(perform: reorderDisplayedPacks)
                    } else {
                        ForEach(displayedScenePacks, id: \.id) { pack in
                            packRow(pack, isLocked: lockedPackIds.contains(pack.id))
                        }
                    }

                    if !secondaryScenePacks.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isMoreExpanded.toggle()
                            }
                        } label: {
                            HStack {
                                Text(isMoreExpanded ? moreExpandedTitle : moreCollapsedTitle)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppColors.text)
                                Text(moreSubtitle ?? "\(secondaryScenePacks.count) 个未用或静默")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.subtext)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: isMoreExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(AppColors.subtext)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if let selectionLimit {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("已选 \(selectedPackIds.count)/\(selectionLimit)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppColors.subtext)

                            Button {
                                let orderedIds = displayedScenePacks
                                    .map(\.id)
                                    .filter { selectedPackIds.contains($0) }
                                onConfirmSelection?(orderedIds)
                                dismiss()
                            } label: {
                                Text(confirmSelectionTitle)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(AppColors.accent.opacity(selectedPackIds.count == selectionLimit ? 0.92 : 0.38))
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedPackIds.count != selectionLimit)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .environment(\.editMode, allowsReorder ? .constant(.active) : .constant(.inactive))
            .navigationTitle("换个角度")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            guard !didSeedSelection else { return }
            selectedPackIds = Set(initialSelectedPackIds)
            didSeedSelection = true
        }
    }

    private func reorderDisplayedPacks(from source: IndexSet, to destination: Int) {
        let currentPacks = displayedScenePacks
        let movedPackIds = Set(source.compactMap { index in
            currentPacks.indices.contains(index) ? currentPacks[index].id : nil
        })
        var reorderedPacks = currentPacks
        reorderedPacks.move(fromOffsets: source, toOffset: destination)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onReorderPacks(reorderedPacks.map(\.id), movedPackIds)
    }

    private func packRow(_ pack: ScenePackDefinition, isLocked: Bool = false) -> some View {
        Button {
            if isSelectionMode {
                togglePackSelection(pack)
                return
            }
            if isLocked {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onSelectLockedPack?(pack)
                return
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.12)) {
                selectedPackID = pack.id
            }
            onSelectPack(pack)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                dismiss()
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
                    Text(scenePackDesc(pack))
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext)
                        .lineLimit(1)
                }

                Spacer()

                if isSelectionMode, selectedPackIds.contains(pack.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                        .transition(.scale.combined(with: .opacity))
                } else if isLocked, let lockedBadgeText {
                    Text(lockedBadgeText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.lockGold.opacity(0.92))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppColors.lockGold.opacity(0.10))
                        )
                } else if selectedPackID == pack.id {
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
                    .fill(isPackVisuallySelected(pack) ? AppColors.accent.opacity(0.13) : Color.clear)
            )
            .opacity(isLocked ? 0.72 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func togglePackSelection(_ pack: ScenePackDefinition) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.12)) {
            if selectedPackIds.contains(pack.id) {
                selectedPackIds.remove(pack.id)
                return
            }
            if let selectionLimit, selectedPackIds.count >= selectionLimit {
                return
            }
            selectedPackIds.insert(pack.id)
        }
    }

    private func isPackVisuallySelected(_ pack: ScenePackDefinition) -> Bool {
        if isSelectionMode {
            return selectedPackIds.contains(pack.id)
        }
        return selectedPackID == pack.id
    }
}
