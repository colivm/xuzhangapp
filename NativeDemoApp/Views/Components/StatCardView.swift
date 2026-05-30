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
                .background(Color(red: 0.47, green: 0.69, blue: 0.63).opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
            }

            Spacer()
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct StatCardView_Previews: PreviewProvider {
    static var previews: some View {
        StatCardView(title: "示例", value: "42", iconName: "number")
            .padding()
    }
}
