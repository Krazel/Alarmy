import ActivityKit
import SwiftUI
import WidgetKit

@main
struct AlarmaLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        AlarmaLiveActivityWidget()
    }
}

struct AlarmaLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmActivityAttributes.self) { context in
            LockScreenAlarmActivityView(state: context.state)
                .activityBackgroundTint(context.state.isRinging ? Color(red: 0.86, green: 0.34, blue: 0.20) : Color(red: 0.15, green: 0.10, blue: 0.08))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.isRinging ? "Sonando" : "Activa", systemImage: context.state.isRinging ? "bell.fill" : "moon.stars.fill")
                        .font(.headline.weight(.black))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.timeText)
                        .font(.title2.weight(.black))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.label)
                        .font(.caption.weight(.bold))
                }
            } compactLeading: {
                Image(systemName: context.state.isRinging ? "bell.fill" : "moon.stars.fill")
            } compactTrailing: {
                Text(context.state.timeText)
                    .font(.caption2.weight(.black))
            } minimal: {
                Image(systemName: context.state.isRinging ? "bell.fill" : "moon.fill")
            }
        }
    }
}

struct LockScreenAlarmActivityView: View {
    let state: AlarmActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                Image(systemName: state.isRinging ? "bell.fill" : "moon.stars.fill")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(state.statusText)
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.white.opacity(0.78))
                Text(state.label)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()

            Text(state.timeText)
                .font(.system(size: 34, weight: .black, design: .serif))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}
