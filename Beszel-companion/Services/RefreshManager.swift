import Foundation
import Combine

class RefreshManager: ObservableObject {
    @Published var refreshSignal = Date()
    
    private var timerCancellable: AnyCancellable?
    
    func adjustTimer(for timeRange: TimeRangeOption) {
        timerCancellable?.cancel()
        
        let interval: TimeInterval
        switch timeRange {
        case .lastHour:
            interval = 60
        case .last12Hours:
            interval = 30 * 60
        case .last24Hours, .last7Days, .last30Days:
            interval = 60 * 60
        }
        
        timerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] newDate in
                self?.refreshSignal = newDate
            }
    }
}
