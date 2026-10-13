import SwiftUI

/// A smooth ribbon whose amplitude comes from the microphone envelope.
struct SoundWave: View {
    let values: [Double]
    var animate = true
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/15, paused: values.isEmpty || !animate)) { context in
            Canvas { canvas, size in
                let signal = values.suffix(12)
                let level = signal.isEmpty ? 0 : signal.reduce(0,+) / Double(signal.count)
                let phase = context.date.timeIntervalSinceReferenceDate * 1.3
                for layer in 0..<14 {
                    var path = Path()
                    for step in 0...120 {
                        let x = Double(step)/120
                        let envelope = pow(sin(.pi*x), 2)
                        let wave = sin(x * .pi * 3.4 - phase + Double(layer)*0.075)
                        let spread = Double(layer-7)*0.018
                        let y = size.height/2 + (wave+spread)*envelope*min(1,level)*size.height*0.75
                        let point = CGPoint(x:x*size.width,y:y)
                        if step == 0 { path.move(to:point) } else { path.addLine(to:point) }
                    }
                    canvas.stroke(path, with:.linearGradient(Gradient(colors:[.cyan.opacity(0.08), .init(red:0.65,green:0.88,blue:1), .init(red:1,green:0.95,blue:0.79), .cyan.opacity(0.08)]), startPoint:.zero,endPoint:CGPoint(x:size.width,y:0)),lineWidth:layer == 7 ? 1.8 : 0.7)
                }
            }
        }.accessibilityHidden(true)
    }
}

struct NightScreen: View {
    @EnvironmentObject var store: SleepStore
    @State private var editingTime = false
    private let ivory = Color(red:0.96,green:0.94,blue:0.87)
    var body: some View {
        ZStack {
            NightLandscape()
            GeometryReader { geo in
                VStack(spacing: 8) {
                    TimelineView(.periodic(from:.now,by:1)) { context in
                        Text(context.date.formatted(.dateTime.hour(.twoDigits(amPM:.omitted)).minute().locale(store.words.locale)))
                            .font(.system(size:76,weight:.light,design:.rounded)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.6).accessibilityIdentifier("night-current-time")
                            .accessibilityLabel(store.words("currentTime"))
                            .accessibilityValue(context.date.formatted(date:.omitted,time:.shortened))
                    }
                    if let night = store.archive.active {
                        if night.hasAlarm {
                            Button { editingTime = true } label: {
                                HStack(spacing:7) {
                                    Text(alarmLabel(night)).underline(color:ivory.opacity(0.55))
                                    Image(systemName:"chevron.down").font(.system(size:10,weight:.semibold))
                                }.font(.system(size:20,design:.serif)).lineLimit(1).minimumScaleFactor(0.65)
                                    .frame(minHeight:44).contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(store.ringing)
                                .accessibilityIdentifier("night-edit-alarm").accessibilityHint(store.words("changeAlarmTime"))
                        } else { Text(store.words("analysis")).font(.system(size:20,design:.serif)).frame(minHeight:44) }
                    }
                    Spacer()
                }.padding(.horizontal,24).padding(.top,20).frame(width:geo.size.width)
                NightRibbon(audio:store.audio).frame(width:max(0,geo.size.width-36),height:100)
                    .position(x:geo.size.width/2,y:geo.size.height*0.85)
                if store.ringing {
                    Button { Task { await store.snooze() } } label: {
                        Text(store.words("snooze") + " · \(store.archive.plan.snoozeMinutes) min")
                            .padding(16).background(.black.opacity(0.25),in:Capsule())
                    }.position(x:geo.size.width/2,y:geo.size.height*0.9)
                }
            }
        }.foregroundStyle(ivory)
            .safeAreaInset(edge:.bottom) {
                SwipeToFinish(words:store.words) { Task { await store.finish() } }.padding(.bottom,6)
            }
            .preferredColorScheme(.dark).interactiveDismissDisabled().disabled(store.busy)
            .sheet(isPresented:$editingTime) {
                if let night = store.archive.active {
                    ActiveAlarmEditor(date:night.editableAlarmTime)
                        .presentationDetents([.height(410),.large]).presentationDragIndicator(.visible)
                }
            }
            .onChange(of:store.ringing) { ringing in if ringing { editingTime = false } }
            .alert(store.words("error"),isPresented:Binding(get:{store.error != nil && !editingTime},set:{if !$0 && !editingTime {store.error = nil}})) {
                if store.writeFailed { Button(store.words("retrySave")) { Task { await store.retrySaving() } } }
                Button(store.words("done")) {store.error = nil}
            } message: {Text(store.error ?? "")}
    }
    private func alarmLabel(_ night: SleepSession) -> String {
        let time: (Date) -> String = { $0.formatted(.dateTime.hour(.twoDigits(amPM:.omitted)).minute().locale(store.words.locale)) }
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
                DatePicker(store.words("wake"),selection:$date,displayedComponents:.hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().accessibilityIdentifier("active-alarm-time")
                Text(next.formatted(.dateTime.weekday(.wide).day().month().hour().minute().locale(store.words.locale)))
                    .font(.subheadline).accessibilityIdentifier("active-alarm-date")
                Text(store.words("tonightOnly")).font(.caption).foregroundStyle(.secondary)
                if store.archive.active?.hasActiveSmartWindow == true { Text(store.words("activeWindowDeadline")).font(.caption).foregroundStyle(.secondary) }
                if saving { ProgressView() }
                Spacer(minLength:0)
            }.padding(.horizontal,24).padding(.top,12)
                .navigationTitle(store.words("alarmTime")).navigationBarTitleDisplayMode(.inline)
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
        }.preferredColorScheme(.dark).tint(Color(red:0.96,green:0.94,blue:0.87))
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
                    .frame(width:28,height:28).background(.white.opacity(0.12),in:Circle())
                    .frame(width:48,height:48).offset(y:-lift)
            }.frame(width:100,height:112).contentShape(Rectangle())
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
