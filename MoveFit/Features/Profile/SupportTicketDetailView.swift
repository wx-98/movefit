import SwiftUI

struct SupportTicketDetailView: View {
    @EnvironmentObject private var remote: RemoteFeatureViewModel
    let ticketID: UUID

    @State private var detail: RemoteSupportTicketDetail?
    @State private var replyBody = ""
    @State private var replyOperationID = UUID()
    @State private var pendingReplyBody: String?
    @State private var closeOperationID = UUID()
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        List {
            if let detail {
                Section("工单") {
                    Text(detail.ticket.subject).font(.headline)
                    Text("状态：\(detail.ticket.status)")
                    Text("创建于 \(detail.ticket.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundColor(.secondary)
                }
                Section("消息") {
                    ForEach(detail.messages) { item in
                        VStack(alignment: .leading, spacing: AppSpacing.tiny) {
                            Text(item.authorRole).font(.caption.bold())
                            Text(item.body).font(.body)
                            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
                if detail.ticket.status != "closed" {
                    Section("回复") {
                        TextEditor(text: $replyBody)
                            .frame(minHeight: 100)
                            .disabled(pendingReplyBody != nil)
                            .accessibilityIdentifier("supportTicketReplyField")
                        Button(pendingReplyBody == nil ? "发送回复" : "重试原回复") {
                            Task { await sendReply() }
                        }
                            .disabled(remote.isWriting || replyBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if pendingReplyBody != nil {
                            Button("编辑并作为新回复发送") {
                                pendingReplyBody = nil
                                replyOperationID = UUID()
                            }
                        }
                        Button("关闭工单", role: .destructive) { Task { await close() } }
                            .disabled(remote.isWriting)
                    }
                }
            } else if isLoading {
                ProgressView("正在读取工单…")
            } else {
                Text("工单暂不可用，请检查网络后重试。")
                Button("重试") { Task { await load() } }
            }
        }
        .navigationTitle("支持工单")
        .task { await load() }
        .alert("操作结果", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("知道了") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await remote.ticket(id: ticketID)
        } catch {
            detail = nil
            message = "无法读取工单，请检查网络后重试。"
        }
    }

    private func sendReply() async {
        let replyText = pendingReplyBody ?? replyBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = await remote.reply(
            ticketID: ticketID,
            message: replyText,
            operationID: replyOperationID
        )
        if result != nil {
            pendingReplyBody = nil
            replyOperationID = UUID()
            replyBody = ""
            await load()
        } else {
            pendingReplyBody = replyText
            message = "服务端未确认回复，请检查网络后用原操作重试。"
        }
    }

    private func close() async {
        if await remote.close(ticketID: ticketID, operationID: closeOperationID) {
            closeOperationID = UUID()
            await load()
        } else {
            message = "服务端未确认关闭，请检查网络后用原操作重试。"
        }
    }
}
