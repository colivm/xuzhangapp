import SwiftUI

// MARK: - Member Pricing View (matching web #accountMemberView)

struct MemberPricingView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var benefitsExpanded = false
    @State private var morePlansExpanded = false

    private let plans = [
        MemberPlan(id: "yearly", name: "年度会员", price: "¥98", period: "年", featured: true,
                   badge: "✨ 推荐", dailyHint: "平均每天不到 1 毛钱，最划算"),
        MemberPlan(id: "monthly", name: "月度会员", price: "¥12", period: "月", featured: false,
                   badge: nil, dailyHint: "按月订阅，随时可取消"),
        MemberPlan(id: "lifetime", name: "永久会员", price: "¥198", period: "永久", featured: false,
                   badge: nil, dailyHint: "一次解锁，终身陪伴"),
    ]

    private let benefits = [
        ("📊 无限次 AI 复盘，更懂你的消费节奏", "不限次数复盘，随时回顾账单"),
        ("🌤️ 解锁天气 / 季节场景互动", "开启后，小宠物会根据天气、时间，给你更贴合当下的温柔陪伴语"),
        ("☁️ 云端账单备份，换机不丢记录", "登录账号后，账单数据可安全同步云端"),
        ("🚫 告别所有广告，享受纯净记账体验", "全程无任何弹窗广告，记账更专注、更安心"),
        ("📝 宠物专属昵称 + 智能习惯备注", "自定义宠物名字全覆盖，结合消费偏好自动生成专属温柔备注"),
    ]

    private var isMember: Bool {
        let tier = settingsViewModel.memberTier.lowercased()
        return ["monthly", "yearly", "lifetime"].contains(tier)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // ── Hero ──
                    heroSection

                    // ── Benefits ──
                    benefitsSection

                    // ── Pricing ──
                    if !isMember {
                        pricingSection
                    } else {
                        currentMemberBadge
                    }

                    // ── Privacy ──
                    privacyNote
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(AppColors.bg.ignoresSafeArea())
            .navigationTitle("会员方案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("✨ 升级会员，解锁更多温柔陪伴")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.text)

            Text("让小宠物陪你，更轻松地把钱花明白")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)

            if !isMember {
                Button {
                    handlePurchase(plans[0]) // yearly default
                } label: {
                    Text("立即开通年度会员（推荐）")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [AppColors.accent.opacity(0.92), AppColors.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .shadow(color: AppColors.accent.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                Text("可随时取消，数据仍保留在本地。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.subtext.opacity(0.8))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.08), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { benefitsExpanded.toggle() }
            } label: {
                HStack {
                    Text("查看会员权益详情")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.text.opacity(0.86))
                    Spacer()
                    Text(benefitsExpanded ? "收起" : "展开")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.thinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if benefitsExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(benefits.indices, id: \.self) { idx in
                        let (title, desc) = benefits[idx]
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.text)
                            Text(desc)
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.subtext)
                                .lineSpacing(2)
                        }
                    }
                }
                .padding(14)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Featured yearly plan
            featuredPlanButton(plans[0])

            // More plans toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { morePlansExpanded.toggle() }
            } label: {
                HStack {
                    Text("查看更多套餐")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.text.opacity(0.8))
                    Spacer()
                    Image(systemName: morePlansExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppColors.subtext)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
            }
            .buttonStyle(.plain)

            if morePlansExpanded {
                regularPlanButton(plans[1])
                regularPlanButton(plans[2])
            }

            Text("订阅可随时在 App Store / 账户设置中取消，不会自动扣费。")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.subtext.opacity(0.8))
                .padding(.top, 4)
        }
    }

    // MARK: - Current Member Badge

    private var currentMemberBadge: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundStyle(AppColors.accent)
            Text("你已是\(settingsViewModel.memberTier)会员")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.text)
            Text("所有会员权益已解锁，感谢你的信任与陪伴。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.accent.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Privacy

    private var privacyNote: some View {
        Text("你的账单数据始终保存在本地，会员权益仅用于解锁功能与服务。我们不会将你的数据分享给第三方，也不会发送营销骚扰信息。")
            .font(.system(size: 11))
            .foregroundStyle(AppColors.subtext.opacity(0.75))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Plan Buttons

    private func featuredPlanButton(_ plan: MemberPlan) -> some View {
        Button {
            handlePurchase(plan)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                if let badge = plan.badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppColors.lockGold)
                        )
                        .padding(.bottom, 2)
                }
                Text("\(plan.name)：\(plan.price) / \(plan.period)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(plan.dailyHint)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [AppColors.accent.opacity(0.92), AppColors.accent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: AppColors.accent.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func regularPlanButton(_ plan: MemberPlan) -> some View {
        Button {
            handlePurchase(plan)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(plan.name)：\(plan.price) / \(plan.period)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.text.opacity(0.88))
                Text(plan.dailyHint)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.subtext)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Purchase Handler

    private func handlePurchase(_ plan: MemberPlan) {
        // Demo: simulate member activation (memberTier setter auto-persists)
        settingsViewModel.memberTier = plan.id
        dismiss()
    }
}

// MARK: - Member Plan Model

private struct MemberPlan: Identifiable {
    let id: String
    let name: String
    let price: String
    let period: String
    let featured: Bool
    let badge: String?
    let dailyHint: String
}

// MARK: - Preview

struct MemberPricingView_Previews: PreviewProvider {
    static var previews: some View {
        MemberPricingView()
            .environmentObject(SettingsViewModel())
    }
}
