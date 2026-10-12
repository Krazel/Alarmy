import SwiftUI

struct SoundWave: View {
    let values: [Double]
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let samples = Array(repeating: 0.0, count: max(0,64-values.count)) + values.suffix(64)
                for (index,value) in samples.enumerated() {
                    let x = CGFloat(index) / 63 * geo.size.width
                    let amplitude = max(1,CGFloat(value)*geo.size.height*0.45)
                    path.move(to: CGPoint(x:x,y:geo.size.height/2-amplitude))
                    path.addLine(to: CGPoint(x:x,y:geo.size.height/2+amplitude))
                }
            }.stroke(Color(red:0.7,green:0.86,blue:0.92),style:StrokeStyle(lineWidth:2,lineCap:.round))
        }.accessibilityHidden(true)
    }
}

struct NightScreen: View {
    @EnvironmentObject var store: SleepStore
    var body: some View {
        ZStack {
            NightLandscape()
            ScrollView {
                VStack(spacing:22) {
                    Image(systemName:store.ringing ? "sun.max" : "moon.stars").font(.system(size:30,weight:.ultraLight)).padding(.top,28)
                    Text(store.words(store.ringing ? "morning" : (store.archive.active?.hasAlarm == false ? "yourPace" : "goodnight")))
                        .font(.system(size:34,design:.serif)).multilineTextAlignment(.center)
                    if let night = store.archive.active {
                        Text(store.words((night.mode ?? .exact).rawValue)).font(.caption).tracking(2).textCase(.uppercase)
                        if !night.hasAlarm {
                            TimelineView(.periodic(from:.now,by:1)) { context in
                                Text(SleepMath.duration(context.date.timeIntervalSince(night.start))).font(.system(size:48,weight:.ultraLight,design:.rounded)).monospacedDigit()
                            }
                            Text(store.words("inBed")).font(.caption)
                        } else if let start = night.windowStart, let end = night.latestWake, night.smartTriggered != true {
                            HStack(spacing:6) { Text(start,style:.time); Text("–"); Text(end,style:.time) }
                                .font(.system(size:38,weight:.ultraLight,design:.rounded)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                            HStack { Text(store.words("latestWake")); Text(end,style:.time) }.font(.caption)
                        } else {
                            Text(night.wake,style:.time).font(.system(size:64,weight:.ultraLight,design:.rounded)).monospacedDigit()
                            if night.smartTriggered == true { Text(store.words("acousticWake")).font(.caption) }
                        }
                        CapturePanel(audio:store.audio)
                    }
                    if store.ringing {
                        Button { Task { await store.snooze() } } label: { Text(store.words("snooze") + " · \(store.archive.plan.snoozeMinutes) min") }.buttonStyle(PrimaryButton())
                    }
                }.padding(.horizontal,28).padding(.bottom,20)
            }.scrollIndicators(.hidden)
        }.foregroundStyle(Color(red:0.96,green:0.92,blue:0.83))
            .safeAreaInset(edge:.bottom) {
                SwipeToFinish(words:store.words) { Task { await store.finish() } }.padding(.bottom,8)
            }
            .preferredColorScheme(.dark).interactiveDismissDisabled().disabled(store.busy)
            .alert(store.words("error"),isPresented:Binding(get:{store.error != nil},set:{if !$0 {store.error = nil}})) {
                if store.writeFailed { Button(store.words("retrySave")) { Task { await store.retrySaving() } } }
                Button(store.words("done")) {store.error = nil}
            } message: {Text(store.error ?? "")}
    }
}

struct SwipeToFinish: View {
    let words: Words
    let finish: () -> Void
    @State private var lift: CGFloat = 0
    @State private var submitted = false
    var body: some View {
        VStack(spacing:8) {
            ZStack(alignment:.bottom) {
                Capsule().fill(.black.opacity(0.24)).overlay(Capsule().stroke(.white.opacity(0.22))).frame(width:64,height:148)
                Image(systemName:"chevron.up.chevron.up").font(.caption).opacity(0.6).offset(y:-107)
                Image(systemName:"sun.horizon.fill").font(.title3).foregroundStyle(Color(red:0.2,green:0.3,blue:0.4))
                    .frame(width:54,height:54).background(Color(red:0.94,green:0.91,blue:0.83),in:Circle()).padding(.bottom,5).offset(y:-lift)
            }.frame(width:110,height:148).contentShape(Rectangle())
                .highPriorityGesture(DragGesture(minimumDistance:8)
                    .onChanged { value in guard !submitted else { return }; lift = min(88,max(0,-value.translation.height)) }
                    .onEnded { value in
                        guard !submitted else { return }
                        if -value.translation.height >= 80 { submitted = true; finish() }
                        else { withAnimation(.easeOut(duration:0.2)) { lift = 0 } }
                    })
                .accessibilityElement(children:.ignore).accessibilityLabel(words("swipeFinish"))
                .accessibilityIdentifier("finish-night")
                .accessibilityAction(named:Text(words("end"))) { finish() }
            Text(words(lift > 10 ? "keepSliding" : "swipeFinish")).font(.caption).multilineTextAlignment(.center)
        }.padding(.horizontal,24)
        // A persistence failure leaves this screen open and allows another attempt.
        .onChange(of: submitted) { value in if value { DispatchQueue.main.asyncAfter(deadline:.now()+2) { submitted = false; lift = 0 } } }
    }
}
