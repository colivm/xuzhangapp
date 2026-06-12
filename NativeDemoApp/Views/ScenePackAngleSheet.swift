import SwiftUI
import UIKit

struct ScenePackAngleSheet: View {
    let primaryScenePacks: [ScenePackDefinition]
    let secondaryScenePacks: [ScenePackDefinition]
    @Binding var isMoreExpanded: Bool
    let scenePackDesc: (ScenePackDefinition) -> String
    let onReorderPacks: (_ orderedPackIds: [String], _ movedPackIds: Set<String>) -> Void
    let onSelectPack: (ScenePackDefinition) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPackID: String?

    private var displayedScenePacks: [ScenePackDefinition] {
        isMoreExpanded ? primaryScenePacks + secondaryScenePacks : primaryScenePacks
    }

    var body: some View {
        NavigationStack {
            List {
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

                Section("场景包") {
                    ForEach(displayedScenePacks, id: \.id) { pack in
                        packRow(pack)
                    }
                    .onMove(perform: reorderDisplayedPacks)

                    if !secondaryScenePacks.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isMoreExpanded.toggle()
                            }
                        } label: {
                            HStack {
                                Text(isMoreExpanded ? "收起未常用场景" : "展开未常用场景")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppColors.text)
                                Text("\(secondaryScenePacks.count) 个未用或静默")
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

    private func packRow(_ pack: ScenePackDefinition) -> some View {
        Button {
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

                if selectedPackID == pack.id {
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
                    .fill(selectedPackID == pack.id ? AppColors.accent.opacity(0.13) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
