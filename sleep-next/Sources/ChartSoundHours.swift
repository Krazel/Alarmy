import SwiftUI
import Charts

struct ChartSoundHours: View {
    let clips: [NightClip]
    let words: Words
    private var hours: [Int:Int] { Dictionary(grouping:clips,by:{Calendar.current.component(.hour,from:$0.created)}).mapValues(\.count) }
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            Chart(Array(0..<24),id:\.self) { hour in
                BarMark(x:.value(words("hour"),hour),y:.value(words("savedClips"),hours[hour] ?? 0)).foregroundStyle(Color.rust)
            }.frame(height:120).chartXScale(domain:0...23).chartXAxis {AxisMarks(values:[0,6,12,18,23])}
            Text(words("soundScheduleHint")).font(.caption2).foregroundStyle(.secondary)
        }.padding(.top,10)
    }
}
