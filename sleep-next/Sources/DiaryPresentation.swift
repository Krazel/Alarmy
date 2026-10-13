import SwiftUI

enum DiaryPresentation {
    static let keys = ["awake", "core", "deep", "rem", "asleep"]
    static func color(_ key: String) -> Color {
        switch key {
        case "awake": return Color(red:0.73,green:0.70,blue:0.85)
        case "deep": return Color(red:0.28,green:0.44,blue:0.46)
        case "rem": return Color(red:0.49,green:0.68,blue:0.82)
        default: return Color(red:0.64,green:0.76,blue:0.66)
        }
    }
    static func duration(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite else { return "—" }
        let minutes = max(0,Int(seconds/60))
        return minutes >= 60 ? "\(minutes/60) h \(String(format:"%02d",minutes%60))" : "\(minutes) min"
    }
    static func clipTime(_ seconds: Double) -> String {
        let value = seconds.isFinite ? max(0,Int(seconds)) : 0
        return String(format:"%02d:%02d",value/60,value%60)
    }
    // Count only observed transitions from sleep into awake and back into sleep.
    // Missing intervals, initial latency and final waking are not awakenings.
    static func awakenings(_ stages: [SleepStage]) -> Int? {
        let values = HealthReader.normalize(stages)
        guard values.contains(where: { $0.key != "awake" }) else { return nil }
        return values.indices.filter { i in
            i > 0 && i+1 < values.count && values[i].key == "awake" &&
            values[i-1].key != "awake" && values[i+1].key != "awake" &&
            values[i-1].end == values[i].start && values[i].end == values[i+1].start
        }.count
    }
    #if DEBUG
    static func fixtureStages(_ night: SleepSession) -> [SleepStage] {
        let keys = ["awake","core","deep","core","rem","core","deep","core","awake","core","rem","core"]
        let weights: [Double] = [3,9,12,7,8,10,9,8,2,10,12,10]
        var start = night.start
        return zip(keys,weights).map { key,weight in
            let end = start.addingTimeInterval(night.duration*weight/100)
            defer { start = end }
            return SleepStage(id:UUID(),start:start,end:end,key:key)
        }
    }
    #endif
}

struct CompactMetric: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment:.leading,spacing:4) {
            Text(value).font(.system(size:23,design:.serif)).lineLimit(1).minimumScaleFactor(0.65).monospacedDigit()
            Text(title).font(.system(size:11)).foregroundStyle(Color.ink.opacity(0.6)).fixedSize(horizontal:false,vertical:true)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}

struct StageChart: View {
    let stages: [SleepStage]
    let words: Words
    @State private var selected: SleepStage?
    var body: some View {
        VStack(spacing:4) {
            GeometryReader { geometry in
            Canvas { context,size in
                guard let start = stages.map(\.start).min(), let end = stages.map(\.end).max(), end > start else { return }
                let total = end.timeIntervalSince(start)
                for stage in stages {
                    let level: CGFloat = stage.key == "awake" ? 0 : (stage.key == "rem" ? 1 : (stage.key == "deep" ? 3 : 2))
                    let rect = CGRect(x:stage.start.timeIntervalSince(start)/total*size.width,y:level*12,width:stage.end.timeIntervalSince(stage.start)/total*size.width,height:13)
                    context.fill(Path(roundedRect:rect,cornerRadius:2),with:.color(DiaryPresentation.color(stage.key)))
                }
            }.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:0).onChanged { gesture in
                guard let start = stages.map(\.start).min(), let end = stages.map(\.end).max(), geometry.size.width > 0 else { return }
                let date = start.addingTimeInterval(min(1,max(0,gesture.location.x/geometry.size.width))*end.timeIntervalSince(start))
                selected = stages.first { $0.start <= date && $0.end > date }
            })
            }.frame(height:50).accessibilityLabel(words("stagesHealth"))
            if let selected {
                Text(words(selected.key) + " · " + selected.start.formatted(date:.omitted,time:.shortened) + "–" + selected.end.formatted(date:.omitted,time:.shortened)).font(.caption2)
            }
            if let start = stages.map(\.start).min(), let end = stages.map(\.end).max() {
                HStack { Text(start,style:.time); Spacer(); Text(end,style:.time) }.font(.system(size:10)).foregroundStyle(Color.ink.opacity(0.6))
            }
        }
    }
}

struct StageDurations: View {
    let stages: [SleepStage]
    let nights: [SleepSession]
    let words: Words
    var body: some View {
        LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:7) {
            ForEach(DiaryPresentation.keys.filter { key in stages.contains { $0.key == key } },id:\.self) { key in
                HStack(spacing:5) {
                    Circle().fill(DiaryPresentation.color(key)).frame(width:9,height:9)
                    Text(words(key)); Spacer(minLength:2)
                    let seconds = NightMetrics(nights:nights).healthSeconds(stages,key:key) ?? 0
                    let total = SleepMath.seconds(stages.map { DateInterval(start:$0.start,end:$0.end) })
                    Text(DiaryPresentation.duration(seconds) + " · \(Int(seconds/max(1,total)*100))%").monospacedDigit().accessibilityLabel(DiaryPresentation.duration(seconds) + " · \(Int(seconds/max(1,total)*100))% " + words("stageShare"))
                }.font(.system(size:10))
            }
        }
    }
}

struct SoundSummaryRow: View {
    let nights: [SleepSession]
    let words: Words
    var body: some View {
        PaperCard(padding:13) {
            HStack(spacing:12) {
                Image(systemName:"waveform").font(.title2)
                VStack(alignment:.leading,spacing:3) {
                    Text(words("sounds")).font(.system(size:18,design:.serif))
                    Text("\(NightMetrics(nights:nights).soundCount) " + words("soundEvents") + " · " + DiaryPresentation.duration(NightMetrics(nights:nights).recordedSeconds)).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                }
                Spacer(); Image(systemName:"chevron.right").font(.caption)
            }.foregroundStyle(Color.ink)
        }
    }
}
