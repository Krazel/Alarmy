import SwiftUI

struct DayFeeling: View {
    let feeling: MorningFeeling?
    var body: some View {
        if let feeling { FeelingFace(feeling: feeling) }
        else { Text("–").font(.caption2).foregroundStyle(Color.ink.opacity(0.3)).accessibilityHidden(true) }
    }
}

struct JournalCalendar: View {
    @EnvironmentObject var store: SleepStore
    @Environment(\.dismiss) private var dismiss
    @State private var month: Date
    init(month: Date) { _month = State(initialValue: month) }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private var dates: [Date?] { CalendarDay.month(around: month) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    PageHeading(title: store.words("calendar"))
                    HStack {
                        Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel(store.words("previousMonth"))
                        Spacer()
                        Text(month.formatted(.dateTime.month(.wide).year().locale(store.words.locale))).font(.system(size: 21, design: .serif))
                        Spacer()
                        Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.disabled(Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)).accessibilityLabel(store.words("nextMonth"))
                    }
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(CalendarDay.week(around: month).enumerated()), id: \.offset) { _, day in
                            Text(day.formatted(.dateTime.weekday(.abbreviated).locale(store.words.locale))).font(.caption2).foregroundStyle(Color.ink.opacity(0.6))
                        }
                        ForEach(dates.indices, id: \.self) { index in
                            if let day = dates[index] {
                                let selected = Calendar.current.isDate(day, inSameDayAs: store.selectedDay)
                                let future = Calendar.current.startOfDay(for: day) > Calendar.current.startOfDay(for: Date())
                                Button { store.selectedDay = day } label: {
                                    VStack(spacing: 3) {
                                        Text(day.formatted(.dateTime.day())).font(.system(size: 15, weight: selected ? .semibold : .regular))
                                        DayFeeling(feeling: store.page(day).feeling).frame(width: 22, height: 22)
                                    }.frame(maxWidth: .infinity, minHeight: 55).foregroundStyle(selected ? Color.paper : Color.ink)
                                        .background(selected ? Color.ink : Color.clear, in: RoundedRectangle(cornerRadius: 16))
                                        .opacity(future ? 0.25 : 1)
                                }.disabled(future).accessibilityIdentifier("calendar-day-" + CalendarDay.key(day))
                                    .accessibilityLabel(day.formatted(date: .complete, time: .omitted) + ", " + store.words(store.page(day).feeling?.key ?? "unrated"))
                                    .accessibilityAddTraits(selected ? .isSelected : [])
                            } else { Color.clear.frame(height: 55).accessibilityHidden(true) }
                        }
                    }
                    Text(store.words("calendarFeelingHint")).font(.caption).foregroundStyle(Color.ink.opacity(0.6))
                    PaperCard(padding: 12) { HStack(alignment: .top, spacing: 3) {
                        ForEach(MorningFeeling.allCases) { feeling in
                            VStack(spacing: 6) {
                                FeelingFace(feeling: feeling).frame(width: 32, height: 32)
                                Text(store.words(feeling.key)).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.7)
                            }.frame(maxWidth: .infinity)
                        }
                    } }
                    PaperCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(store.selectedDay.formatted(.dateTime.day().month(.wide).locale(store.words.locale))).font(.system(size: 24, design: .serif))
                                Spacer(); DayFeeling(feeling: store.page(store.selectedDay).feeling).frame(width: 38, height: 38)
                            }
                            if !store.page(store.selectedDay).text.isEmpty { Text(store.page(store.selectedDay).text).font(.subheadline).lineLimit(3) }
                            Button { dismiss() } label: { Label(store.words("openDay"), systemImage: "chevron.right") }.accessibilityIdentifier("open-calendar-day")
                        }
                    }
                }.padding(20)
            }.background(Color.paper).foregroundStyle(Color.ink).tint(.rust)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.words("done")) { dismiss() }.accessibilityIdentifier("close-journal-calendar") } }
        }
    }
    private func move(_ value: Int) {
        if let start = Calendar.current.dateInterval(of: .month, for: month)?.start,
           let next = Calendar.current.date(byAdding: .month, value: value, to: start) { month = next }
    }
}
