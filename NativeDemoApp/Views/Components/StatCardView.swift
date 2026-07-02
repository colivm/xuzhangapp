import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let iconName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(AppColors.accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppColors.subtext)
                Text(value)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
            }

            Spacer()
        }
        .padding(16)
        .metricSurface(radius: 16, padding: 0, tint: AppColors.accent)
    }
}

struct StatCardView_Previews: PreviewProvider {
    static var previews: some View {
        StatCardView(title: "示例", value: "42", iconName: "number")
            .padding()
    }
}
