import ActivityKit

@available(iOS 16.1, *)
struct AlarmActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var label: String
        var timeText: String
        var statusText: String
        var isRinging: Bool
    }

    var alarmId: String
}
