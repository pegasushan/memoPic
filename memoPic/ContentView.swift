import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<DiaryEntry>

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var datesWithEntries: Set<Date> = []
    @State private var showingAddEntry = false
    @State private var editingEntry: DiaryEntry? = nil
    @State private var selectedImage: UIImage? = nil

    @State private var showImagePicker = false
    @State private var selectedEntryForViewing: DiaryEntry? = nil

    private let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "a h:mm"
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = .current
        return f
    }()

    private func updateDatesWithEntries() {
        datesWithEntries = Set(
            entries.compactMap { $0.date }.map {
                Calendar.current.startOfDay(for: $0)
            }
        )
        print("📅 datesWithEntries updated:", datesWithEntries.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .none) })
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Upper half: Calendar
                CustomCalendarView(
                    selectedDate: $selectedDate,
                    datesWithEntries: datesWithEntries
                )
                .id(selectedDate.hashValue ^ datesWithEntries.hashValue)
                .frame(height: UIScreen.main.bounds.height * 0.4)
                .padding(.vertical)

                Divider()

                // Lower half: Entries list
                let filteredEntries = entries.filter {
                    guard let entryDate = $0.date else { return false }
                    return Calendar.current.isDate(entryDate, inSameDayAs: selectedDate)
                }

                if filteredEntries.isEmpty {
                    VStack {
                        Spacer()
                        Text("해당 날짜의 기록이 없습니다.")
                            .foregroundColor(.gray)
                            .padding()
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredEntries, id: \.self) { entry in
                            HStack {
                                Text(entry.memo ?? "")
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                                if let date = entry.date {
                                    Text(shortTimeFormatter.string(from: date))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntryForViewing = entry
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewContext.delete(entry)
                                    try? viewContext.save()
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .onAppear {
                updateDatesWithEntries()
                selectedDate = Calendar.current.startOfDay(for: selectedDate)
            }
            .onReceive(entries.publisher.collect()) { _ in
                updateDatesWithEntries()
                print("📥 Entries updated - count:", entries.count)
                selectedDate = Calendar.current.startOfDay(for: selectedDate)
            }
            .onChange(of: selectedDate) { _ in
                updateDatesWithEntries()
                print("📌 Selected date changed to:", selectedDate)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("memoPic")
                        .font(.system(size: 15, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddEntry = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddEntryView(date: selectedDate)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $editingEntry) { entry in
                NavigationView {
                    VStack(spacing: 16) {
                        if let imageData = entry.imageData,
                           let baseImage = UIImage(data: imageData) {
                            Image(uiImage: selectedImage ?? baseImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(10)
                        }

                        Button("사진 변경") {
                            showImagePicker = true
                        }
                        .sheet(isPresented: $showImagePicker) {
                            ImagePicker(isPresented: $showImagePicker, imageHandler: { image in
                                selectedImage = image
                            })
                        }

                        TextEditor(text: Binding(
                            get: { entry.memo ?? "" },
                            set: { entry.memo = $0 }
                        ))
                        .padding()
                        .frame(maxHeight: 200)
                        .border(Color.gray)

                        Button("저장") {
                            if let image = selectedImage {
                                entry.imageData = image.jpegData(compressionQuality: 0.8)
                            }
                            try? viewContext.save()
                            editingEntry = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()

                        Spacer()
                    }
                    .padding()
                    .navigationTitle("메모 수정")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(item: $selectedEntryForViewing) { entry in
                EntryDetailView(entry: entry)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
}

// Replace CalendarViewOverlay with this new view
struct CustomCalendarView: View {
    @Binding var selectedDate: Date
    let datesWithEntries: Set<Date>

    private let calendar = Calendar.current
    private var currentMonthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) else { return [] }
        var dates: [Date] = []
        var current = monthInterval.start
        while current < monthInterval.end {
            dates.append(calendar.startOfDay(for: current))
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        // Add leading empty days
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        let leadingDates = Array(repeating: Date.distantPast, count: leadingEmptyDays)

        // Add trailing empty days to fill last week
        let totalItems = leadingDates.count + dates.count
        let trailingEmptyDays = (7 - (totalItems % 7)) % 7
        let trailingDates = Array(repeating: Date.distantPast, count: trailingEmptyDays)

        return leadingDates + dates + trailingDates
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(monthYearString(from: selectedDate))
                    .font(.headline)
                Spacer()
                Button(action: {
                    if let previous = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
                        selectedDate = previous
                    }
                }) {
                    Image(systemName: "chevron.left")
                }
                Button(action: {
                    if let next = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
                        selectedDate = next
                    }
                }) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)

            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                ForEach(currentMonthDates, id: \.self) { date in
                    if calendar.isDate(date, equalTo: Date.distantPast, toGranularity: .day) {
                        Color.clear.frame(height: 32)
                    } else {
                        let day = calendar.startOfDay(for: date)
                        let isSelected = calendar.isDate(day, inSameDayAs: calendar.startOfDay(for: selectedDate))
                        let hasEntry = datesWithEntries.contains(where: { calendar.isDate($0, inSameDayAs: day) })
                        let today = calendar.startOfDay(for: Date())
                        let isToday = calendar.isDate(day, inSameDayAs: today)

                        Text("\(calendar.component(.day, from: date))")
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(isToday ? Color.yellow.opacity(0.3) : Color.clear)
                            .foregroundColor({
                                if hasEntry {
                                    return .brown
                                } else {
                                    return .primary
                                }
                            }())
                            .font(hasEntry ? .body.bold() : .body)
                            .clipShape(Circle())
                            .onTapGesture {
                                selectedDate = calendar.startOfDay(for: date)
                            }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: date)
    }
}
