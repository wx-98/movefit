import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var model: AppModel
    let registrationViewModelFactory: RegistrationViewModelFactory

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    profileHeader
                    healthMetrics
                    achievementSummary
                    settingsGroup
                    supportGroup
                }
                .padding()
            }
            .background(AppColor.pageBackground.ignoresSafeArea())
            .navigationTitle("我的")
        }
    }

    private var profileHeader: some View {
        AppCard {
            HStack(spacing: AppSpacing.medium) {
                Image("MoveFitLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 78, height: 78)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                    Text(model.profile?.nickname ?? "MoveFit 用户").font(.title2.bold()).foregroundColor(.primary)
                    Text(accountCaption).font(.footnote).foregroundColor(.secondary)
                    NavigationLink("编辑健康档案", destination: HealthMetricsFormView().environmentObject(model))
                        .font(.caption.bold()).foregroundColor(AppColor.primary)
                        .padding(.top, AppSpacing.tiny)
                }
                Spacer()
            }
        }
    }

    private var healthMetrics: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack {
                    HealthSectionHeader(title: "身体指标", detail: nil, symbol: "figure.arms.open")
                    Image(systemName: model.hidesSensitiveMetrics ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
                HStack {
                    MetricView(title: "体重", value: protectedWeight, detail: "千克")
                    MetricView(title: "身高", value: protectedHeight, detail: "厘米")
                    MetricView(title: "BMI", value: protectedBMI, detail: "指数")
                }
                .privacySensitive()
            }
        }
    }

    private var achievementSummary: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HealthSectionHeader(title: "运动与成就", detail: "本机与设备数据", symbol: "medal.fill")
                HStack {
                    MetricView(title: "运动", value: "\(model.workouts.count)", detail: "全部来源")
                    MetricView(title: "挑战", value: "\(model.challenges.filter(\.isJoined).count)", detail: "已加入")
                    MetricView(title: "徽章", value: "\(model.badges.filter(\.isUnlocked).count)", detail: "已解锁")
                }
            }
        }
    }

    private var settingsGroup: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HealthSectionHeader(title: "账户与偏好", symbol: "person.crop.circle")
            AppCard {
                VStack(spacing: 0) {
                settingLink(
                    "账号与登录",
                    symbol: "person.crop.circle.badge.checkmark",
                    destination: LocalAccountView(factory: registrationViewModelFactory)
                )
                Divider().padding(.leading, 44)
                settingLink("账号绑定", symbol: "link.circle.fill", destination: AccountBindingsView())
                Divider().padding(.leading, 44)
                settingLink("后端服务", symbol: "server.rack", destination: BackendStatusView())
                Divider().padding(.leading, 44)
                settingLink("健康与设备", symbol: "applewatch", destination: HealthDevicesView())
                Divider().padding(.leading, 44)
                settingLink("外观与语言", symbol: "circle.lefthalf.filled", destination: AppearanceLanguageView())
                Divider().padding(.leading, 44)
                settingLink("隐私与缓存", symbol: "lock.shield.fill", destination: PrivacySettingsView())
                Divider().padding(.leading, 44)
                settingLink("养护建议与收藏", symbol: "leaf.fill", destination: WellnessView())
                }
            }
        }
    }

    private var supportGroup: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HealthSectionHeader(title: "支持与说明", symbol: "questionmark.circle")
            AppCard {
                VStack(spacing: 0) {
                settingLink("帮助与支持", symbol: "questionmark.circle.fill", destination: HelpSupportView())
                Divider().padding(.leading, 44)
                settingLink("隐私政策", symbol: "hand.raised.fill", destination: PrivacyPolicyView())
                Divider().padding(.leading, 44)
                settingLink("关于 MoveFit", symbol: "info.circle.fill", destination: AboutView())
                }
            }
        }
    }

    private func settingLink<Destination: View>(
        _ title: String,
        symbol: String,
        destination: Destination
    ) -> some View {
        HealthSettingsRow(title: title, symbol: symbol) {
            destination.environmentObject(model)
        }
    }

    private var accountCaption: String {
        guard let session = model.accountSession else { return "本地健康模式 · 未登录后端账号" }
        return "\(session.method.rawValue)服务端会话 · \(session.displayName)"
    }

    private var protectedWeight: String {
        guard let profile = model.profile else { return "—" }
        return model.hidesSensitiveMetrics ? "••" : String(format: "%.1f", profile.weight.value)
    }

    private var protectedHeight: String {
        guard let profile = model.profile else { return "—" }
        return model.hidesSensitiveMetrics ? "••" : String(format: "%.0f", profile.height.value)
    }

    private var protectedBMI: String {
        guard let profile = model.profile else { return "—" }
        return model.hidesSensitiveMetrics ? "••" : String(format: "%.1f", profile.bmi)
    }
}
