import Foundation

struct RemotePage<Item> {
    let items: [Item]
    let nextCursor: String?
    let hasMore: Bool
}
