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
    @State private var showMonthSheet: Bool = false
    @State private var quickMemoText: String = ""

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

    private func weekCalendarHeight(_ totalHeight: CGFloat) -> CGFloat {
        let basePadding: CGFloat = 12
        return max(140, totalHeight * 0.22) + basePadding
    }

    var body: some View {
        NavigationView {
            GeometryReader { proxy in
                let totalHeight = proxy.size.height
                let calendarHeight = self.weekCalendarHeight(totalHeight)
                let imageMaxHeight = max(200, (totalHeight - calendarHeight) * 0.72)
                ZStack {
                    VStack(spacing: 0) {
                        // Week calendar (default)
                        WeekCalendarView(
                            selectedDate: $selectedDate,
                            datesWithEntries: datesWithEntries
                        )
                        .frame(height: calendarHeight)
                        .padding(.top, 0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: selectedDate)

                        // Selected day preview (image + memo)
                        let filteredEntries = entries.filter {
                            guard let entryDate = $0.date else { return false }
                            return Calendar.current.isDate(entryDate, inSameDayAs: selectedDate)
                        }

                        if let firstEntry = filteredEntries.sorted(by: { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }).first {
                            VStack(spacing: 6) {
                        if let data = firstEntry.imageData, let uiImg = UIImage(data: data) {
                            FramedPhotoView(image: uiImg, maxHeight: imageMaxHeight)
                                .padding(.horizontal, 10)
                                .padding(.top, 0)
                                .onTapGesture { selectedEntryForViewing = firstEntry }
                        }
                        let memoText = (firstEntry.memo ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !memoText.isEmpty {
                            Text(memoText)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                )
                                .padding(.horizontal, 10)
                        } else {
                            Text("메모가 없습니다")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                        }
                        HStack {
                            Spacer()
                            Button { selectedEntryForViewing = firstEntry } label: { Label("자세히", systemImage: "chevron.right.circle.fill") }
                                .buttonStyle(.bordered)
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                    }
                        } else {
                            VStack(spacing: 12) {
                                Spacer()
                                Text("해당 날짜의 기록이 없습니다.")
                                    .foregroundColor(.gray)
                                Button { showingAddEntry = true } label: { Label("첫 기록 추가", systemImage: "plus") }
                                    .buttonStyle(.bordered)
                                Spacer()
                            }
                        }
                    }
                }
                // Month popover-like overlay anchored below the navigation bar (centered)
                .overlay(alignment: .top) {
                    Group {
                        if showMonthSheet {
                            // light scrim
                            Color.black.opacity(0.08)
                                .ignoresSafeArea()
                                .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { showMonthSheet = false } }
                                .zIndex(1)

                            VStack(spacing: 12) {
                                HStack {
                                    Spacer()
                                    Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { showMonthSheet = false } }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                CustomCalendarView(
                                    selectedDate: $selectedDate,
                                    datesWithEntries: datesWithEntries,
                                    thumbnailProvider: { day in
                                        if let entry = entries.first(where: { e in
                                            guard let d = e.date else { return false }
                                            return Calendar.current.isDate(d, inSameDayAs: day) && e.imageData != nil
                                        }), let data = entry.imageData, let ui = UIImage(data: data) {
                                            return ui
                                        }
                                        return nil
                                    }
                                )
                            }
                            .padding(14)
                            .frame(width: min(360, proxy.size.width - 28))
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
                            .padding(.top, proxy.safeAreaInsets.top + 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .gesture(
                                DragGesture().onEnded { value in
                                    if value.translation.height > 80 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { showMonthSheet = false }
                                    }
                                }
                            )
                            .zIndex(2)
                        }
                    }
                }
            }
            .onAppear {
                updateDatesWithEntries()
                selectedDate = Calendar.current.startOfDay(for: selectedDate)
                let firstEntry = entries.filter { entry in
                    guard let d = entry.date else { return false }
                    return Calendar.current.isDate(d, inSameDayAs: selectedDate)
                }.sorted(by: { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }).first
                quickMemoText = firstEntry?.memo ?? ""
            }
            .onReceive(entries.publisher.collect()) { _ in
                updateDatesWithEntries()
                print("📥 Entries updated - count:", entries.count)
                selectedDate = Calendar.current.startOfDay(for: selectedDate)
                let firstEntry = entries.filter { entry in
                    guard let d = entry.date else { return false }
                    return Calendar.current.isDate(d, inSameDayAs: selectedDate)
                }.sorted(by: { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }).first
                quickMemoText = firstEntry?.memo ?? ""
            }
            .onChange(of: selectedDate) {
                updateDatesWithEntries()
                print("📌 Selected date changed to:", selectedDate)
                let firstEntry = entries.filter { entry in
                    guard let d = entry.date else { return false }
                    return Calendar.current.isDate(d, inSameDayAs: selectedDate)
                }.sorted(by: { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }).first
                quickMemoText = firstEntry?.memo ?? ""
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showMonthSheet = true }) {
                        Image(systemName: "calendar")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("hp 사진메모")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.bottom, -6) // tighten gap to content
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddEntry = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            // remove sheet; use overlay popup instead
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
    var thumbnailProvider: ((Date) -> UIImage?)? = nil
    var onSelectDay: (() -> Void)? = nil

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
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Button(action: {
                    if let previous = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
                        selectedDate = previous
                    }
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white, .blue)
                        .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                Spacer()
                Text(monthYearString(from: selectedDate))
                    .font(.title3).bold()
                Spacer()
                Button(action: {
                    if let next = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
                        selectedDate = next
                    }
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white, .blue)
                        .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                Button("오늘") {
                    selectedDate = calendar.startOfDay(for: Date())
                    onSelectDay?()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(["일", "월", "화", "수", "목", "금", "토"].indices, id: \.self) { idx in
                    let day = ["일", "월", "화", "수", "목", "금", "토"][idx]
                    Text(day)
                        .font(.subheadline).bold()
                        .frame(maxWidth: .infinity)
                        .foregroundColor(idx == 0 ? .red : (idx == 6 ? .blue : .primary))
                }
                ForEach(currentMonthDates, id: \.self) { date in
                    if calendar.isDate(date, equalTo: Date.distantPast, toGranularity: .day) {
                        Color.clear.frame(height: 38)
                    } else {
                        let day = calendar.startOfDay(for: date)
                        let isSelected = calendar.isDate(day, inSameDayAs: calendar.startOfDay(for: selectedDate))
                        let hasEntry = datesWithEntries.contains(where: { calendar.isDate($0, inSameDayAs: day) })
                        let today = calendar.startOfDay(for: Date())
                        let isToday = calendar.isDate(day, inSameDayAs: today)

                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(AppTheme.brandGradient)
                                    .frame(width: 36, height: 36)
                                    .shadow(color: Color.blue.opacity(0.45), radius: 8, x: 0, y: 4)
                            } else if isToday {
                                Circle()
                                    .stroke(AppTheme.brandGradient, lineWidth: 2)
                                    .frame(width: 36, height: 36)
                            }
                            if let provider = thumbnailProvider, let ui = provider(day) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 34, height: 34)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                isSelected ? Color.white : (isToday ? Color.blue : Color.clear),
                                                lineWidth: isSelected ? 2 : (isToday ? 2 : 0)
                                            )
                                    )
                            } else {
                                VStack(spacing: 2) {
                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.body.weight(isSelected ? .bold : .regular))
                                        .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))
                                    if hasEntry {
                                        Circle()
                                            .fill(isSelected ? Color.white : Color.blue)
                                            .frame(width: 6, height: 6)
                                            .offset(y: 2)
                                    } else {
                                        Spacer().frame(height: 8)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .contentShape(Circle())
                        .onTapGesture {
                            selectedDate = calendar.startOfDay(for: date)
                            onSelectDay?()
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.top, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(AppTheme.subtleBrand)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        )
        .padding(.horizontal)
        .padding(.bottom, 0) // flush to the next photo card
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: date)
    }
}

// (Removed segmented scope selection; keeping only week view by default.)

// MARK: - Week Calendar View
struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    let datesWithEntries: Set<Date>

    private let calendar = Calendar.current

    private var weekDays: [Date] {
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }.map { calendar.startOfDay(for: $0) }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    if let prev = calendar.date(byAdding: .day, value: -7, to: selectedDate) { selectedDate = prev }
                } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(weekTitle)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button {
                    if let next = calendar.date(byAdding: .day, value: 7, to: selectedDate) { selectedDate = next }
                } label: { Image(systemName: "chevron.right") }
                Button("오늘") {
                    selectedDate = calendar.startOfDay(for: Date())
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                ForEach(weekDays, id: \.self) { day in
                    let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                    let isToday = calendar.isDateInToday(day)
                    let hasEntry = datesWithEntries.contains { calendar.isDate($0, inSameDayAs: day) }

                    VStack(spacing: 6) {
                        Text(weekdayString(for: day))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 44, height: 44)
                            } else if isToday {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                                    .frame(width: 44, height: 44)
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray6))
                                    .frame(width: 44, height: 44)
                            }

                            Text("\(calendar.component(.day, from: day))")
                                .font(.body.weight(isSelected ? .bold : .regular))
                                .foregroundColor(isSelected ? .white : .primary)
                        }

                        if hasEntry { Circle().fill(Color.blue).frame(width: 5, height: 5) }
                        else { Spacer().frame(height: 5) }
                    }
                    .onTapGesture { selectedDate = day }
                }
            }
            .padding(.horizontal)
        }
            .padding(.vertical, 0)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 18
            )
            .fill(LinearGradient(colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .padding(.horizontal, 10)
    }

    private var weekTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        let start = weekDays.first ?? selectedDate
        let end = weekDays.last ?? selectedDate
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private func weekdayString(for date: Date) -> String {
        let idx = calendar.component(.weekday, from: date)
        return ["일","월","화","수","목","금","토"][max(0, idx-1)]
    }
}

// MARK: - Day Header View
struct DayHeaderView: View {
    @Binding var selectedDate: Date
    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 16) {
            Button { if let prev = calendar.date(byAdding: .day, value: -1, to: selectedDate) { selectedDate = prev } } label: { Image(systemName: "chevron.left") }
            Spacer()
            VStack(spacing: 4) {
                Text(dayTitle)
                    .font(.title3).bold()
                Text(weekday)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button { if let next = calendar.date(byAdding: .day, value: 1, to: selectedDate) { selectedDate = next } } label: { Image(systemName: "chevron.right") }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .padding(.horizontal)
    }

    private var dayTitle: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy년 M월 d일"
        return f.string(from: selectedDate)
    }
    private var weekday: String {
        let idx = calendar.component(.weekday, from: selectedDate)
        return ["일요일","월요일","화요일","수요일","목요일","금요일","토요일"][max(0, idx-1)]
    }
}

// MARK: - Framed Photo View
struct FramedPhotoView: View {
    let image: UIImage
    let maxHeight: CGFloat

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: 18,
            topTrailingRadius: 0
        )
        ZStack {
            // Matte (액자 안쪽 배경)
            shape
                .fill(Color(.systemBackground))
                .overlay(
                    // 바깥 프레임 테두리
                    shape.stroke(Color.black.opacity(0.08), lineWidth: 2)
                )
                .overlay(
                    // 안쪽 하이라이트(얇은 광택)로 깊이감
                    shape.inset(by: 2).stroke(Color.white.opacity(0.55), lineWidth: 0.5)
                )
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 8) // no top/bottom matte
        }
        .frame(maxHeight: maxHeight)
        .clipShape(shape)
        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
    }
}

