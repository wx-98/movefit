import SwiftUI

struct SupportTicketComposerView: View {
    private struct Submission {
        let category: String
        let subject: String
        let message: String
    }

    @EnvironmentObject private var remote: RemoteFeatureViewModel
    @State private var category = "technical"
    @State private var subject = ""
    @State private var messageBody = ""
    @State private var operationID = UUID()
    @State private var createdTicketID: UUID?
    @State private var showCreatedTicket = false
    @State private var message: String?
    @State private var retrySubmission: Submission?

    private let categories: [(code: String, title: String)] = [
        ("account", "账号"), ("workout", "运动"), ("challenge", "挑战"),
        ("content", "内容"), ("privacy", "隐私"), ("technical", "技术问题"),
        ("other", "其他")
    ]

    var body: some View {
        Form {
            Section("问题类型") {
                Picker("分类", selection: $category) {
                    ForEach(categories, id: \.code) { item in
                        Text(item.title).tag(item.code)
                    }
                }
                .disabled(retrySubmission != nil)
            }
            Section("内容") {
                TextField("主题", text: $subject)
                    .disabled(retrySubmission != nil)
                    .accessibilityIdentifier("supportTicketSubjectField")
                TextEditor(text: $messageBody)
                    .disabled(retrySubmission != nil)
                    .frame(minHeight: 140)
                    .accessibilityIdentifier("supportTicketMessageField")
            }
            Section {
                Text("请勿提交验证码、密码、精确路线或健康明细。")
                    .font(.footnote).foregroundColor(.secondary)
                Button(retrySubmission == nil ? "提交工单" : "重试原工单请求") {
                    Task { await submit() }
                }
                    .disabled(remote.isWriting || subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("supportTicketSubmitButton")
                if retrySubmission != nil {
                    Button("编辑并作为新操作提交") {
                        retrySubmission = nil
                        operationID = UUID()
                    }
                }
            }
            if let createdTicketID {
                NavigationLink(
                    destination: SupportTicketDetailView(ticketID: createdTicketID),
                    isActive: $showCreatedTicket
                ) { Text("查看已创建工单") }
            }
        }
        .navigationTitle("创建支持工单")
        .alert("提交结果", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("知道了") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func submit() async {
        let submission = retrySubmission ?? Submission(
            category: category,
            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
            message: messageBody.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let result = await remote.createTicket(
            category: submission.category,
            subject: submission.subject,
            message: submission.message,
            operationID: operationID
        )
        if let result {
            retrySubmission = nil
            operationID = UUID()
            createdTicketID = result.ticket.id
            showCreatedTicket = true
        } else {
            retrySubmission = submission
            message = "服务端未确认工单提交，请检查网络后用原操作重试。"
        }
    }
}
