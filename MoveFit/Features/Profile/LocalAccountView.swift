import SwiftUI

struct LocalAccountView: View {
    private enum FocusedField: Hashable {
        case identifier
        case password
        case code
    }

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var registration: RegistrationViewModel
    @State private var isRegistering = false
    @State private var showsCredentials = false
    @FocusState private var focusedField: FocusedField?

    init(factory: RegistrationViewModelFactory) {
        _registration = StateObject(wrappedValue: factory.make())
    }

    var body: some View {
        Group {
            if let session = model.accountSession {
                Form { signedInSection(session) }
            } else if showsCredentials {
                credentialsContent
            } else {
                landingContent
            }
        }
        .navigationTitle("账户")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppColor.pageBackground.ignoresSafeArea())
        .onDisappear {
            registration.cancel()
        }
        .onChange(of: registration.phase) { phase in
            guard phase == .completed,
                  let completion = registration.completion else {
                return
            }
            registration.kind = completion.kind
            registration.identifier = completion.loginIdentifier
            isRegistering = false
            showsCredentials = true
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if showsCredentials && model.accountSession == nil {
                    Button("其他方式") {
                        focusedField = nil
                        registration.prepareForAnotherRegistration()
                        showsCredentials = false
                        isRegistering = false
                    }
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    focusedField = nil
                }
                .accessibilityIdentifier("registrationKeyboardDoneButton")
            }
        }
    }

    private var landingContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                VStack(spacing: AppSpacing.medium) {
                    Image("MoveFitLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 86, height: 86)
                        .accessibilityHidden(true)
                    Text("欢迎来到 MoveFit")
                        .font(.largeTitle.bold())
                    Text("登录后同步账号资料与运动记录。也可以继续使用本机健康功能。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.section)

                VStack(spacing: AppSpacing.medium) {
                    Button {
                        showCredentials(registering: false)
                    } label: {
                        Label("使用手机号或邮箱登录", systemImage: "person.crop.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColor.primary)
                    .controlSize(.large)
                    .accessibilityIdentifier("accountChoosePasswordButton")

                    HStack(spacing: AppSpacing.medium) {
                        Rectangle().fill(AppColor.separator).frame(height: 1)
                        Text("或使用其他方式")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize()
                        Rectangle().fill(AppColor.separator).frame(height: 1)
                    }

                    providerButton(
                        title: "使用 Apple 登录",
                        symbol: "applelogo",
                        provider: .apple,
                        identifier: "accountAppleButton"
                    )
                    providerButton(
                        title: "使用微信登录",
                        symbol: "message.fill",
                        provider: .wechat,
                        identifier: "accountWeChatButton"
                    )
                    providerButton(
                        title: "使用 Google 登录",
                        symbol: "globe",
                        provider: .google,
                        identifier: "accountGoogleButton"
                    )

                    Button("创建账号") {
                        showCredentials(registering: true)
                    }
                    .font(.subheadline.bold())
                    .accessibilityIdentifier("registrationModeButton")
                }
                .frame(maxWidth: 420)

                VStack(spacing: AppSpacing.small) {
                    Button("暂不登录，继续本机体验") { dismiss() }
                        .font(.subheadline)
                    NavigationLink("查看隐私政策", destination: PrivacyPolicyView())
                        .font(.caption)
                    Text("第三方授权成功后才会建立后端会话；未配置时不会创建模拟账号。")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppSpacing.medium)
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: .infinity)
        }
    }

    private func providerButton(
        title: LocalizedStringKey,
        symbol: String,
        provider: SocialProvider,
        identifier: String
    ) -> some View {
        Button {
            Task {
                _ = await model.signInSocial(provider: provider)
            }
        } label: {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Text(LocalizedStringKey(provider == .wechat ? "需配置" : "授权登录"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(model.accountOperationInProgress)
        .accessibilityIdentifier(identifier)
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            NavigationLink("查看隐私政策", destination: PrivacyPolicyView())
            Text("登录会将账号标识提交给 MoveFit 后端，令牌安全保存于 Keychain。")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func showCredentials(registering: Bool) {
        isRegistering = registering
        showsCredentials = true
    }

    private func signedInSection(_ session: AccountSession) -> some View {
        Section("当前会话") {
            HStack { Text("账号"); Spacer(); Text(session.displayName).foregroundColor(.secondary) }
            HStack { Text("方式"); Spacer(); Text(session.method.rawValue).foregroundColor(.secondary) }
            Label("已连接主业务后端", systemImage: "checkmark.shield.fill")
                .foregroundColor(AppColor.stand)
            Button("退出当前会话", role: .destructive) {
                Task { await model.signOut() }
            }
            Button("退出全部设备", role: .destructive) {
                Task { await model.signOut(allSessions: true) }
            }
        }
    }

    private var credentialsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                Text(LocalizedStringKey(isRegistering ? "创建 MoveFit 账号" : "使用账号登录"))
                    .font(.title2.bold())
                Text(LocalizedStringKey(
                    isRegistering ? "填写账号信息后获取验证码。" : "输入手机号或邮箱及密码以继续。"
                ))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        Picker("账号类型", selection: $registration.kind) {
                            ForEach(AccountIdentifierKind.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("registrationKindPicker")
                        TextField(
                            registration.kind == .phone ? "+8613800000000" : "name@example.com",
                            text: $registration.identifier
                        )
                        .textContentType(registration.kind == .phone ? .telephoneNumber : .emailAddress)
                        .keyboardType(registration.kind == .phone ? .phonePad : .emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .identifier)
                        .accessibilityIdentifier("registrationIdentifierField")
                        .textFieldStyle(.roundedBorder)
                        SecureField("密码", text: $registration.password)
                            .textContentType(isRegistering ? .newPassword : .password)
                            .focused($focusedField, equals: .password)
                            .accessibilityIdentifier("registrationPasswordField")
                            .textFieldStyle(.roundedBorder)
                        if isRegistering {
                            Text("手机号需包含国家码，例如 +8613800000000。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("密码需 12–128 个字符。验证码仅由 MoveFit 后端发送和验证。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            registrationControls
                            if let message = registration.message {
                                Text(LocalizedStringKey(message))
                                    .font(.footnote)
                                    .foregroundColor(messageColor)
                                    .accessibilityIdentifier("registrationStatusMessage")
                            }
                        } else {
                            Button("登录") { submitLogin() }
                                .buttonStyle(.borderedProminent)
                                .tint(AppColor.primary)
                                .controlSize(.large)
                                .frame(maxWidth: .infinity)
                                .disabled(model.accountOperationInProgress || !canSubmitLogin)
                                .accessibilityIdentifier("accountSubmitButton")
                            if model.accountOperationInProgress {
                                ProgressView("正在登录…")
                            }
                        }
                        Button(isRegistering ? "已有账号？返回登录" : "没有账号？注册") {
                            toggleMode()
                        }
                        .accessibilityIdentifier("registrationModeButton")
                    }
                }
                privacySection
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var registrationControls: some View {
        switch registration.phase {
        case .idle:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = registration.remainingCooldownSeconds(at: context.date)
                VStack(alignment: .leading, spacing: 8) {
                    if remaining > 0 {
                        Text("\(remaining) 秒后可重新发送")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("registrationCooldownLabel")
                    }
                    Button("发送验证码") {
                        Task { await registration.requestCode() }
                    }
                    .disabled(remaining > 0 || registration.isBusy || !canRequestCode)
                    .accessibilityIdentifier("registrationSendCodeButton")
                }
            }
        case .requesting:
            Button("正在发送验证码…") {}
                .disabled(true)
                .accessibilityIdentifier("registrationSendCodeButton")
        case .codeEntry:
            TextField("六位验证码", text: $registration.code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focusedField, equals: .code)
                .accessibilityIdentifier("registrationCodeField")
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = registration.remainingCooldownSeconds(at: context.date)
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        remaining > 0
                            ? "\(remaining) 秒后可重新发送"
                            : "现在可以重新发送验证码"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("registrationCooldownLabel")
                    Button("重新发送验证码") {
                        Task { await registration.requestCode() }
                    }
                    .disabled(remaining > 0 || registration.isBusy)
                    .accessibilityIdentifier("registrationSendCodeButton")
                }
            }
            Button("验证并注册") {
                Task { await registration.completeRegistration() }
            }
            .disabled(registration.isBusy || registration.code.count != 6)
            .accessibilityIdentifier("registrationCompleteButton")
        case .confirming:
            ProgressView("正在验证验证码…")
        case .registering:
            ProgressView("正在创建账号…")
        case .completed:
            EmptyView()
        }
    }

    private var canSubmitLogin: Bool {
        !registration.identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !registration.password.isEmpty
    }

    private var canRequestCode: Bool {
        !registration.identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !registration.password.isEmpty
    }

    private var messageColor: Color {
        if registration.message == "验证码已请求，请检查对应的邮箱或手机号。" {
            return AppColor.stand
        }
        return .red
    }

    private func submitLogin() {
        Task {
            _ = await model.signIn(
                kind: registration.kind,
                identifier: registration.identifier,
                password: registration.password
            )
        }
    }

    private func toggleMode() {
        if isRegistering {
            registration.prepareForAnotherRegistration()
        }
        isRegistering.toggle()
    }
}
