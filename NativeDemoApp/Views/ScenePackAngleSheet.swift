import SwiftUI

struct ScenePackAngleSheet: View {
    let scenePacks: [ScenePackDefinition]
    let scenePackDesc: (ScenePackDefinition) -> String
    let onSelectPack: (ScenePackDefinition) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(scenePacks) { pack in
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
                                    .lineLimit(2)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
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
}
