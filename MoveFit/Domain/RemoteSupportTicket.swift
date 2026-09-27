import Foundation

struct RemoteSupportTicket: Identifiable {
    let id: UUID
    let category: String
    let subject: String
    let status: String
    let version: Int
    let createdAt: Date
    let updatedAt: Date
    let closedAt: Date?
}

struct RemoteSupportMessage: Identifiable {
    let id: UUID
    let sequence: Int
    let authorRole: String
    let body: String
    let createdAt: Date
}

struct RemoteSupportTicketDetail {
    let ticket: RemoteSupportTicket
    let messages: [RemoteSupportMessage]
}

struct RemoteSupportTicketReply {
    let ticket: RemoteSupportTicket
    let message: RemoteSupportMessage
}
