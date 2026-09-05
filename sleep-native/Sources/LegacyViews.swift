import SwiftUI
import AVFoundation
import MediaPlayer
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var session: NightSession
    @EnvironmentObject private var dreams: DreamStore
    @EnvironmentObject private var navigation: AppNavigation
    @Environment(\.scenePhase) private var scenePhase
    @State private var editingSleepAlarm = false

    var body: some View {
        ZStack {
            SleepBackdrop(theme: store.sleepTheme)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 56)

                AlarmHeroCard(
                    alarm: store.sleepAlarm,
                    theme: store.sleepTheme,
                    onAdjust: adjustSleepAlarm,
                    onEdit: { editingSleepAlarm = true }
                )
                .padding(.top, 30)

                Spacer()

                Button {
                    session.start(
                        alarm: store.sleepAlarm,
                        dreamStore: dreams,
                        recordAudio: store.sleepRecordingEnabled,
                        soundRetentionDays: store.nightSoundRetention.days
                    )
                } label: {
                    Label(L("Empezar la noche"), systemImage: "moon.stars.fill")
                        .font(.title3.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 66)
                        .background(
                            LinearGradient(colors: [store.sleepTheme.primary.opacity(0.92), store.sleepTheme.primary.opacity(0.74)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: store.sleepTheme.primary.opacity(0.30), radius: 18, x: 0, y: 10)
                }
                .accessibilityIdentifier("start-night")
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $editingSleepAlarm) {
            EditAlarmView(
                alarm: store.sleepAlarm,
                theme: store.sleepTheme,
                onSave: { updated in store.updateSleepAlarm(updated) },
                onDelete: nil
            )
        }
        .fullScreenCover(isPresented: Binding(get: { session.isActive || session.ringingAlarm != nil }, set: { if !$0 { session.stop() } })) {
            if let alarm = session.ringingAlarm {
                RingView(alarm: alarm, theme: store.sleepTheme, onFinish: finishAlarm)
            } else if let alarm = session.activeAlarm {
                NightActiveView(onFinish: finishAlarm, alarm: alarm, theme: store.sleepTheme)
            }
        }
        .preferredColorScheme(store.sleepTheme == .night ? .dark : .light)
        .statusBarHidden(false)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(store.sleepTheme.title)
                    .font(.system(size: 46, weight: .bold, design: .serif))
                    .foregroundStyle(store.sleepTheme.text)
                    .minimumScaleFactor(0.75)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    store.appearance = store.sleepTheme == .sunset ? .dark : .light
                }
            } label: {
                Image(systemName: store.sleepTheme == .sunset ? "moon.stars.fill" : "sun.max.fill")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 46, height: 46)
                    .background(store.sleepTheme == .sunset ? Color.white.opacity(0.72) : Color.white.opacity(0.10))
                    .foregroundStyle(store.sleepTheme.primary)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(store.sleepTheme == .sunset ? Color.black.opacity(0.05) : Color.white.opacity(0.14), lineWidth: 1))
                    .shadow(color: .black.opacity(store.sleepTheme == .sunset ? 0.10 : 0.28), radius: 12, x: 0, y: 8)
            }
            .accessibilityIdentifier("theme-toggle")
            .accessibilityLabel(store.sleepTheme == .sunset ? L("Activar modo noche") : L("Activar modo claro"))
        }
    }

    private func adjustSleepAlarm(component: TimeComponent, amount: Int) {
        var alarm = store.sleepAlarm
        switch component {
        case .hour:
            alarm.hour = (alarm.hour + amount + 24) % 24
        case .minute:
            alarm.minute = (alarm.minute + amount + 60) % 60
        }
        store.updateSleepAlarm(alarm)
    }

    private func finishAlarm() {
        session.stop()
        if store.openJournalAfterAlarm {
            navigation.openJournal(for: Date())
        }
    }

}

enum TimeComponent {
    case hour
    case minute
}

struct AlarmHeroCard: View {
    let alarm: Alarm
    let theme: SleepTheme
    let onAdjust: (TimeComponent, Int) -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(theme == .sunset ? Color(red: 0.78, green: 0.36, blue: 0.17).opacity(0.18) : theme.primary.opacity(0.16))
                        .frame(width: 52, height: 52)
                    Image(systemName: theme == .sunset ? "moon.stars.fill" : "moon.fill")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(theme.primary)
                }
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil").accessibilityIdentifier("edit-alarm")
                        .font(.system(size: 18, weight: .black))
                        .frame(width: 46, height: 46)
                        .background(theme == .sunset ? Color.white.opacity(0.66) : Color.white.opacity(0.08))
                        .foregroundStyle(theme.primary)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(theme == .sunset ? Color.black.opacity(0.05) : theme.primary.opacity(0.22), lineWidth: 1))
                }
                .accessibilityLabel(L("Editar alarma"))
                .accessibilityIdentifier("edit-alarm")
            }

            VStack(spacing: 8) {
                SwipeTimeText(timeText: alarm.timeText, textColor: theme.text, alignment: .center, onAdjust: onAdjust)
                    .frame(height: 86)
                Text(L("Descansa"))
                    .font(.headline.weight(.black))
                    .foregroundStyle(theme.primary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(theme == .sunset ? Color.white.opacity(0.50) : Color(red: 0.02, green: 0.13, blue: 0.20).opacity(0.68))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(theme == .sunset ? Color(red: 0.94, green: 0.70, blue: 0.45).opacity(0.42) : theme.primary.opacity(0.70), lineWidth: theme == .sunset ? 1 : 1.4)
                )
                .shadow(color: theme == .sunset ? Color(red: 0.55, green: 0.29, blue: 0.10).opacity(0.13) : theme.primary.opacity(0.22), radius: 18, x: 0, y: 10)
        )
    }
}

struct SwipeTimeText: View {
    let timeText: String
    var textColor = Color(red: 0.31, green: 0.15, blue: 0.08)
    var alignment: Alignment = .leading
    let onAdjust: (TimeComponent, Int) -> Void
    @State private var lastStep = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: alignment) {
                Text(timeText)
                    .font(.system(size: 78, weight: .bold, design: .serif))
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(textColor)
                    .allowsHitTesting(false)

                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .highPriorityGesture(timeDragGesture(for: .hour))
                        .accessibilityElement()
                        .accessibilityLabel(L("Horas"))
                        .accessibilityValue(timeText)
                        .accessibilityAdjustableAction { direction in onAdjust(.hour, direction == .increment ? 1 : -1) }
                    Color.clear
                        .contentShape(Rectangle())
                        .highPriorityGesture(timeDragGesture(for: .minute))
                        .accessibilityElement()
                        .accessibilityLabel(L("Minutos"))
                        .accessibilityValue(timeText)
                        .accessibilityAdjustableAction { direction in onAdjust(.minute, direction == .increment ? 1 : -1) }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: alignment)
        }
        .frame(height: 90)
        .frame(maxWidth: .infinity)
    }

    private func timeDragGesture(for component: TimeComponent) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let step = Int((-value.translation.height / 18).rounded(.towardZero))
                guard step != lastStep else { return }
                let delta = step - lastStep
                lastStep = step
                onAdjust(component, delta)
            }
            .onEnded { _ in
                lastStep = 0
            }
    }
}

struct SleepBackdrop: View {
    let theme: SleepTheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let uiImage = backgroundUIImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    fallbackBackground
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }

                LinearGradient(
                    colors: theme == .sunset
                        ? [Color.white.opacity(0.42), Color.white.opacity(0.10), Color(red: 0.47, green: 0.20, blue: 0.10).opacity(0.22)]
                        : [Color.black.opacity(0.28), Color.black.opacity(0.08), Color.black.opacity(0.54)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .ignoresSafeArea()
        }
    }

    private var backgroundUIImage: UIImage? {
        let assetName = theme == .sunset ? "SunsetBackground" : "NightBackground"
        let fileName = theme == .sunset ? "sunset-background" : "night-background"
        if let uiImage = UIImage(named: assetName) {
            return uiImage
        }
        if let url = Bundle.main.url(forResource: fileName, withExtension: "png"),
           let uiImage = UIImage(contentsOfFile: url.path) {
            return uiImage
        }
        if let url = Bundle.main.url(forResource: fileName, withExtension: "jpg"),
           let uiImage = UIImage(contentsOfFile: url.path) {
            return uiImage
        }
        return nil
    }

    @ViewBuilder
    private var fallbackBackground: some View {
        if theme == .sunset {
            SunsetScene()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.08, blue: 0.16),
                        Color(red: 0.02, green: 0.17, blue: 0.28),
                        Color(red: 0.01, green: 0.03, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Stars()
                    .fill(Color.white.opacity(0.76))
            }
        }
    }
}

struct Stars: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points: [(CGFloat, CGFloat, CGFloat)] = [
            (0.16, 0.10, 2), (0.28, 0.18, 1.4), (0.48, 0.12, 1.8), (0.68, 0.20, 1.2), (0.84, 0.11, 1.6),
            (0.20, 0.32, 1.2), (0.37, 0.28, 1.6), (0.58, 0.34, 1.3), (0.76, 0.31, 1.7), (0.90, 0.39, 1.1)
        ]
        for point in points {
            path.addEllipse(in: CGRect(x: rect.width * point.0, y: rect.height * point.1, width: point.2, height: point.2))
        }
        return path
    }
}

struct SunsetScene: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.86, blue: 0.64),
                        Color(red: 0.97, green: 0.55, blue: 0.31),
                        Color(red: 0.45, green: 0.20, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(Color(red: 1.0, green: 0.91, blue: 0.55).opacity(0.95))
                    .frame(width: size.width * 0.28, height: size.width * 0.28)
                    .position(x: size.width * 0.52, y: size.height * 0.54)

                mountain(color: Color(red: 0.76, green: 0.35, blue: 0.19).opacity(0.54), height: 0.64)
                mountain(color: Color(red: 0.45, green: 0.19, blue: 0.12).opacity(0.72), height: 0.78)

                cloud(x: size.width * 0.17, y: size.height * 0.24, scale: 0.82)
                cloud(x: size.width * 0.87, y: size.height * 0.18, scale: 0.56)
                birds
                    .stroke(Color(red: 0.40, green: 0.19, blue: 0.12).opacity(0.55), lineWidth: 1.5)
                    .frame(width: size.width * 0.24, height: size.height * 0.12)
                    .position(x: size.width * 0.76, y: size.height * 0.23)
            }
        }
    }

    private func mountain(color: Color, height: CGFloat) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            Path { path in
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height * height))
                path.addLine(to: CGPoint(x: size.width * 0.22, y: size.height * (height - 0.16)))
                path.addLine(to: CGPoint(x: size.width * 0.44, y: size.height * (height - 0.05)))
                path.addLine(to: CGPoint(x: size.width * 0.66, y: size.height * (height - 0.22)))
                path.addLine(to: CGPoint(x: size.width, y: size.height * (height - 0.08)))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
            }
            .fill(color)
        }
    }

    private func cloud(x: CGFloat, y: CGFloat, scale: CGFloat) -> some View {
        ZStack {
            Capsule().fill(Color.white.opacity(0.22)).frame(width: 82 * scale, height: 18 * scale)
            Circle().fill(Color.white.opacity(0.18)).frame(width: 36 * scale, height: 36 * scale).offset(x: -22 * scale, y: -7 * scale)
            Circle().fill(Color.white.opacity(0.18)).frame(width: 42 * scale, height: 42 * scale).offset(x: 6 * scale, y: -10 * scale)
        }
        .position(x: x, y: y)
    }

    private var birds: Path {
        Path { path in
            for index in 0..<3 {
                let x = CGFloat(index) * 28
                let y = CGFloat(index % 2) * 12
                path.move(to: CGPoint(x: x, y: y + 10))
                path.addQuadCurve(to: CGPoint(x: x + 14, y: y + 10), control: CGPoint(x: x + 7, y: y))
                path.addQuadCurve(to: CGPoint(x: x + 28, y: y + 10), control: CGPoint(x: x + 21, y: y))
            }
        }
    }
}

struct EditAlarmView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AlarmStore
    @State var alarm: Alarm
    @State private var choosingSounds = false
    let theme: SleepTheme
    let onSave: (Alarm) -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        ZStack {
            SleepBackdrop(theme: theme)
                .ignoresSafeArea()
                .overlay(theme == .sunset ? Color.white.opacity(0.45) : Color.black.opacity(0.14))

            VStack(spacing: 18) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .black))
                            .frame(width: 44, height: 44)
                            .background(theme == .sunset ? Color.white.opacity(0.58) : Color.white.opacity(0.08))
                            .foregroundStyle(theme.text)
                            .clipShape(Circle())
                    }

                    Spacer()
                    Text(L("Editar alarma"))
                        .font(.title3.weight(.black))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        TimeEditPanel(alarm: $alarm, theme: theme)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(L("Musicas posibles"))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(theme.text)
                                Spacer()
                                Button(L("Escoger")) {
                                    choosingSounds = true
                                }
                                .font(.headline.weight(.black))
                                .foregroundStyle(theme.primary)
                            }

                            Text(soundSummary)
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(theme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(panelFill)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        FadeDurationControl(enabled: $alarm.fadeInEnabled, duration: $alarm.fadeDuration, theme: theme)

                        Toggle(isOn: $alarm.motionSnooze) {
                            Label(L("Mover para posponer"), systemImage: "iphone.radiowaves.left.and.right")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(theme.text)
                        }
                        .tint(theme.primary)
                        .padding(16)
                        .background(panelFill)
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        LightWakeControl(enabled: $alarm.lightWakeEnabled, minutes: $alarm.lightWakeMinutes, theme: theme)

                        SnoozePresetSelector(minutes: $alarm.snoozeMinutes, theme: theme)
                    }
                    .padding(.bottom, 4)
                }

                Button {
                    alarm.randomSound = alarm.soundIds.count > 1
                    alarm.weekdays = []
                    onSave(alarm)
                    dismiss()
                } label: {
                    Text(L("Guardar"))
                        .font(.title3.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            LinearGradient(colors: [theme.primary.opacity(0.95), theme.primary.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 58)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: $choosingSounds) {
            SoundPickerSheet(alarm: $alarm, theme: theme)
        }
        .preferredColorScheme(theme == .night ? .dark : .light)
    }

    private var panelFill: Color {
        theme == .sunset ? Color.white.opacity(0.52) : Color.white.opacity(0.07)
    }

    private var soundSummary: String {
        let builtin = AlarmSound.all.filter { alarm.soundIds.contains($0.id) }.map(\.name)
        let custom = store.customSounds.filter { alarm.soundIds.contains($0.soundId) }.map(\.name)
        let selected = builtin + custom
        if selected.isEmpty { return L("Ninguna seleccionada") }
        if selected.count == 1 { return selected[0] }
        return LF("%@ seleccionadas", String(describing: selected.count))
    }
}

struct TimeEditPanel: View {
    @Binding var alarm: Alarm
    let theme: SleepTheme

    var body: some View {
        DatePicker(L("Hora"), selection: timeBinding, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .frame(height: 164)
            .clipped()
            .colorScheme(theme == .sunset ? .light : .dark)
            .tint(theme.primary)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme == .sunset ? Color.white.opacity(0.54) : Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme == .sunset ? Color.white.opacity(0.20) : Color.white.opacity(0.16), lineWidth: 1))
        )
        .foregroundStyle(.white)
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = alarm.hour
                components.minute = alarm.minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                alarm.hour = components.hour ?? alarm.hour
                alarm.minute = components.minute ?? alarm.minute
            }
        )
    }
}

struct SnoozePresetSelector: View {
    @Binding var minutes: Int
    let theme: SleepTheme
    private let options = [1, 3, 5, 10, 15]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L("Posponer"), systemImage: "moon.zzz.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(theme.text)

            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        minutes = option
                    } label: {
                        Text("\(option) min")
                            .font(.subheadline.weight(.black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(minutes == option ? theme.primary.opacity(0.22) : panelFill)
                            .foregroundStyle(minutes == option ? theme.primary : theme.text)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(minutes == option ? theme.primary.opacity(0.58) : theme.secondaryText.opacity(0.16), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var panelFill: Color {
        theme == .sunset ? Color.white.opacity(0.52) : Color.white.opacity(0.07)
    }
}

struct LightWakeControl: View {
    @Binding var enabled: Bool
    @Binding var minutes: Int
    let theme: SleepTheme
    private let options = [3, 5, 10, 15]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $enabled) {
                Label(L("Luz progresiva"), systemImage: "sun.max.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(theme.text)
            }
            .tint(theme.primary)

            if enabled {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            minutes = option
                        } label: {
                            Text("\(option) min")
                                .font(.subheadline.weight(.black))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(minutes == option ? theme.primary.opacity(0.22) : panelFill)
                                .foregroundStyle(minutes == option ? theme.primary : theme.text)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(minutes == option ? theme.primary.opacity(0.58) : theme.secondaryText.opacity(0.16), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var panelFill: Color {
        theme == .sunset ? Color.white.opacity(0.52) : Color.white.opacity(0.07)
    }
}

struct SoundPickerSheet: View {
    @EnvironmentObject private var engine: NightEngine
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AlarmStore
    @Binding var alarm: Alarm
    let theme: SleepTheme
    @State private var importingSound = false

    var body: some View {
        ZStack {
            SleepBackdrop(theme: theme)
                .ignoresSafeArea()
                .overlay(theme == .sunset ? Color.white.opacity(0.48) : Color.black.opacity(0.24))

            VStack(spacing: 18) {
                HStack {
                    Text(L("Musicas posibles"))
                        .font(.title3.weight(.black))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Button {
                        importingSound = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.black))
                            .frame(width: 38, height: 38)
                            .background(theme == .sunset ? Color.white.opacity(0.52) : Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .foregroundStyle(theme.primary)
                    .accessibilityLabel(L("Importar canción"))
                    .accessibilityIdentifier("import-song")
                    Button(L("Hecho")) {
                        dismiss()
                    }
                    .font(.headline.weight(.black))
                    .foregroundStyle(theme.primary)
                }

                ScrollView(showsIndicators: false) {
                    SoundSelector(alarm: $alarm, theme: theme, showAll: true)
                }

                Button(L("Deseleccionar")) {
                    alarm.soundIds.removeAll()
                    alarm.randomSound = false
                }
                .font(.headline.weight(.black))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(theme.primary)
                .background(theme == .sunset ? Color.white.opacity(0.52) : Color.white.opacity(0.07))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.top, 58)
            .padding(.bottom, 28)
        }
        .onDisappear { engine.stopPreview() }
        .fileImporter(isPresented: $importingSound, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                store.importCustomSound(from: url)
            }
        }
        .preferredColorScheme(theme == .night ? .dark : .light)
        .statusBarHidden(false)
    }
}

struct SoundSelector: View {
    @EnvironmentObject private var engine: NightEngine
    @EnvironmentObject private var store: AlarmStore
    @Binding var alarm: Alarm
    let theme: SleepTheme
    let showAll: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(visibleSounds) { sound in
                soundRow(sound)
            }
            if !store.customSounds.isEmpty {
                Text(L("Tus canciones"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(theme.secondaryText)
                    .padding(.top, 8)
                ForEach(store.customSounds) { sound in
                    customSoundRow(sound)
                }
            }
        }
    }

    private var visibleSounds: [AlarmSound] {
        showAll ? AlarmSound.all : Array(AlarmSound.all.prefix(5))
    }

    private func soundRow(_ sound: AlarmSound) -> some View {
        rowContent(
            icon: icon(for: sound.id),
            title: sound.name,
            subtitle: subtitle(for: sound),
            selected: alarm.soundIds.contains(sound.id),
            onToggle: {
                toggleSound(sound.id)
            },
            onPreview: {
                engine.playPreview(sound.id)
            },
            onDelete: nil
        )
    }

    private func customSoundRow(_ sound: CustomAlarmSound) -> some View {
        rowContent(
            icon: "music.note",
            title: sound.name,
            subtitle: L("Cancion importada"),
            selected: alarm.soundIds.contains(sound.soundId),
            onToggle: {
                toggleSound(sound.soundId)
            },
            onPreview: {
                engine.playPreview(sound.soundId)
            },
            onDelete: {
                engine.stopPreview()
                alarm.soundIds.removeAll { $0 == sound.soundId }
                store.removeCustomSound(sound)
            }
        )
    }

    private func rowContent(icon: String, title: String, subtitle: String?, selected: Bool, onToggle: @escaping () -> Void, onPreview: @escaping () -> Void, onDelete: (() -> Void)?) -> some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2.weight(.bold))
                    .frame(width: 34)
                    .foregroundStyle(selected ? theme.primary : theme.secondaryText.opacity(0.45))
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.black))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                }
            }
            Spacer()
            Button(action: onPreview) {
                Image(systemName: "play.fill")
                    .font(.subheadline.weight(.black))
                    .frame(width: 34, height: 34)
                    .background(theme.primary.opacity(0.18))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.primary)
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.secondaryText)
            }
        }
        .foregroundStyle(theme.text)
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
        .background(theme == .sunset ? Color.white.opacity(0.44) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? theme.primary.opacity(0.58) : theme.secondaryText.opacity(0.16), lineWidth: 1))
    }

    private func toggleSound(_ id: String) {
        if alarm.soundIds.contains(id) {
            alarm.soundIds.removeAll { $0 == id }
        } else {
            alarm.soundIds.append(id)
        }
        alarm.randomSound = alarm.soundIds.count > 1
    }

    private func icon(for id: String) -> String {
        switch id {
        case "funny-alarm": return "bell.fill"
        case "bosque-amanecer": return "tree.fill"
        case "despertar-suave": return "sunrise.fill"
        case "lo-fi-alarm": return "music.note"
        default: return "music.note"
        }
    }

    private func subtitle(for sound: AlarmSound) -> String {
        switch sound.id {
        case "funny-alarm": return L("Alarma clara")
        case "bosque-amanecer": return L("Ambiente natural")
        case "despertar-suave": return L("Entrada tranquila")
        case "lo-fi-alarm": return L("Ritmo suave")
        default: return L("Sonido")
        }
    }
}

struct FadeDurationControl: View {
    @Binding var enabled: Bool
    @Binding var duration: Double
    var theme: SleepTheme = .sunset

    private var durationText: String {
        if duration < 60 { return "\(Int(duration)) s" }
        let minutes = duration / 60
        if minutes.rounded() == minutes { return "\(Int(minutes)) min" }
        return String(format: "%.1f min", minutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L("Volumen progresivo"), systemImage: "waveform")
                Spacer()
                Text(enabled ? durationText : L("Maximo"))
                    .font(.headline.weight(.black))
                    .foregroundStyle(theme.primary)
            }
            .foregroundStyle(theme.text)

            HStack(spacing: 8) {
                volumeModeButton(title: L("Progresivo"), systemImage: "waveform", isSelected: enabled) {
                    enabled = true
                }
                volumeModeButton(title: L("Directo al maximo"), systemImage: "speaker.wave.3.fill", isSelected: !enabled) {
                    enabled = false
                }
            }

            if enabled {
                Slider(value: $duration, in: 60...600, step: 60) {
                    Text(L("Subida"))
                } minimumValueLabel: {
                    Text("1 min")
                } maximumValueLabel: {
                    Text("10 min")
                }
                .tint(theme.primary)
                .foregroundStyle(theme.secondaryText)
            } else {
                Label(L("La alarma usara el volumen maximo interno de la app."), systemImage: "speaker.wave.3.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label(L("Volumen del iPhone"), systemImage: "iphone")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(theme.text)

                SystemVolumeSlider()
                    .frame(height: 34)

                Text(L("iOS solo permite cambiar este volumen con el control del sistema o los botones laterales."))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(12)
            .background(panelFill)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(16)
        .background(theme == .sunset ? Color.white.opacity(0.52) : Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear {
            if duration < 60 { duration = 60 }
        }
    }

    private func volumeModeButton(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(isSelected ? theme.primary.opacity(0.22) : panelFill)
                .foregroundStyle(isSelected ? theme.primary : theme.text)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? theme.primary.opacity(0.58) : theme.secondaryText.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var panelFill: Color {
        theme == .sunset ? Color.white.opacity(0.26) : Color.white.opacity(0.07)
    }
}

struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context _: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = false
        view.setVolumeThumbImage(UIImage(systemName: "circle.fill"), for: .normal)
        return view
    }

    func updateUIView(_: MPVolumeView, context _: Context) {}
}

struct NightActiveView: View {
    var onFinish: (() -> Void)? = nil
    @EnvironmentObject private var session: NightSession
    let alarm: Alarm
    let theme: SleepTheme
    @State private var showMotionHint = false
    @State private var showStartedTitle = true

    var body: some View {
        ZStack {
            SleepBackdrop(theme: theme)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer(minLength: 86)

                Text(Self.currentTimeFormatter.string(from: session.now))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme == .sunset ? Color.white.opacity(0.88) : Color.white.opacity(0.76))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(theme == .sunset ? Color.black.opacity(0.12) : Color.white.opacity(0.08))
                    .clipShape(Capsule())

                if theme == .sunset {
                    Text(L("Buenas noches"))
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                }

                Text(alarm.timeText)
                    .font(.system(size: 86, weight: .bold, design: .serif))
                    .foregroundStyle(theme == .sunset ? Color.white.opacity(0.96) : Color.white.opacity(0.92))

                Text(L("La noche ha comenzado"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme == .sunset ? Color.white : theme.primary)
                    .opacity(showStartedTitle ? 1 : 0)

                Label(L("Mueve el móvil\npara posponer"), systemImage: "iphone.radiowaves.left.and.right")
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme == .sunset ? Color.white.opacity(0.92) : theme.primary)
                    .opacity(showMotionHint ? 1 : 0)
                    .frame(height: showMotionHint ? 62 : 0)

                Spacer()

                Button {
                    onFinish?()
                } label: {
                    Label(L("Terminar"), systemImage: "stop.fill")
                        .font(.headline.weight(.black))
                        .padding(.horizontal, 22)
                        .frame(height: 48)
                        .background(theme == .sunset ? Color.white.opacity(0.36) : Color.white.opacity(0.08))
                        .foregroundStyle(theme == .sunset ? Color(red: 0.30, green: 0.17, blue: 0.10) : Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(theme == .night ? Color.white.opacity(0.14) : Color.clear, lineWidth: 1))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 30)
            }
            .padding(24)
        }
        .preferredColorScheme(theme == .night ? .dark : .light)
        .statusBarHidden(false)
        .onAppear {
            showMotionHint = alarm.motionSnooze
            showStartedTitle = true
            withAnimation(.easeOut(duration: 1.4).delay(2.2)) {
                showMotionHint = false
            }
            withAnimation(.easeOut(duration: 1.4).delay(4.2)) {
                showStartedTitle = false
            }
        }
    }

    private static var currentTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}

struct RingView: View {
    @EnvironmentObject private var session: NightSession
    let alarm: Alarm
    let theme: SleepTheme
    var onFinish: (() -> Void)?

    var body: some View {
        ZStack {
            SleepBackdrop(theme: theme)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 108)
                Text(L("La noche ha comenzado"))
                    .font(.title2.weight(.medium))
                    .foregroundStyle(theme == .sunset ? Color.white : theme.primary)

                Text(displayedAlarm.timeText)
                    .font(.system(size: 100, weight: .bold, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.94))

                Image(systemName: theme == .sunset ? "moon.fill" : "moon.stars.fill")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(theme == .sunset ? Color.white.opacity(0.88) : theme.primary)

                Text(statusText)
                    .font(.title2.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme == .sunset ? Color.white.opacity(0.94) : theme.primary)

                ProgressView(value: session.motionProgress)
                    .tint(.white)
                    .padding(.horizontal, 40)
                    .opacity(session.isSnoozing ? 0 : 1)
                    

                Spacer()

                VStack(spacing: 12) {
                    RingActionButton(
                        title: session.isSnoozing ? L("Pospuesta") : L("Posponer"),
                        icon: "moon.zzz.fill",
                        fill: theme.primary,
                        foreground: theme == .sunset ? .white : Color(red: 0.01, green: 0.06, blue: 0.08),
                        disabled: session.isSnoozing,
                        action: { Task { await session.snooze() } }
                    )
                    RingActionButton(
                        title: L("Terminar"),
                        icon: "stop.fill",
                        fill: theme == .sunset ? Color.white.opacity(0.90) : Color.white.opacity(0.18),
                        foreground: theme == .sunset ? Color(red: 0.30, green: 0.17, blue: 0.10) : .white,
                        action: { onFinish?() ?? session.stop() }
                    )
                }
            }
            .padding(24)
        }
        .preferredColorScheme(theme == .night ? .dark : .light)
        .statusBarHidden(false)
    }

    private var statusText: String {
        if session.isSnoozing, let date = session.snoozedUntil {
            return LF("Pospuesta hasta %@", String(describing: Self.snoozeFormatter.string(from: date)))
        }
        return displayedAlarm.motionSnooze ? L("Mueve el móvil\npara posponer") : L("Alarma sonando")
    }

    private var displayedAlarm: Alarm {
        session.ringingAlarm ?? alarm
    }

    private static var snoozeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}

struct RingActionButton: View {
    let title: String
    let icon: String
    let fill: Color
    let foreground: Color
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
                    .font(.title2.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            } icon: {
                Image(systemName: icon)
                    .font(.title2.weight(.black))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(fill)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
            .shadow(color: fill.opacity(0.24), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.72 : 1)
    }
}

struct DreamJournalView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var dreams: DreamStore
    @EnvironmentObject private var navigation: AppNavigation
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var displayedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var draft = DreamEntry(day: Date())
    @State private var showingSoundClips = false
    @State private var showingFullCalendar = false
    @FocusState private var notesFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                SleepBackdrop(theme: store.sleepTheme)
                    .ignoresSafeArea()
                    .overlay(store.sleepTheme == .sunset ? Color.white.opacity(0.52) : Color.black.opacity(0.20))

                GeometryReader { proxy in
                    let contentWidth = max(0, proxy.size.width - 26)

                    VStack(spacing: 0) {
                        journalHeader
                            .frame(width: proxy.size.width)

                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 10) {
                                SleepCalendarGrid(selectedDate: $selectedDate, displayedMonth: $displayedMonth)
                                    .frame(width: contentWidth)
                                    .clipped()
                                    .simultaneousGesture(TapGesture().onEnded { notesFocused = false })

                                SleepStageChart(entry: draft)
                                    .frame(width: contentWidth)
                                    .clipped()
                                    .simultaneousGesture(TapGesture().onEnded { notesFocused = false })

                                WakeMoodSelector(entry: $draft, theme: store.sleepTheme)
                                    .frame(width: contentWidth)
                                    .clipped()
                                    .simultaneousGesture(TapGesture().onEnded { notesFocused = false })

                                NightSoundsSummary(entry: draft, theme: store.sleepTheme) {
                                    showingSoundClips = true
                                }
                                .frame(width: contentWidth)
                                .clipped()
                                .simultaneousGesture(TapGesture().onEnded { notesFocused = false })

                                DreamNotesCard(notes: $draft.notes, theme: store.sleepTheme, focused: $notesFocused)
                                    .frame(width: contentWidth)
                                    .clipped()
                            }
                            .frame(width: contentWidth, alignment: .leading)
                            .padding(.horizontal, 13)
                            .padding(.top, 4)
                            .padding(.bottom, 16)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .frame(width: proxy.size.width)
                        .clipped()
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { loadEntry(); Task { await dreams.refreshHealth() } }
            .onReceive(dreams.objectWillChange) { _ in DispatchQueue.main.async { loadEntry() } }
            .onChange(of: selectedDate) { _ in
                if selectedDate > Self.today {
                    selectedDate = Self.today
                    return
                }
                displayedMonth = Self.monthStart(for: selectedDate)
                loadEntry()
            }
            .onChange(of: navigation.requestedJournalDate) { date in
                guard let date else { return }
                let safeDate = min(Calendar.current.startOfDay(for: date), Self.today)
                selectedDate = safeDate
                displayedMonth = Self.monthStart(for: safeDate)
                loadEntry()
                notesFocused = true
            }
            .onChange(of: draft.notes) { _ in
                dreams.upsert(draft)
            }
            .onChange(of: draft.wakeMood) { _ in dreams.upsert(draft) }
            .preferredColorScheme(store.sleepTheme == .night ? .dark : .light)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L("Listo")) { notesFocused = false }
                }
            }
            .sheet(isPresented: $showingSoundClips) {
                NightSoundsSheet(entry: draft, theme: store.sleepTheme)
            }
            .sheet(isPresented: $showingFullCalendar) {
                FullSleepCalendarSheet(selectedDate: $selectedDate, displayedMonth: $displayedMonth)
            }
        }
    }

    private var journalHeader: some View {
        ZStack {
            Text(L("Diario de sueño"))
                .font(.system(size: 25, weight: .bold, design: .default))
                .foregroundStyle(store.sleepTheme.text)

            HStack {
                Button {
                    goToToday()
                } label: {
                    Text(L("Hoy")).minimumScaleFactor(0.7)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(store.sleepTheme.primary)
                        .frame(width: 54, height: 34)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(store.sleepTheme.primary.opacity(0.86), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    showingFullCalendar = true
                } label: {
                    Image(systemName: "calendar").accessibilityIdentifier("full-calendar").accessibilityLabel(L("Calendario"))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(store.sleepTheme.primary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func goToToday() {
        let today = Calendar.current.startOfDay(for: Date())
        selectedDate = today
        displayedMonth = Self.monthStart(for: today)
        loadEntry()
    }

    private func loadEntry() {
        draft = dreams.entry(for: selectedDate)
        draft.day = selectedDate
    }

    private func metricRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.headline.weight(.black))
        }
        .font(.subheadline.weight(.bold))
    }

    private var sleepDurationText: String {
        let minutes = draft.lightSleepMinutes + draft.deepSleepMinutes
        guard minutes > 0 else { return L("Sin datos") }
        return "\(minutes / 60) h \(minutes % 60) min"
    }

    private var bedDurationText: String {
        guard let started = draft.sleepStartedAt else { return L("Sin datos") }
        let ended = draft.sleepEndedAt ?? Date()
        let minutes = max(0, Int(ended.timeIntervalSince(started) / 60))
        guard minutes > 0 else { return L("Menos de 1 min") }
        return "\(minutes / 60) h \(minutes % 60) min"
    }

    private var panelFill: Color {
        store.sleepTheme == .sunset ? Color.white.opacity(0.62) : Color.white.opacity(0.08)
    }

    private static func monthStart(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    private static var today: Date {
        Calendar.current.startOfDay(for: Date())
    }
}

struct SleepCalendarGrid: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var dreams: DreamStore
    @Binding var selectedDate: Date
    @Binding var displayedMonth: Date
    @State private var showingMonthPicker = false

    private let weekdays = [L("LUN"), L("MAR"), L("MIÉ"), L("JUE"), L("VIE"), L("SÁB"), L("DOM")]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                Button {
                    showingMonthPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Text(Self.monthFormatter.string(from: displayedMonth))
                            .font(.system(size: 18, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(store.sleepTheme.secondaryText)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    moveWeek(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 34, height: 32)
                }

                Button {
                    moveWeek(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 34, height: 32)
                }
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(weekDates.enumerated()), id: \.element) { index, date in
                    dayButton(for: date, weekday: weekdays[index])
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(panelFill)
        .foregroundStyle(store.sleepTheme.text)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
        .sheet(isPresented: $showingMonthPicker) {
            MonthSelectionSheet(selectedDate: $selectedDate, displayedMonth: $displayedMonth)
        }
    }

    private func dayButton(for date: Date, weekday: String) -> some View {
        let entry = dreams.entry(for: date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let isFuture = date > Self.today

        return Button {
            guard !isFuture else { return }
            selectedDate = Calendar.current.startOfDay(for: date)
        } label: {
            VStack(spacing: 4) {
                Text(weekday)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(store.sleepTheme.secondaryText)
                Text(Self.dayFormatter.string(from: date))
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(1)

                if let mood = entry.wakeMood {
                    DiaryAssetImage(name: mood.face)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(scoreColor(for: entry))
                        .frame(width: 6, height: 6)
                        .opacity(entry.hasSleepData ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(isSelected && !isFuture ? store.sleepTheme.primary.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected && !isFuture ? store.sleepTheme.primary.opacity(0.92) : isToday ? store.sleepTheme.primary.opacity(0.34) : Color.clear, lineWidth: 1.3)
            )
            .opacity(isFuture ? 0.34 : 1)
            .grayscale(isFuture ? 0.75 : 0)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(accessibilityText(for: entry, date: date))
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: selectedDate)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: selectedDate) ?? selectedDate
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monday)
        }
    }

    private var panelFill: Color {
        store.sleepTheme == .sunset ? Color.white.opacity(0.50) : Color(red: 0.02, green: 0.11, blue: 0.16).opacity(0.74)
    }

    private var borderColor: Color {
        store.sleepTheme == .sunset ? Color.white.opacity(0.34) : Color.white.opacity(0.13)
    }

    private func moveWeek(_ offset: Int) {
        let nextDate = Calendar.current.date(byAdding: .day, value: offset * 7, to: selectedDate) ?? selectedDate
        selectedDate = min(Calendar.current.startOfDay(for: nextDate), Self.today)
        displayedMonth = Self.monthStart(for: selectedDate)
    }

    private func scoreColor(for entry: DreamEntry) -> Color {
        guard entry.hasSleepData, let score = entry.score else { return .clear }
        if score >= 80 { return Color.green }
        if score >= 60 { return Color.orange }
        return Color.red
    }

    private func accessibilityText(for entry: DreamEntry, date: Date) -> String {
        guard entry.hasSleepData, let score = entry.score else {
            return LF("%@, sin datos", String(describing: Self.fullDateFormatter.string(from: date)))
        }
        return LF("%@, puntuacion %@", String(describing: Self.fullDateFormatter.string(from: date)), String(describing: score))
    }

    private static var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }

    private static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }

    private static var fullDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.dateStyle = .long
        return formatter
    }

    private static func monthStart(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    private static var today: Date {
        Calendar.current.startOfDay(for: Date())
    }
}

struct MonthSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AlarmStore
    @Binding var selectedDate: Date
    @Binding var displayedMonth: Date
    @State private var pickerYear: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    init(selectedDate: Binding<Date>, displayedMonth: Binding<Date>) {
        _selectedDate = selectedDate
        _displayedMonth = displayedMonth
        _pickerYear = State(initialValue: Calendar.current.component(.year, from: displayedMonth.wrappedValue))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SleepBackdrop(theme: store.sleepTheme)
                    .ignoresSafeArea()
                    .overlay(store.sleepTheme == .sunset ? Color.white.opacity(0.52) : Color.black.opacity(0.22))

                VStack(spacing: 18) {
                    HStack {
                        Button { pickerYear -= 1 } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 42, height: 42)
                        }

                        Spacer()

                        Text(String(pickerYear))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(store.sleepTheme.text)

                        Spacer()

                        Button { pickerYear += 1 } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 42, height: 42)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(store.sleepTheme.primary)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(1...12, id: \.self) { month in
                            monthButton(month)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(18)
            }
            .navigationTitle(L("Escoger mes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Cerrar")) { dismiss() }
                        .font(.headline.weight(.bold))
                }
            }
            .preferredColorScheme(store.sleepTheme == .night ? .dark : .light)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func monthButton(_ month: Int) -> some View {
        let monthDate = Calendar.current.date(from: DateComponents(year: pickerYear, month: month, day: 1)) ?? displayedMonth
        let isSelected = Calendar.current.isDate(monthDate, equalTo: displayedMonth, toGranularity: .month)
        let isFuture = monthDate > Self.currentMonth

        return Button {
            guard !isFuture else { return }
            let start = Self.monthStart(for: monthDate)
            selectedDate = start
            displayedMonth = start
            dismiss()
        } label: {
            Text(Self.monthNameFormatter.string(from: monthDate).capitalized)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isSelected && !isFuture ? store.sleepTheme.primary.opacity(0.16) : Color.black.opacity(store.sleepTheme == .sunset ? 0.03 : 0.10))
                .foregroundStyle(isFuture ? store.sleepTheme.secondaryText.opacity(0.45) : isSelected ? store.sleepTheme.primary : store.sleepTheme.text)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected && !isFuture ? store.sleepTheme.primary.opacity(0.88) : borderColor, lineWidth: 1)
                )
                .opacity(isFuture ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private var borderColor: Color {
        store.sleepTheme == .sunset ? Color.white.opacity(0.28) : Color.white.opacity(0.12)
    }

    private static func monthStart(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    private static var currentMonth: Date {
        monthStart(for: Date())
    }

    private static var monthNameFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.dateFormat = "LLLL"
        return formatter
    }
}

struct FullSleepCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var dreams: DreamStore
    @Binding var selectedDate: Date
    @Binding var displayedMonth: Date

    private let weekdays = [L("LUN"), L("MAR"), L("MIÉ"), L("JUE"), L("VIE"), L("SÁB"), L("DOM")]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        NavigationStack {
            ZStack {
                SleepBackdrop(theme: store.sleepTheme)
                    .ignoresSafeArea()
                    .overlay(store.sleepTheme == .sunset ? Color.white.opacity(0.52) : Color.black.opacity(0.22))

                VStack(alignment: .leading, spacing: 14) {
                    monthHeader

                    HStack {
                        ForEach(weekdays, id: \.self) { day in
                            Text(day)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(store.sleepTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                            if let date {
                                fullDayButton(for: date)
                            } else {
                                Color.clear.frame(height: 54)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(18)
            }
            .navigationTitle(L("Calendario"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Cerrar")) { dismiss() }
                        .font(.headline.weight(.bold))
                }
            }
            .preferredColorScheme(store.sleepTheme == .night ? .dark : .light)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var monthHeader: some View {
        HStack {
            Button { moveMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(Self.monthFormatter.string(from: displayedMonth))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(store.sleepTheme.text)

            Spacer()

            Button { moveMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .disabled(displayedMonth >= Self.currentMonth)
            .opacity(displayedMonth >= Self.currentMonth ? 0.35 : 1)
        }
        .foregroundStyle(store.sleepTheme.primary)
    }

    private func fullDayButton(for date: Date) -> some View {
        let entry = dreams.entry(for: date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let isFuture = date > Self.today

        return Button {
            guard !isFuture else { return }
            selectedDate = Calendar.current.startOfDay(for: date)
            displayedMonth = Self.monthStart(for: date)
            dismiss()
        } label: {
            VStack(spacing: 4) {
                Text(Self.dayFormatter.string(from: date))
                    .font(.system(size: 17, weight: .bold))
                if let mood = entry.wakeMood {
                    DiaryAssetImage(name: mood.face)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(scoreColor(for: entry))
                        .frame(width: 6, height: 6)
                        .opacity(entry.hasSleepData ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isSelected && !isFuture ? store.sleepTheme.primary.opacity(0.12) : Color.black.opacity(store.sleepTheme == .sunset ? 0.03 : 0.10))
            .foregroundStyle(isFuture ? store.sleepTheme.secondaryText.opacity(0.45) : store.sleepTheme.text)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected && !isFuture ? store.sleepTheme.primary.opacity(0.92) : isToday ? store.sleepTheme.primary.opacity(0.34) : borderColor, lineWidth: 1)
            )
            .opacity(isFuture ? 0.45 : 1)
            .grayscale(isFuture ? 0.75 : 0)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private var monthCells: [Date?] {
        let calendar = Calendar.current
        let start = Self.monthStart(for: displayedMonth)
        let range = calendar.range(of: .day, in: .month, for: start) ?? 1..<1
        let weekday = calendar.component(.weekday, from: start)
        let leadingBlanks = (weekday + 5) % 7
        let days = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
        return Array(repeating: nil, count: leadingBlanks) + days
    }

    private func moveMonth(_ offset: Int) {
        let nextMonth = Calendar.current.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
        displayedMonth = min(Self.monthStart(for: nextMonth), Self.currentMonth)
    }

    private func scoreColor(for entry: DreamEntry) -> Color {
        guard entry.hasSleepData, let score = entry.score else { return .clear }
        if score >= 80 { return Color.green }
        if score >= 60 { return Color.orange }
        return Color.red
    }

    private var borderColor: Color {
        store.sleepTheme == .sunset ? Color.white.opacity(0.28) : Color.white.opacity(0.12)
    }

    private static func monthStart(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    private static var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private static var currentMonth: Date {
        monthStart(for: Date())
    }

    private static var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }

    private static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
}

struct WakeMoodSelector: View {
    @Binding var entry: DreamEntry
    let theme: SleepTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Cómo te has despertado"))
                .font(.system(size: 19, weight: .bold))

            HStack(spacing: 8) {
                ForEach(WakeMood.allCases) { mood in
                    Button {
                        entry.wakeMood = entry.wakeMood == mood ? nil : mood
                    } label: {
                        VStack(spacing: 5) {
                            DiaryAssetImage(name: mood.face)
                                .frame(width: 46, height: 46)
                            Text(mood.title).minimumScaleFactor(0.65).lineLimit(1)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.58)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 76)
                        .background(entry.wakeMood == mood ? theme.primary.opacity(0.10) : optionFill)
                        .foregroundStyle(entry.wakeMood == mood ? theme.primary : theme.text)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(entry.wakeMood == mood ? theme.primary.opacity(0.92) : theme.secondaryText.opacity(0.14), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
        .foregroundStyle(theme.text)
    }

    private var panelFill: Color {
        theme == .sunset ? Color.white.opacity(0.50) : Color(red: 0.02, green: 0.11, blue: 0.16).opacity(0.74)
    }

    private var optionFill: Color {
        theme == .sunset ? Color.white.opacity(0.28) : Color.white.opacity(0.05)
    }

    private var borderColor: Color {
        theme == .sunset ? Color.white.opacity(0.34) : Color.white.opacity(0.13)
    }
}

struct NightSoundsSummary: View {
    @EnvironmentObject private var engine: NightEngine
    let entry: DreamEntry
    let theme: SleepTheme
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DiaryAssetImage(name: "sound-wave")
                    .frame(width: 27, height: 27)
                Text(L("Ruidos nocturnos"))
                    .font(.system(size: 19, weight: .bold))
                Spacer()
                Text(LF("%@ clips", String(describing: clipCount)))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.primary)
                Button(action: onOpen) {
                    Text(L("Ver clips"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.primary)
                        .frame(width: 76, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(theme.primary.opacity(0.86), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(clipCount == 0)
                .opacity(clipCount == 0 ? 0.45 : 1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theme.secondaryText)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            LazyVGrid(columns: soundColumns, spacing: 6) {
                ForEach(soundSummaryItems, id: \.title) { item in
                    soundPill(item.title, count: item.count, kind: item.kind)
                }
            }
            .frame(height: 42)

            HStack(spacing: 9) {
                if let latest = latestClip {
                    Button {
                        play(latest)
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.76), lineWidth: 2)
                            Image(systemName: engine.previewID == latest.id.uuidString ? "pause.fill" : "play.fill")
                                .font(.system(size: 17, weight: .black))
                        }
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Circle()
                        .fill(latest.kind.color)
                        .frame(width: 8, height: 8)

                    Text(Self.timeFormatter.string(from: latest.date))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.secondaryText)

                    waveform(color: latest.kind.color)
                        .frame(maxWidth: .infinity)

                    Text(durationText(for: latest))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.secondaryText)

                    Text(latest.kind.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(latest.kind.color)
                        .lineLimit(1)
                        .frame(width: 58, alignment: .leading)

                    Button(action: onOpen) {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(theme.secondaryText)
                            .frame(width: 20, height: 36)
                    }
                    .buttonStyle(.plain)
                } else {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.30), lineWidth: 2)
                        Image(systemName: "play.fill")
                            .font(.system(size: 17, weight: .black))
                    }
                    .frame(width: 44, height: 44)
                    .foregroundStyle(theme.secondaryText.opacity(0.55))

                    Text(L("Sin clips guardados esta noche."))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                }
            }
            .padding(8)
            .frame(height: 52)
            .background(Color.black.opacity(theme == .sunset ? 0.05 : 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(13)
        .frame(height: 176)
        .frame(maxWidth: .infinity)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
        .foregroundStyle(theme.text)
        .onDisappear { engine.stopPreview() }
    }

    private func waveform(color: Color) -> some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<24, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color.opacity(index % 4 == 0 ? 0.92 : 0.62))
                    .frame(width: 2, height: CGFloat(5 + (index * 7) % 20))
            }
        }
        .frame(height: 26)
    }

    private func durationText(for clip: SleepSoundClip) -> String {
        guard let player = try? AVAudioPlayer(contentsOf: clip.fileURL) else { return "--" }
        let seconds = max(1, Int(player.duration.rounded()))
        return String(format: "0:%02d", min(seconds, 59))
    }

    private var clipCount: Int {
        max(entry.audioClips, entry.soundClips.count)
    }

    private var latestClip: SleepSoundClip? {
        entry.soundClips.sorted(by: { $0.date > $1.date }).first
    }

    private var soundColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
    }

    private var soundSummaryItems: [(title: String, count: Int, kind: SleepAudioEvent.Kind)] {
        [
            (L("Ronq."), entry.snoreEvents, .snore),
            (L("Resp."), entry.strongBreathingEvents, .strongBreathing),
            (L("Tos"), entry.coughEvents, .cough),
            (L("Voz"), entry.talkingEvents, .talking)
        ]
    }

    private func soundPill(_ title: String, count: Int, kind: SleepAudioEvent.Kind) -> some View {
        HStack(spacing: 6) {
            DiaryAssetImage(name: kind.assetName)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("\(count)")
                    .font(.system(size: 16, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 38)
    }

    private func play(_ clip: SleepSoundClip) {
        engine.playPreview(clip.id.uuidString, url: clip.fileURL)
    }

    private var panelFill: Color {
        theme == .sunset ? Color.white.opacity(0.50) : Color(red: 0.02, green: 0.11, blue: 0.16).opacity(0.74)
    }

    private var borderColor: Color {
        theme == .sunset ? Color.white.opacity(0.34) : Color.white.opacity(0.13)
    }

    private static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}

struct DreamNotesCard: View {
    @Binding var notes: String
    let theme: SleepTheme
    var focused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "book.closed")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(theme.primary)
                Text(L("Diario de sueños"))
                    .font(.system(size: 19, weight: .bold))
            }

            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text(L("Escribe aquí tus sueños, pensamientos o cómo\nha sido tu noche..."))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.secondaryText.opacity(0.78))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $notes).accessibilityIdentifier("dream-notes")
                    .focused(focused)
                    .frame(minHeight: 92)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .foregroundStyle(theme.text)
                    .background(Color.clear)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(notes.count)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.secondaryText)
                            .padding(10)
                    }
                }
            }
            .frame(minHeight: 96)
            .background(Color.black.opacity(theme == .sunset ? 0.04 : 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 1))
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
        .foregroundStyle(theme.text)
    }

    private var panelFill: Color {
        theme == .sunset ? Color.white.opacity(0.50) : Color(red: 0.02, green: 0.11, blue: 0.16).opacity(0.74)
    }

    private var borderColor: Color {
        theme == .sunset ? Color.white.opacity(0.34) : Color.white.opacity(0.13)
    }
}

struct NightSoundsSheet: View {
    @EnvironmentObject private var engine: NightEngine
    @Environment(\.dismiss) private var dismiss
    let entry: DreamEntry
    let theme: SleepTheme
    @State private var selectedKind: SleepAudioEvent.Kind?

    var body: some View {
        NavigationStack {
            ZStack {
                SleepBackdrop(theme: theme)
                    .ignoresSafeArea()
                    .overlay(theme == .sunset ? Color.white.opacity(0.54) : Color.black.opacity(0.22))

                VStack(alignment: .leading, spacing: 14) {
                    filterRow

                    if filteredClips.isEmpty {
                        Text(L("No hay clips de este tipo."))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 32)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 10) {
                                ForEach(filteredClips) { clip in
                                    clipRow(clip)
                                }
                            }
                            .padding(.bottom, 18)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(L("Ruidos nocturnos"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(LF("%@ clips", String(describing: filteredClips.count)))
                        .font(.caption.weight(.black))
                        .foregroundStyle(theme.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("Cerrar")) {
                        engine.stopPreview()
                        dismiss()
                    }
                    .font(.headline.weight(.bold))
                }
            }
            .preferredColorScheme(theme == .night ? .dark : .light)
        }
        .onDisappear { engine.stopPreview() }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton(L("Todos"), kind: nil)
                filterButton(L("Ronquidos"), kind: .snore)
                filterButton(L("Respiración"), kind: .strongBreathing)
                filterButton(L("Tos"), kind: .cough)
                filterButton(L("Voz"), kind: .talking)
            }
        }
    }

    private func filterButton(_ title: String, kind: SleepAudioEvent.Kind?) -> some View {
        Button {
            selectedKind = kind
        } label: {
            Text(title)
                .font(.caption.weight(.black))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(selectedKind == kind ? theme.primary.opacity(0.24) : optionFill)
                .foregroundStyle(selectedKind == kind ? theme.primary : theme.text)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func clipRow(_ clip: SleepSoundClip) -> some View {
        Button {
            play(clip)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.74), lineWidth: 2)
                    Image(systemName: engine.previewID == clip.id.uuidString ? "pause.fill" : "play.fill")
                        .font(.subheadline.weight(.black))
                }
                .frame(width: 40, height: 40)
                .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(Self.timeFormatter.string(from: clip.date))
                            .font(.subheadline.weight(.black))
                        Text(clip.kind.title)
                            .font(.caption.weight(.black))
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(clip.kind.color.opacity(0.16))
                            .foregroundStyle(clip.kind.color)
                            .clipShape(Capsule())
                        Spacer()
                        Text(durationText(for: clip))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.secondaryText)
                    }
                    waveform(color: clip.kind.color)
                }
            }
            .padding(12)
            .background(panelFill)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.text)
    }

    private func waveform(color: Color) -> some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<22, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(index % 3 == 0 ? 0.80 : 0.42))
                    .frame(width: 3, height: CGFloat(7 + (index * 5) % 18))
            }
        }
        .frame(height: 26, alignment: .center)
    }

    private var filteredClips: [SleepSoundClip] {
        entry.soundClips
            .filter { selectedKind == nil || $0.kind == selectedKind }
            .sorted { $0.date > $1.date }
    }

    private var panelFill: Color {
        theme == .sunset ? Color.white.opacity(0.66) : Color.white.opacity(0.09)
    }

    private var optionFill: Color {
        theme == .sunset ? Color.white.opacity(0.34) : Color.white.opacity(0.07)
    }

    private func play(_ clip: SleepSoundClip) {
        engine.playPreview(clip.id.uuidString, url: clip.fileURL)
    }

    private func durationText(for clip: SleepSoundClip) -> String {
        guard let player = try? AVAudioPlayer(contentsOf: clip.fileURL) else { return "--" }
        let seconds = max(1, Int(player.duration.rounded()))
        return String(format: "0:%02d", min(seconds, 59))
    }

    private static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}

struct SleepStageChart: View {
    @EnvironmentObject private var dreams: DreamStore
    @EnvironmentObject private var store: AlarmStore
    let entry: DreamEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(L("Gráfica de sueño"))
                    .font(.system(size: 19, weight: .bold))
                Spacer()
            }

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    legend(L("Despierto"), color: Color(red: 0.94, green: 0.45, blue: 0.17))
                    legend(L("Ligero"), color: Color(red: 0.19, green: 0.55, blue: 0.92))
                    legend(L("Profundo"), color: Color(red: 0.45, green: 0.25, blue: 0.90))
                    legend(L("REM"), color: Color(red: 0.20, green: 0.78, blue: 0.78))
                }
                .frame(width: 80, alignment: .leading)

                VStack(spacing: 6) {
                    GeometryReader { proxy in
                        let samples = chartSamples
                        ZStack(alignment: .bottomLeading) {
                            chartBase(size: proxy.size)
                            if samples.isEmpty {
                                Text(L("Sin datos"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(store.sleepTheme.secondaryText.opacity(0.82))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                chartArea(samples: samples, size: proxy.size)
                                soundMarkers(samples: samples, size: proxy.size)
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                    }
                    .frame(height: 94)

                    HStack {
                        let labels = timeLabels(for: chartSamples)
                        ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                            Text(label)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : index == labels.count - 1 ? .trailing : .center)
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(store.sleepTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .clipped()
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .background(panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
        .foregroundStyle(store.sleepTheme.text)
    }

    private var chartSamples: [SleepStageSample] {
        dreams.healthSamples(for: entry.day)
    }

    private func chartBase(size: CGSize) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height - 1))
            path.addLine(to: CGPoint(x: size.width, y: size.height - 1))
        }
        .stroke(store.sleepTheme.secondaryText.opacity(0.20), lineWidth: 1)
    }

    private func chartArea(samples: [SleepStageSample], size: CGSize) -> some View {
        let start = samples.first?.date ?? Date()
        let end = samples.map { $0.endDate ?? $0.date }.max() ?? start
        let duration = max(1, end.timeIntervalSince(start))
        return ZStack(alignment: .topLeading) {
            ForEach(samples) { sample in
                let x = sample.date.timeIntervalSince(start) / duration * size.width
                let width = max(1, (sample.endDate ?? sample.date).timeIntervalSince(sample.date) / duration * size.width)
                RoundedRectangle(cornerRadius: 2)
                    .fill(stageColor(sample.stage).opacity(0.85))
                    .frame(width: width, height: 12)
                    .offset(x: x, y: yPosition(for: sample.stage, height: size.height))
            }
        }
    }
    private func stageColor(_ stage: SleepStageSample.Stage) -> Color {
        switch stage {
        case .awake: return Color(red: 0.94, green: 0.45, blue: 0.17)
        case .light: return Color(red: 0.19, green: 0.55, blue: 0.92)
        case .deep: return Color(red: 0.45, green: 0.25, blue: 0.90)
        case .rem: return Color(red: 0.20, green: 0.78, blue: 0.78)
        }
    }

    private func soundMarkers(samples: [SleepStageSample], size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(samples.enumerated()), id: \.element.id) { index, sample in
                if sample.soundEvents > 0 {
                    let x = CGFloat(index) / CGFloat(max(samples.count - 1, 1)) * size.width
                    VStack(spacing: 0) {
                        Circle()
                            .stroke(Color(red: 0.94, green: 0.45, blue: 0.17), lineWidth: 1.4)
                            .background(Circle().fill(Color.black.opacity(0.24)))
                            .overlay(DiaryAssetImage(name: "sound-wave").padding(5))
                            .frame(width: 28, height: 28)
                        Rectangle()
                            .fill(Color.white.opacity(0.42))
                            .frame(width: 1, height: max(0, size.height - 28))
                    }
                    .offset(x: min(max(0, x - 14), max(0, size.width - 28)), y: 4)
                }
            }
        }
    }

    private func yPosition(for stage: SleepStageSample.Stage, height: CGFloat) -> CGFloat {
        switch stage {
        case .awake: return height * 0.18
        case .light: return height * 0.42
        case .deep: return height * 0.70
        case .rem: return height * 0.30
        }
    }

    private func legend(_ text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
    }

    private func timeLabels(for samples: [SleepStageSample]) -> [String] {
        guard let first = samples.first?.date, let last = samples.map({ $0.endDate ?? $0.date }).max(), last > first else {
            return ["--:--", "--:--", "--:--", "--:--"]
        }
        let interval = last.timeIntervalSince(first)
        return [0, 1, 2, 3].map { index in
            let date = first.addingTimeInterval(interval * Double(index) / 3.0)
            return Self.timeFormatter.string(from: date)
        }
    }

    private static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private var panelFill: Color {
        store.sleepTheme == .sunset ? Color.white.opacity(0.50) : Color(red: 0.02, green: 0.11, blue: 0.16).opacity(0.74)
    }

    private var borderColor: Color {
        store.sleepTheme == .sunset ? Color.white.opacity(0.34) : Color.white.opacity(0.13)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var dreams: DreamStore
    @State private var editingSleepAlarm = false
    @State private var showingSubscriptionSetup = false
    @State private var supportExpanded = false
    @State private var confirmingDeleteSounds = false

    var body: some View {
        NavigationStack {
            ZStack {
                SleepBackdrop(theme: store.sleepTheme)
                    .ignoresSafeArea()
                    .overlay(store.sleepTheme == .sunset ? Color.white.opacity(0.52) : Color.black.opacity(0.20))

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        settingsGroup(L("Idioma"), systemImage: "globe") {
                            Picker(L("Idioma"), selection: $store.language) {
                                Text(L("Sistema")).tag(AppLanguage.system)
                                Text(L("Castellano")).tag(AppLanguage.es)
                                Text(L("English")).tag(AppLanguage.en)
                            }.pickerStyle(.segmented).accessibilityIdentifier("language-picker")
                        }
                        settingsGroup(L("Apariencia"), systemImage: "circle.lefthalf.filled") {
                            Picker(L("Tema"), selection: $store.appearance) {
                                ForEach(AppAppearance.allCases) { appearance in
                                    Text(appearance.title).tag(appearance)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        settingsGroup(L("Seguimiento nocturno"), systemImage: "waveform") {
                            settingToggle(L("Abrir diario al terminar alarma"), isOn: $store.openJournalAfterAlarm)
                            settingToggle(L("Grabar sonidos nocturnos"), isOn: $store.sleepRecordingEnabled)
                            nightSoundRetentionControls
                            Button(L("Conectar con Salud")) { Task { await dreams.connectHealth() } }
                            Text(L("Las fases de sueño proceden de Salud. Sin registros compatibles, la gráfica permanece vacía.")).font(.caption)
                            if let message = dreams.healthMessage { Text(message).font(.caption) }
                            Text(L("La detección de ronquidos, respiración fuerte, tos y voz se guarda localmente como estimación."))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(store.sleepTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        settingsGroup(L("Despertar"), systemImage: "sunrise.fill") {
                            settingToggle(L("Mover para posponer"), isOn: Binding(
                                get: { store.sleepAlarm.motionSnooze },
                                set: { enabled in
                                    var alarm = store.sleepAlarm
                                    alarm.motionSnooze = enabled
                                    store.updateSleepAlarm(alarm)
                                }
                            ))
                            settingRow(L("Posponer"), value: "\(store.sleepAlarm.snoozeMinutes) min")
                            snoozeSelector

                            Divider().opacity(0.28)

                            settingToggle(L("Luz progresiva"), isOn: Binding(
                                get: { store.sleepAlarm.lightWakeEnabled },
                                set: { enabled in
                                    var alarm = store.sleepAlarm
                                    alarm.lightWakeEnabled = enabled
                                    store.updateSleepAlarm(alarm)
                                }
                            ))
                            if store.sleepAlarm.lightWakeEnabled {
                                lightWakeSelector
                            }

                            Button {
                                editingSleepAlarm = true
                            } label: {
                                Label(L("Editar alarma"), systemImage: "slider.horizontal.3")
                                    .font(.headline.weight(.black))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(store.sleepTheme.primary)
                                    .foregroundStyle(store.sleepTheme == .sunset ? .white : Color(red: 0.01, green: 0.06, blue: 0.08))
                                    .clipShape(Capsule())
                            }
                        }

                        if store.monetizationEnabled {
                            supportGroup
                        }

                        Text(appIdentityText)
                            .font(.caption.weight(.black))
                            .foregroundStyle(store.sleepTheme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 6)
                    }
                    .padding(20)
                    .foregroundStyle(store.sleepTheme.text)
                }
            }
            .navigationTitle(L("Ajustes"))
            .preferredColorScheme(store.sleepTheme == .night ? .dark : .light)
            .sheet(isPresented: $editingSleepAlarm) {
                EditAlarmView(
                    alarm: store.sleepAlarm,
                    theme: store.sleepTheme,
                    onSave: { updated in store.updateSleepAlarm(updated) },
                    onDelete: nil
                )
            }
            .alert(L("Suscripción pendiente"), isPresented: $showingSubscriptionSetup) {
                Button(L("Entendido"), role: .cancel) {}
            } message: {
                Text(L("El apoyo mensual estará disponible en una próxima versión. Todavía no hay compras que restaurar."))
            }
            .alert(L("Eliminar sonidos nocturnos"), isPresented: $confirmingDeleteSounds) {
                Button(L("Eliminar todos"), role: .destructive) {
                    dreams.deleteAllSoundClips()
                }
                Button(L("Cancelar"), role: .cancel) {}
            } message: {
                Text(L("Se borrarán los clips de audio guardados y los contadores de ruidos del diario."))
            }
        }
    }

    private var nightSoundRetentionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("Eliminar sonidos"))
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(dreams.soundStorageText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(store.sleepTheme.secondaryText)
                Picker(L("Eliminar sonidos"), selection: Binding(
                    get: { store.nightSoundRetention },
                    set: { retention in
                        store.nightSoundRetention = retention
                        dreams.pruneSoundClips(olderThanDays: retention.days)
                    }
                )) {
                    ForEach(NightSoundRetention.allCases) { retention in
                        Text(retention.title).tag(retention)
                    }
                }
                .pickerStyle(.menu)
                .tint(store.sleepTheme.primary)
            }

            Button {
                confirmingDeleteSounds = true
            } label: {
                Label(L("Eliminar todos los sonidos"), systemImage: "trash")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.red.opacity(store.sleepTheme == .sunset ? 0.12 : 0.18))
                    .foregroundStyle(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private var supportGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    supportExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Label(L("Apoyar la app"), systemImage: "heart.fill")
                        .font(.headline.weight(.black))

                    Spacer()

                    Text(store.adsRemoved ? L("Activo") : L("Opcional"))
                        .font(.caption.weight(.black))
                        .foregroundStyle(store.sleepTheme.secondaryText)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.black))
                        .rotationEffect(.degrees(supportExpanded ? 180 : 0))
                        .foregroundStyle(store.sleepTheme.secondaryText)
                }
                .foregroundStyle(store.sleepTheme.text)
            }
            .buttonStyle(.plain)

            if supportExpanded {
                HStack(spacing: 12) {
                    Image(systemName: store.adsRemoved ? "checkmark.seal.fill" : "rectangle.badge.xmark")
                        .font(.title3.weight(.black))
                        .foregroundStyle(store.adsRemoved ? Color.green : store.sleepTheme.primary)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.adsRemoved ? L("Sin anuncios activo") : L("Próximamente"))
                            .font(.subheadline.weight(.black))
                        Text(L("El apoyo mensual todavía no está disponible. No se realizará ningún cargo."))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(store.sleepTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(AppMonetizationConfig.monthlySupportOptions, id: \.self) { amount in
                        Text(amount)
                            .font(.caption.weight(.black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(Color.white.opacity(store.sleepTheme == .sunset ? 0.30 : 0.07))
                            .foregroundStyle(store.sleepTheme.text)
                            .clipShape(Capsule())
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                Button {
                    showingSubscriptionSetup = true
                } label: {
                    Label(L("Quitar anuncios"), systemImage: "sparkles")
                        .font(.headline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(store.sleepTheme.primary)
                        .foregroundStyle(store.sleepTheme == .sunset ? .white : Color(red: 0.01, green: 0.06, blue: 0.08))
                        .clipShape(Capsule())
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                Button {
                    showingSubscriptionSetup = true
                } label: {
                    Text(L("Restaurar compras"))
                        .font(.subheadline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.white.opacity(store.sleepTheme == .sunset ? 0.30 : 0.07))
                        .foregroundStyle(store.sleepTheme.text)
                        .clipShape(Capsule())
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(store.sleepTheme == .sunset ? Color.white.opacity(0.62) : Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func settingsGroup<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.black))
            content()
        }
        .padding(16)
        .background(store.sleepTheme == .sunset ? Color.white.opacity(0.62) : Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func settingRow(_ title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.black))
                .foregroundStyle(store.sleepTheme.secondaryText)
        }
        .font(.subheadline.weight(.bold))
    }

    private func settingToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.subheadline.weight(.bold))
        }
        .tint(store.sleepTheme.primary)
    }

    private var appIdentityText: String {
        let name = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? L("Alarma")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev"
        return "\(name) iPhone - v\(version) build \(build)"
    }

    private var lightWakeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("La pantalla se ilumina al sonar"))
                .font(.caption.weight(.bold))
                .foregroundStyle(store.sleepTheme.secondaryText)
            HStack(spacing: 8) {
                ForEach([3, 5, 10, 15], id: \.self) { minutes in
                    Button {
                        var alarm = store.sleepAlarm
                        alarm.lightWakeMinutes = minutes
                        store.updateSleepAlarm(alarm)
                    } label: {
                        Text("\(minutes) min")
                            .font(.caption.weight(.black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(store.sleepAlarm.lightWakeMinutes == minutes ? store.sleepTheme.primary.opacity(0.22) : Color.white.opacity(store.sleepTheme == .sunset ? 0.30 : 0.07))
                            .foregroundStyle(store.sleepAlarm.lightWakeMinutes == minutes ? store.sleepTheme.primary : store.sleepTheme.text)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var snoozeSelector: some View {
        HStack(spacing: 8) {
                ForEach([1, 3, 5, 10, 15], id: \.self) { minutes in
                Button {
                    var alarm = store.sleepAlarm
                    alarm.snoozeMinutes = minutes
                    store.updateSleepAlarm(alarm)
                } label: {
                    Text("\(minutes) min")
                        .font(.caption.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(store.sleepAlarm.snoozeMinutes == minutes ? store.sleepTheme.primary.opacity(0.22) : Color.white.opacity(store.sleepTheme == .sunset ? 0.30 : 0.07))
                        .foregroundStyle(store.sleepAlarm.snoozeMinutes == minutes ? store.sleepTheme.primary : store.sleepTheme.text)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

