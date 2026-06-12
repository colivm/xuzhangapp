import SwiftUI

struct ScenePackAngleSheet: View {
    let primaryScenePacks: [ScenePackDefinition]
    let secondaryScenePacks: [ScenePackDefinition]
    @Binding var isMoreExpanded: Bool
    let scenePackDesc: (ScenePackDefinition) -> String
    let onPromotePack: (ScenePackDefinition) -> Void
    let onSelectPack: (ScenePackDefinition) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("常用场景") {
                    ForEach(primaryScenePacks, id: \.id) { pack in
                        packRow(pack)
                    }
                }

                if !secondaryScenePacks.isEmpty {
                    Section {
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

                    if isMoreExpanded {
                        Section("未常用场景") {
                            ForEach(secondaryScenePacks, id: \.id) { pack in
                                packRow(pack)
                            }
                        }
                    }
                }
            }
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

    private func packRow(_ pack: ScenePackDefinition) -> some View {
        HStack(spacing: 8) {
            Button {
                onSelectPack(pack)
                dismiss()
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
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                onPromotePack(pack)
            } label: {
                Image(systemName: "arrow.up.to.line.compact")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.subtext.opacity(0.84))
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.72))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("置顶\(pack.label)")
        }
    }
}
