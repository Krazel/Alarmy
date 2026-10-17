import SwiftUI

/// A smooth ribbon whose amplitude comes from the microphone envelope.
struct SoundWave: View {
    let values: [Double]
    var animate = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var envelope = WaveEnvelope()
    private var input: Double { let recent = values.suffix(4); return recent.isEmpty ? 0 : recent.reduce(0,+)/Double(recent.count) }
    var body: some View {
        TimelineView(.animation(minimumInterval:1.0/60,paused:values.isEmpty || !animate || reduceMotion || scenePhase != .active)) { context in
            Canvas { canvas, size in
                let time = context.date.timeIntervalSinceReferenceDate
                let level = animate && !reduceMotion ? envelope.level(at:time) : input
                let phase = reduceMotion ? 0 : time*1.3
                let gradient = GraphicsContext.Shading.linearGradient(Gradient(colors:[.cyan.opacity(0.08), .init(red:0.65,green:0.88,blue:1), .init(red:1,green:0.95,blue:0.79), .cyan.opacity(0.08)]),startPoint:.zero,endPoint:CGPoint(x:size.width,y:0))
                for layer in 0..<12 {
                    var path = Path()
                    for step in 0...100 {
                        let x = Double(step)/100
                        let y = size.height/2 + WaveMotion.offset(x:x,phase:phase,layer:layer,level:level,height:size.height)
                        let point = CGPoint(x:x*size.width,y:y)
                        if step == 0 { path.move(to:point) } else { path.addLine(to:point) }
                    }
                    canvas.stroke(path,with:gradient,lineWidth:layer == 6 ? 1.8 : 0.7)
                }
            }
        }.onAppear { envelope.update(input,at:Date().timeIntervalSinceReferenceDate) }
            .onChange(of:input) { level in envelope.update(level,at:Date().timeIntervalSinceReferenceDate) }
            .accessibilityHidden(true)
    }
}

struct NightScreen: View {
    @EnvironmentObject var store: SleepStore
    @State private var editingTime = false
    private let ivory = Color(red:0.96,green:0.94,blue:0.87)
    var body: some View {
        ZStack {
            if store.ringing {
                GeometryReader { geo in
                    Image("DawnArtwork").resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped()
                        .overlay(LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.15), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                }.ignoresSafeArea().accessibilityHidden(true)
            } else { NightLandscape() }
            GeometryReader { geo in
                VStack(spacing: 12) {
                    Spacer(minLength: 12)
                    if store.ringing { Text(store.words("goodMorning")).font(.system(size: 28, design: .serif)) }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(context.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(store.words.locale)))
                            .font(.system(size: 84, weight: .regular, design: .serif)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.6).accessibilityIdentifier("night-current-time")
                            .accessibilityLabel(store.words("currentTime"))
                    }
                    if let night = store.archive.active, !store.ringing {
                        if night.hasAlarm {
                            Button { editingTime = true } label: {
                                HStack(spacing: 7) {
                                    Text(alarmLabel(night)).underline(color: ivory.opacity(0.55))
                                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                                }.font(.system(size: 19)).lineLimit(1).minimumScaleFactor(0.65).frame(minHeight: 44)
                            }.buttonStyle(.plain).accessibilityIdentifier("night-edit-alarm").accessibilityHint(store.words("changeAlarmTime"))
                        } else { Text(store.words("analysis")).font(.system(size: 19)).frame(minHeight: 44) }
                    }
                    Spacer(minLength: 24)
                    if !store.ringing { NightRibbon(audio: store.audio).frame(height: 100) }
                    Spacer(minLength: 24)
                    if store.ringing {
                        if let night = store.archive.active {
                            HStack(spacing: 14) {
                                Image("DawnArtwork").resizable().scaledToFill().frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(store.archive.tones.first { $0.id == night.soundID }?.name ?? night.soundID.capitalized).font(.system(size: 20, design: .serif))
                                    Text(store.words("music")).font(.caption).opacity(0.7)
                                }
                                Spacer()
                            }.padding(.bottom, 18)
                        }
                        Button { Task { await store.snooze() } } label: {
                            Text(store.words("snooze") + " · \(store.archive.plan.snoozeMinutes) min")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 20).background(.ultraThinMaterial, in: Capsule())
                        }.accessibilityIdentifier("snooze-night")
                    }
                }.padding(.horizontal, 30).padding(.bottom, 10).frame(width: geo.size.width, height: geo.size.height)
            }
        }.foregroundStyle(ivory)
            .safeAreaInset(edge:.bottom) {
                SwipeToFinish(words:store.words) { Task { await store.finish() } }.padding(.bottom,6)
            }
            .preferredColorScheme(.dark).interactiveDismissDisabled().disabled(store.busy)
            .sheet(isPresented:$editingTime) {
                if let night = store.archive.active {
                    ActiveAlarmEditor(date:night.editableAlarmTime)
                        .presentationDetents([.height(500),.large]).presentationDragIndicator(.visible)
                }
            }
            .onChange(of:store.ringing) { ringing in if ringing { editingTime = false } }
            .alert(store.words("error"),isPresented:Binding(get:{store.error != nil && !editingTime},set:{if !$0 && !editingTime {store.error = nil}})) {
                if store.writeFailed { Button(store.words("retrySave")) { Task { await store.retrySaving() } } }
                Button(store.words("done")) {store.error = nil}
            } message: {Text(store.error ?? "")}
    }
    private func alarmLabel(_ night: SleepSession) -> String {
        let time: (Date) -> String = { $0.formatted(.dateTime.hour(.twoDigits(amPM:.omitted)).minute(.twoDigits).locale(store.words.locale)) }
        if let start = night.windowStart, let end = night.latestWake, night.smartTriggered != true {
            return store.words("alarm") + " · " + time(start) + " – " + time(end)
        }
        return store.words("alarm") + " · " + time(night.wake)
    }
}

private struct NightRibbon: View {
    @EnvironmentObject var store: SleepStore
    @ObservedObject var audio: NightAudio
    var body: some View {
        VStack(spacing:12) {
            SoundWave(values:audio.waveform,animate:!store.testMode).frame(height:76).accessibilityIdentifier("night-wave")
            // Quiet normal operation has no microphone control. A genuine interruption
            // must remain visible and recoverable, without pretending to keep listening.
            if !store.ringing && audio.waveform.isEmpty && !audio.isRecording && !store.testMode {
                if store.archive.preferences.analysisEnabled {
                    Text(store.words(audio.captureState)).font(.caption).multilineTextAlignment(.center)
                    Button { Task { await store.resumeCapture() } } label: { Text(store.words("resumeCapture")).underline() }
                        .font(.caption).accessibilityIdentifier("resume-capture")
                } else { Text(store.words("analysisDisabled")).font(.caption).opacity(0.7) }
            }
        }
    }
}

struct ActiveAlarmEditor: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.dismiss) private var dismiss
    @State var date: Date
    @State private var saving = false
    private var next: Date {
        var plan = AlarmPlan(); let components = Calendar.current.dateComponents([.hour,.minute],from:date)
        plan.hour = components.hour ?? 7; plan.minute = components.minute ?? 30
        return plan.next(after:Date()) ?? date
    }
    var body: some View {
        NavigationStack {
            VStack(spacing:8) {
                PageHeading(title: store.words("alarmTime"), subtitle: store.words("tonightOnly"))
                DatePicker(store.words("wake"),selection:$date,displayedComponents:.hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().accessibilityIdentifier("active-alarm-time")
                Text(next.formatted(.dateTime.weekday(.wide).day().month().hour().minute().locale(store.words.locale)))
                    .font(.subheadline).accessibilityIdentifier("active-alarm-date")
                if store.archive.active?.hasActiveSmartWindow == true { Text(store.words("activeWindowDeadline")).font(.caption).foregroundStyle(.secondary) }
                if saving { ProgressView() }
                Spacer(minLength:0)
            }.padding(.horizontal,24).padding(.top,12)
                .background(Color.paper).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.cancellationAction) { Button(store.words("cancel")) { dismiss() }.accessibilityIdentifier("cancel-active-alarm") }
                    ToolbarItem(placement:.confirmationAction) {
                        Button(store.words("save")) {
                            let c = Calendar.current.dateComponents([.hour,.minute],from:date)
                            saving = true
                            Task {
                                let saved = await store.changeActiveAlarm(hour:c.hour ?? 7,minute:c.minute ?? 30)
                                saving = false
                                if saved { dismiss() }
                            }
                        }.accessibilityIdentifier("save-active-alarm")
                    }
                }.disabled(saving).interactiveDismissDisabled(saving)
                .alert(store.words("error"),isPresented:Binding(get:{store.error != nil},set:{if !$0 {store.error = nil}})) {
                    if store.writeFailed { Button(store.words("retrySave")) { Task { await store.retrySaving() } } }
                    Button(store.words("done")) { store.error = nil }
                } message: { Text(store.error ?? "") }
        }.preferredColorScheme(.light).foregroundStyle(Color.ink).tint(.rust)
    }
}

struct SwipeToFinish: View {
    let words: Words
    let finish: () -> Void
    @State private var lift: CGFloat = 0
    @State private var submitted = false
    var body: some View {
        VStack(spacing:0) {
            ZStack(alignment:.bottom) {
                Color.clear
                Image(systemName:"chevron.up").font(.system(size:13,weight:.medium))
                    .frame(width:28,height:28)
                    .frame(width:48,height:48).offset(y:-lift)
            }.frame(width:100,height:80).contentShape(Rectangle())
                .highPriorityGesture(DragGesture(minimumDistance:8)
                    .onChanged { value in guard !submitted else { return }; lift = min(80,max(0,-value.translation.height)) }
                    .onEnded { value in
                        guard !submitted else { return }
                        if -value.translation.height >= 64 { submitted = true; finish() }
                        else { withAnimation(.easeOut(duration:0.2)) { lift = 0 } }
                    })
                .accessibilityElement(children:.ignore).accessibilityLabel(words("swipeFinish"))
                .accessibilityIdentifier("finish-night")
                .accessibilityAction(named:Text(words("stop"))) { finish() }
            Text(words("stop")).font(.system(size:15,design:.serif))
        }.padding(.horizontal,24)
        .onChange(of:submitted) { value in if value { DispatchQueue.main.asyncAfter(deadline:.now()+2) { submitted = false; lift = 0 } } }
    }
}
