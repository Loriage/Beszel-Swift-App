import WidgetKit

extension WidgetFamily {
    var isLockScreen: Bool {
        switch self {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            return true
        default:
            return false
        }
    }
}
