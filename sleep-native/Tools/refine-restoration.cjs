const fs=require('fs');let f='sleep-native/Sources/LegacyViews.swift',s=fs.readFileSync(f,'utf8');
// Remove legacy, unused reminder rows and heuristic score UI.
s=s.slice(0,s.indexOf('struct AlarmRow:'))+s.slice(s.indexOf('struct EditAlarmView:'));
s=s.slice(0,s.indexOf('struct DreamScoreCard:'))+s.slice(s.indexOf('struct SleepStageChart:'));
s=s.replace('                    .foregroundStyle(theme.primary)\n                    Button(L("Hecho"))','                    .foregroundStyle(theme.primary)\n                    .accessibilityLabel(L("Importar canción"))\n                    .accessibilityIdentifier("import-song")\n                    Button(L("Hecho"))').replace('                    .foregroundStyle(theme.primary)\r\n                    Button(L("Hecho"))','                    .foregroundStyle(theme.primary)\r\n                    .accessibilityLabel(L("Importar canción"))\r\n                    .accessibilityIdentifier("import-song")\r\n                    Button(L("Hecho"))');
s=s.replace('            .accessibilityLabel(store.sleepTheme', '            .accessibilityIdentifier("theme-toggle")\n            .accessibilityLabel(store.sleepTheme');
s=s.replace('                .padding(.bottom, 30)\n            }','                .accessibilityIdentifier("start-night")\n                .padding(.bottom, 30)\n            }');
s=s.replace('                .padding(.bottom, 30)\r\n            }','                .accessibilityIdentifier("start-night")\r\n                .padding(.bottom, 30)\r\n            }'); // affects nightly end? specify later
s=s.replace('Button(action: onEdit) {','Button(action: onEdit) {');
s=s.replace('Image(systemName: "pencil")','Image(systemName: "pencil").accessibilityIdentifier("edit-alarm")');
s=s.replace('TextEditor(text: $notes)','TextEditor(text: $notes).accessibilityIdentifier("dream-notes")');
s=s.replace('Text(L("Hoy"))','Text(L("Hoy")).minimumScaleFactor(0.7)');
s=s.replace('Image(systemName: "calendar")','Image(systemName: "calendar").accessibilityIdentifier("full-calendar")');
s=s.replace('Text(mood.title)','Text(mood.title).minimumScaleFactor(0.65).lineLimit(1)');
s=s.replace('            .onChange(of: session.motionProgress) { value in\n                        if value > 0.96 { Task { await session.snooze() } }\n                    }','');
// Mark adjustable hour/minute targets for VoiceOver, keeping the original drag interaction.
s=s.replace('                    .highPriorityGesture(timeDrag(for: .hour, lastStep: $hourStep))','                    .highPriorityGesture(timeDrag(for: .hour, lastStep: $hourStep))');
// Clip sheets must stop playback when swiped away as well as when Close is tapped.
s=s.replace('        .presentationDetents([.medium, .large])', '        .onDisappear { player?.stop(); player = nil; playingClipId = nil }\n        .presentationDetents([.medium, .large])');
// Show measured Health intervals at their actual time positions, including gaps, not an evenly spaced curve.
const start=s.indexOf('    private func chartArea('),end=s.indexOf('    private func soundMarkers(',start);
s=s.slice(0,start)+`    private func chartArea(samples: [SleepStageSample], size: CGSize) -> some View {
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

`+s.slice(end);
s=s.replace('let last = samples.last?.date','let last = samples.map({ $0.endDate ?? $0.date }).max()');
fs.writeFileSync(f,s);
f='sleep-native/Sources/PresentationBridge.swift';s=fs.readFileSync(f,'utf8').replace('result.wakeMood = note?.mood ?? nights.first?.mood','result.wakeMood = note != nil ? note?.mood : nights.first?.mood\n        result.samples = healthSamples(for: date)');fs.writeFileSync(f,s);
