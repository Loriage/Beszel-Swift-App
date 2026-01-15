import Foundation

struct AlertDetail: Identifiable, Hashable, Sendable {
    enum UserInfoKey {
        static let alertHistoryId = "alertHistoryId"
        static let systemId = "alertSystemId"
        static let systemName = "alertSystemName"
        static let name = "alertName"
        static let value = "alertValue"
        static let created = "alertCreated"
        static let resolved = "alertResolved"
    }

    let id: String
    let systemId: String
    let systemName: String?
    let name: String
    let value: Double?
    let resolved: String?
    let created: Date

    init(alert: AlertHistoryRecord, systemName: String?) {
        self.id = alert.id
        self.systemId = alert.system
        self.systemName = systemName
        self.name = alert.name
        self.value = alert.value
        self.resolved = alert.resolved
        self.created = alert.created
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard let id = userInfo[UserInfoKey.alertHistoryId] as? String,
              let systemId = userInfo[UserInfoKey.systemId] as? String,
              let name = userInfo[UserInfoKey.name] as? String
        else {
            return nil
        }

        let createdInterval = (userInfo[UserInfoKey.created] as? NSNumber)?.doubleValue
        guard let createdInterval else {
            return nil
        }

        let valueNumber = userInfo[UserInfoKey.value] as? NSNumber
        let resolvedString = userInfo[UserInfoKey.resolved] as? String
        let cleanedResolved = resolvedString?.isEmpty == true ? nil : resolvedString

        self.id = id
        self.systemId = systemId
        self.systemName = userInfo[UserInfoKey.systemName] as? String
        self.name = name
        self.value = valueNumber?.doubleValue
        self.resolved = cleanedResolved
        self.created = Date(timeIntervalSince1970: createdInterval)
    }

    func userInfoPayload() -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [
            UserInfoKey.alertHistoryId: id,
            UserInfoKey.systemId: systemId,
            UserInfoKey.name: name,
            UserInfoKey.created: created.timeIntervalSince1970
        ]

        if let systemName {
            userInfo[UserInfoKey.systemName] = systemName
        }
        if let value {
            userInfo[UserInfoKey.value] = value
        }
        if let resolved {
            userInfo[UserInfoKey.resolved] = resolved
        }

        return userInfo
    }

    func withSystemName(_ systemName: String?) -> AlertDetail {
        AlertDetail(
            id: id,
            systemId: systemId,
            systemName: systemName,
            name: name,
            value: value,
            resolved: resolved,
            created: created
        )
    }

    private init(id: String, systemId: String, systemName: String?, name: String, value: Double?, resolved: String?, created: Date) {
        self.id = id
        self.systemId = systemId
        self.systemName = systemName
        self.name = name
        self.value = value
        self.resolved = resolved
        self.created = created
    }
}

extension AlertDetail {
    var alertType: AlertType {
        AlertType(rawValue: name) ?? .status
    }

    var displayName: String {
        alertType.displayName
    }

    var triggeredValueDescription: String {
        guard let val = value else { return "-" }
        return alertType.formatValue(val)
    }

    var isResolved: Bool {
        !(resolved ?? "").isEmpty
    }
}
