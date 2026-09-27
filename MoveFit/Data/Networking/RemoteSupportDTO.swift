import Foundation

enum RemoteSupportDTO {
    struct Ticket: Decodable {
        let ticketId: UUID
        let category: String
        let subject: String
        let status: String
        let version: Int
        let createdAt: String
        let updatedAt: String
        let closedAt: String?

        func domain() throws -> RemoteSupportTicket {
            guard let createdAt = BackendDateParser.date(from: createdAt),
                  let updatedAt = BackendDateParser.date(from: updatedAt) else {
                throw BackendError.invalidResponse
            }
            let closedDate: Date?
            if let closedAt {
                guard let parsed = BackendDateParser.date(from: closedAt) else {
                    throw BackendError.invalidResponse
                }
                closedDate = parsed
            } else {
                closedDate = nil
            }
            return RemoteSupportTicket(
                id: ticketId,
                category: category,
                subject: subject,
                status: status,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                closedAt: closedDate
            )
        }
    }

    struct Message: Decodable {
        let messageId: UUID
        let sequence: Int
        let authorRole: String
        let body: String
        let createdAt: String

        func domain() throws -> RemoteSupportMessage {
            guard let createdAt = BackendDateParser.date(from: createdAt) else {
                throw BackendError.invalidResponse
            }
            return RemoteSupportMessage(
                id: messageId,
                sequence: sequence,
                authorRole: authorRole,
                body: body,
                createdAt: createdAt
            )
        }
    }

    struct Created: Decodable {
        let ticket: Ticket
        let firstMessage: Message

        func domain() throws -> RemoteSupportTicketDetail {
            RemoteSupportTicketDetail(ticket: try ticket.domain(), messages: [try firstMessage.domain()])
        }
    }

    struct Detail: Decodable {
        let ticket: Ticket
        let messages: [Message]

        func domain() throws -> RemoteSupportTicketDetail {
            RemoteSupportTicketDetail(
                ticket: try ticket.domain(),
                messages: try messages.map { try $0.domain() }
            )
        }
    }

    struct CreateRequest: Encodable {
        let category: String
        let subject: String
        let message: String
    }

    struct ReplyRequest: Encodable {
        let message: String
    }

    struct Reply: Decodable {
        let ticket: Ticket
        let message: Message

        func domain() throws -> RemoteSupportTicketReply {
            RemoteSupportTicketReply(ticket: try ticket.domain(), message: try message.domain())
        }
    }

    struct Closed: Decodable {
        let ticket: Ticket
    }
}
