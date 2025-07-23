import Foundation

struct ResolvedPinnedItem: Identifiable, Hashable {
    let item: PinnedItem
    let systemID: String

    var id: String {
        "\(systemID)-\(item.id)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ResolvedPinnedItem, rhs: ResolvedPinnedItem) -> Bool {
        lhs.id == rhs.id
    }
}
