import Foundation

struct Instance: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    let url: String
    let email: String
    var notifyWorkerURL: String?
    var notifyWebhookSecret: String?
}

extension Instance {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case url
        case email
        case notifyWorkerURL
        case notifyWebhookSecret
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            url: try container.decode(String.self, forKey: .url),
            email: try container.decode(String.self, forKey: .email),
            notifyWorkerURL: try container.decodeIfPresent(String.self, forKey: .notifyWorkerURL),
            notifyWebhookSecret: try container.decodeIfPresent(String.self, forKey: .notifyWebhookSecret)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(notifyWorkerURL, forKey: .notifyWorkerURL)
    }
}
