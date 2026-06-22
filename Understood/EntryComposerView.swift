import SwiftUI
import PhotosUI
import UIKit
import CoreLocation
import Combine
import Auth

enum EntryComposerKind: String, CaseIterable, Identifiable {
    case reminder
    case action
    case event

    var id: String { rawValue }
}

private enum Priority: String, Codable, CaseIterable, Identifiable {
    case none, low, medium, high
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    var marks: String {
        switch self {
        case .none: return ""
        case .low: return "!"
        case .medium: return "!!"
        case .high: return "!!!"
        }
    }
}

private enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekdays, weekly, monthly, yearly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Never"
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

private enum EarlyReminder: String, Codable, CaseIterable, Identifiable {
    case none
    case m5 = "5m"
    case m10 = "10m"
    case m30 = "30m"
    case h1 = "1h"
    case d1 = "1d"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .m5: return "5 minutes before"
        case .m10: return "10 minutes before"
        case .m30: return "30 minutes before"
        case .h1: return "1 hour before"
        case .d1: return "1 day before"
        }
    }
}

private enum ReminderStatus: String, Codable { case active, completed, deleted }

private enum ReminderKind: String, Codable, CaseIterable, Identifiable {
    case reminder, action, event
    var id: String { rawValue }
    var label: String {
        switch self {
        case .reminder: return "Reminder"
        case .action: return "Action"
        case .event: return "Event"
        }
    }
}

private enum Effort: String, Codable, CaseIterable, Identifiable {
    case none, m5, m15, m30, h1, h2plus
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "—"
        case .m5: return "5m"
        case .m15: return "15m"
        case .m30: return "30m"
        case .h1: return "1h"
        case .h2plus: return "2h+"
        }
    }
}

private enum Energy: String, Codable, CaseIterable, Identifiable {
    case none, low, medium, high
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "—"
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        }
    }
}

private enum SuccessStep: String, Codable, CaseIterable, Identifiable {
    case none, context, circle, closeGap, chooseSuccess, codePattern, killSwitch, clearSign, compound
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .context: return "Context"
        case .circle: return "Circle"
        case .closeGap: return "Close the Gap"
        case .chooseSuccess: return "Choose Success"
        case .codePattern: return "Code the Pattern"
        case .killSwitch: return "Create Kill Switch"
        case .clearSign: return "Clear Sign of Success"
        case .compound: return "Compound"
        }
    }
}

private struct Subtask: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var done: Bool = false
}

private struct Reminder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: ReminderKind = .reminder
    var title: String = ""
    var notes: String = ""
    var url: String = ""
    var imageLocalPath: String? = nil
    var dueDate: Date? = nil
    var dueTime: Date? = nil
    var endTime: Date? = nil
    var urgent: Bool = false
    var repeatRule: RepeatRule = .none
    var earlyReminder: EarlyReminder = .none
    var listName: String = ""
    var flag: Bool = false
    var priority: Priority = .none
    var outcome: String = ""
    var effort: Effort = .none
    var energy: Energy = .none
    var context: SuccessStep = .none
    var deferDate: Date? = nil
    var waitingOn: String = ""
    var locationName: String = ""
    var whenMessagingPerson: String = ""
    var seededFromTemplateID: String? = nil
    var pinned: Bool = false
    var upNextOrder: Int? = nil
    var tags: [String] = []
    var subtasks: [Subtask] = []
    var status: ReminderStatus = .active
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var completedAt: Date? = nil
    var needsSync: Bool = false
}

private enum Brand {
    static let crimson = Color(red: 0xDC / 255, green: 0x14 / 255, blue: 0x3C / 255)
    static let card = Color(red: 0xF3 / 255, green: 0xEA / 255, blue: 0xD5 / 255)
    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

private enum LocalImageStore {
    private static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("reminder-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do { try data.write(to: dir.appendingPathComponent(name), options: .atomic); return name }
        catch { return nil }
    }

    static func load(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent(name).path)
    }

    static func data(_ name: String?) -> Data? {
        guard let name else { return nil }
        return try? Data(contentsOf: dir.appendingPathComponent(name))
    }
}

@MainActor
private final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isResolving = false
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<String?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentPlaceName() async -> String? {
        if continuation != nil { return nil }
        isResolving = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        return await withCheckedContinuation { cont in
            self.continuation = cont
            self.manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { Task { @MainActor in self.finish(nil) }; return }
        CLGeocoder().reverseGeocodeLocation(loc) { placemarks, _ in
            let p = placemarks?.first
            let name = [p?.name, p?.subLocality, p?.locality].compactMap { $0 }.first
            Task { @MainActor in self.finish(name) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }

    private func finish(_ value: String?) {
        isResolving = false
        continuation?.resume(returning: value)
        continuation = nil
    }
}

/// The entry form. One screen, three faces: the type selector at the top swaps the field set —
/// Reminder (timed nudge), Action (broad GTD-style to-do), or Event (time block). White page,
/// tan entry cells. Reused for create and edit.
struct EntryComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var location = LocationProvider()

    private let existingTags: [String]
    private var onSave: (Reminder) -> Void

    @State private var r: Reminder
    @State private var hasDate: Bool
    @State private var hasTime: Bool
    @State private var hasDefer: Bool
    @State private var hasEnd: Bool
    @State private var date: Date
    @State private var time: Date
    @State private var deferDate: Date
    @State private var endTime: Date
    @State private var tagDraft = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var committed = false
    @State private var cancelled = false
    @State private var showSaved = false

    private let listChoices = ["Learning", "Leverage", "Delegation", "Inspiration", "Risk", "Health"]

    init(initialKind: EntryComposerKind = .reminder, onSaved: (() -> Void)? = nil) {
        self.existingTags = []
        self.onSave = { reminder in
            Task { await EntryComposerPersistence.persist(reminder: reminder, onSaved: onSaved) }
        }
        var base = Reminder()
        switch initialKind {
        case .reminder:
            base.kind = .reminder
        case .action:
            base.kind = .action
        case .event:
            base.kind = .event
        }
        _r = State(initialValue: base)
        _hasDate = State(initialValue: base.dueDate != nil)
        _hasTime = State(initialValue: base.dueTime != nil)
        _hasDefer = State(initialValue: base.deferDate != nil)
        _hasEnd = State(initialValue: base.endTime != nil)
        _date = State(initialValue: base.dueDate ?? Date())
        _time = State(initialValue: base.dueTime ?? Date())
        _deferDate = State(initialValue: base.deferDate ?? Date())
        _endTime = State(initialValue: base.endTime ?? base.dueTime ?? Date())
        _pickedImage = State(initialValue: LocalImageStore.load(base.imageLocalPath))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $r.kind) {
                        ForEach(ReminderKind.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Brand.card)

                switch r.kind {
                case .reminder: reminderSections
                case .action:   actionSections
                case .event:    eventSections
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.white.ignoresSafeArea())
            .tint(Brand.crimson)
            .navigationTitle(r.title.trimmingCharacters(in: .whitespaces).isEmpty ? r.kind.label : r.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { cancelled = true; dismiss() } label: {
                        Image(systemName: "xmark.circle").font(.system(size: 22))
                    }
                    .tint(.black)
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { commit() } label: {
                        SaveDiskIcon(size: 24)
                    }
                    .accessibilityLabel("Save")
                }
            }
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .onChange(of: photoItem) { _, item in loadPhoto(item) }
            .onDisappear { autosaveIfNeeded() }
        }
        .overlay { if showSaved { savedToast } }
        .preferredColorScheme(.light)
    }

    private var savedToast: some View {
        ZStack {
            Color.black.opacity(0.12).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 46)).foregroundStyle(Brand.crimson)
                Text("Locked In").font(Brand.serif(30)).foregroundStyle(.black)
            }
            .padding(.horizontal, 40).padding(.vertical, 30)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.2), radius: 28, y: 12)
        }
        .transition(.opacity)
    }

    @ViewBuilder private var reminderSections: some View {
        Section {
            TextField("Title", text: $r.title)
            TextField("Notes", text: $r.notes, axis: .vertical).lineLimit(1...5)
            urlField("URL")
            imageRow
        } header: { sectionHeader("Details") }
        .listRowBackground(Brand.card)

        patternSection

        Section {
            dateGroup("Date", icon: "calendar", isOn: $hasDate, date: $date)
            timeGroup("Time", icon: "clock", isOn: $hasTime, time: $time)
            Toggle(isOn: $r.urgent) { Label("Urgent", systemImage: "alarm") }
            repeatGroup
            earlyReminderGroup
        } header: { sectionHeader("Date & Time") }
        .listRowBackground(Brand.card)

        Section {
            listGroup
            tagsEditor
            subtasksEditor("Subtasks", addLabel: "Add Subtask")
            Toggle(isOn: $r.flag) { Label("Flag", systemImage: "flag") }
            priorityGroup
        } header: { sectionHeader("Organization") }
        .listRowBackground(Brand.card)

        Section {
            locationRow
            messagingRow
        } header: { sectionHeader("Places & People") } footer: {
            Text("Saved with the reminder. Apple limits live Messages integration to its own Reminders app.")
                .foregroundStyle(.black.opacity(0.45))
        }
        .listRowBackground(Brand.card)
    }

    @ViewBuilder private var actionSections: some View {
        Section {
            TextField("What will you do?", text: $r.title)
            TextField("Outcome — what does done look like?", text: $r.outcome, axis: .vertical).lineLimit(1...3)
            subtasksEditor("Steps", addLabel: "Add Step")
        } header: { sectionHeader("Do") }
        .listRowBackground(Brand.card)

        patternSection

        Section {
            priorityGroup
            effortGroup
            energyGroup
        } header: { sectionHeader("Choose") }
        .listRowBackground(Brand.card)

        Section {
            dateGroup("Due", icon: "calendar", isOn: $hasDate, date: $date)
            dateGroup("Start / defer", icon: "calendar.badge.clock", isOn: $hasDefer, date: $deferDate)
            repeatGroup
            timeGroup("Nudge", icon: "bell", isOn: $hasTime, time: $time)
        } header: { sectionHeader("Schedule") }
        .listRowBackground(Brand.card)

        Section {
            listGroup
            Toggle(isOn: $r.flag) { Label("Flag", systemImage: "flag") }
            tagsEditor
        } header: { sectionHeader("Organize") }
        .listRowBackground(Brand.card)

        Section {
            TextField("Notes", text: $r.notes, axis: .vertical).lineLimit(1...5)
            urlField("Link")
            imageRow
        } header: { sectionHeader("Details") }
        .listRowBackground(Brand.card)

        Section {
            locationRow
            HStack {
                Image(systemName: "person").foregroundStyle(.secondary)
                TextField("Waiting on / delegate to", text: $r.waitingOn)
            }
        } header: { sectionHeader("Place / People") }
        .listRowBackground(Brand.card)
    }

    @ViewBuilder private var eventSections: some View {
        Section {
            TextField("Title", text: $r.title)
            TextField("Notes", text: $r.notes, axis: .vertical).lineLimit(1...4)
            locationRow
            tagsEditor
        } header: { sectionHeader("Event") }
        .listRowBackground(Brand.card)

        patternSection

        Section {
            dateGroup("Date", icon: "calendar", isOn: $hasDate, date: $date)
            timeGroup("Starts", icon: "clock", isOn: $hasTime, time: $time)
            timeGroup("Ends", icon: "clock.badge.checkmark", isOn: $hasEnd, time: $endTime)
            repeatGroup
        } header: { sectionHeader("When") }
        .listRowBackground(Brand.card)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.black.opacity(0.5))
    }

    private func urlField(_ placeholder: String) -> some View {
        TextField(placeholder, text: $r.url)
            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
    }

    private var imageRow: some View {
        HStack {
            Label("Image", systemImage: "photo")
            Spacer()
            if let img = pickedImage {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Text(pickedImage == nil ? "Add" : "Change").foregroundStyle(Brand.crimson)
            }
        }
    }

    private var locationRow: some View {
        HStack {
            Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)
            TextField("Location", text: $r.locationName)
            Button {
                Task { if let name = await location.currentPlaceName() { r.locationName = name } }
            } label: {
                if location.isResolving { ProgressView() } else { Image(systemName: "location") }
            }.foregroundStyle(Brand.crimson)
        }
    }

    private var messagingRow: some View {
        HStack {
            Image(systemName: "message").foregroundStyle(.secondary)
            TextField("When messaging a person", text: $r.whenMessagingPerson)
        }
    }

    private func dateGroup(_ title: String, icon: String, isOn: Binding<Bool>, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: isOn) { Label(title, systemImage: icon) }
            DatePicker(title, selection: date, displayedComponents: .date)
                .labelsHidden().disabled(!isOn.wrappedValue).opacity(isOn.wrappedValue ? 1 : 0.45)
        }
    }

    private func timeGroup(_ title: String, icon: String, isOn: Binding<Bool>, time: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: isOn) { Label(title, systemImage: icon) }
            DatePicker(title, selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden().disabled(!isOn.wrappedValue).opacity(isOn.wrappedValue ? 1 : 0.45)
        }
    }

    private func enumMenu<T: CaseIterable & Identifiable & Hashable>(
        _ title: String, icon: String, selection: Binding<T>, label: @escaping (T) -> String
    ) -> some View where T.AllCases: RandomAccessCollection {
        Picker(selection: selection) {
            ForEach(T.allCases) { Text(label($0)).tag($0) }
        } label: {
            Label(title, systemImage: icon)
        }
        .pickerStyle(.menu)
        .tint(Brand.crimson)
    }

    private var repeatGroup: some View {
        enumMenu("Repeat", icon: "repeat", selection: $r.repeatRule) { $0.label }
    }

    private var earlyReminderGroup: some View {
        enumMenu("Early Reminder", icon: "bell", selection: $r.earlyReminder) { $0.label }
    }

    private var priorityGroup: some View {
        enumMenu("Priority", icon: "exclamationmark.3", selection: $r.priority) { $0.label }
    }

    private var effortGroup: some View {
        enumMenu("Effort", icon: "timer", selection: $r.effort) { $0.label }
    }

    private var energyGroup: some View {
        enumMenu("Energy", icon: "bolt", selection: $r.energy) { $0.label }
    }

    private var patternSection: some View {
        Section {
            enumMenu("Pattern", icon: "list.number", selection: $r.context) { $0.label }
        } header: { sectionHeader("Pattern") }
        .listRowBackground(Brand.card)
    }

    private var listGroup: some View {
        Picker(selection: $r.listName) {
            Text("None").tag("")
            ForEach(listChoices, id: \.self) { Text($0).tag($0) }
        } label: {
            Label("Lift", systemImage: "sparkles")
        }
        .pickerStyle(.menu)
        .tint(Brand.crimson)
    }

    private var tagsEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tags", systemImage: "tag")
            HStack {
                TextField("Add a tag", text: $tagDraft)
                    .onSubmit(addTag)
                    .onChange(of: tagDraft) { _, value in if value.contains(",") { addTag() } }
                Button("Add", action: addTag)
                    .foregroundStyle(Brand.crimson)
                    .disabled(tagDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if !suggestedTags.isEmpty {
                Menu {
                    ForEach(suggestedTags, id: \.self) { tag in
                        Button(tag) { addExistingTag(tag) }
                    }
                } label: {
                    HStack {
                        Label("Add a recent tag", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                .tint(Brand.crimson)
            }
            if !r.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(r.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag).font(.system(size: 15, weight: .semibold))
                                Button { r.tags.removeAll { $0 == tag } } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }.foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 5).padding(.horizontal, 10)
                            .background(Color(white: 0.92)).clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private func subtasksEditor(_ title: String, addLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "checklist")
            ForEach($r.subtasks) { $sub in
                HStack {
                    Image(systemName: "circle").foregroundStyle(.secondary)
                    TextField("Step", text: $sub.title)
                    Button { r.subtasks.removeAll { $0.id == sub.id } } label: {
                        Image(systemName: "minus.circle.fill")
                    }.foregroundStyle(.secondary)
                }
            }
            Button { r.subtasks.append(Subtask()) } label: {
                Text(addLabel).foregroundStyle(Brand.crimson)
            }
        }
    }

    private func addTag() {
        let t = tagDraft
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        if !t.isEmpty && !r.tags.contains(t) { r.tags.append(t) }
        tagDraft = ""
    }

    private var suggestedTags: [String] { existingTags.filter { !r.tags.contains($0) } }

    private func addExistingTag(_ tag: String) {
        if !r.tags.contains(tag) { r.tags.append(tag) }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                pickedImage = img
            }
        }
    }

    private func commit() {
        committed = true
        persist()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.3)) { showSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { dismiss() }
    }

    private func autosaveIfNeeded() {
        guard !committed, !cancelled, hasContent else { return }
        persist()
    }

    private var hasContent: Bool {
        if !r.title.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        if !r.notes.isEmpty || !r.outcome.isEmpty || !r.url.isEmpty { return true }
        if !r.locationName.isEmpty || !r.waitingOn.isEmpty { return true }
        if !r.tags.isEmpty { return true }
        if r.subtasks.contains(where: { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }) { return true }
        if hasDate || hasTime || hasDefer || hasEnd || pickedImage != nil { return true }
        return false
    }

    private func persist() {
        addTag()
        if let pickedImage {
            r.imageLocalPath = LocalImageStore.save(pickedImage)
        }
        r.dueDate = hasDate ? date : nil
        r.dueTime = hasTime ? time : nil
        r.deferDate = (r.kind == .action && hasDefer) ? deferDate : nil
        r.endTime = (r.kind == .event && hasEnd) ? endTime : nil
        r.subtasks.removeAll { $0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        if r.title.trimmingCharacters(in: .whitespaces).isEmpty { r.title = "New \(r.kind.label)" }
        onSave(r)
    }
}

private enum EntryComposerPersistence {
    static let supabase = SupabaseService.shared

    static func persist(reminder: Reminder, onSaved: (() -> Void)?) async {
        do {
            try await saveToUnderstood(reminder)
            if let onSaved {
                await MainActor.run { onSaved() }
            }
        } catch {
            print("EntryComposer persistence failed: \(error.localizedDescription)")
        }
    }

    private static func saveToUnderstood(_ reminder: Reminder) async throws {
        let headline = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveHeadline = headline.isEmpty ? "New \(reminder.kind.label)" : headline
        let entryType = reminder.kind == .action ? "action" : "story"
        let nowISO = ISO8601DateFormatter().string(from: Date())
        let dueDateValue = reminder.dueDate.map { ISO8601DateFormatter().string(from: $0) }

        let metadata = EntryMetadata(
            timestamp: nowISO,
            dayOfWeek: nil,
            timeOfDay: nil,
            device: "mobile",
            patternStep: reminder.context == .none ? nil : reminder.context.label
        )

        let content = composeBody(from: reminder)

        let entry = try await supabase.createEntry(
            content: content,
            category: "Insight",
            entryType: entryType,
            metadata: metadata
        )

        let payload = EntryUpdatePayload(
            headline: effectiveHeadline,
            subheading: reminder.kind == .action ? reminder.outcome : "",
            content: content,
            category: "Insight",
            entryType: entryType,
            dueDate: dueDateValue,
            completedAt: nil,
            updatedAt: nowISO,
            shouldClearDueDate: true,
            shouldClearCompletedAt: true
        )
        try await supabase.updateEntry(id: entry.id, payload: payload)

        if let imageData = LocalImageStore.data(reminder.imageLocalPath),
           let image = UIImage(data: imageData),
           let userId = supabase.currentSession?.user.id.uuidString {
            let url = try await supabase.uploadEntryImage(
                image: image.uprightOrientation(),
                userId: userId,
                entryId: entry.id,
                index: 0
            )
            try await supabase.updateEntryImages(
                entryId: entry.id,
                images: [EntryImage(url: url, isPoster: true, order: 0)]
            )
        }
    }

    private static func composeBody(from reminder: Reminder) -> String {
        var sections: [String] = []

        sections.append("Kind: \(reminder.kind.label)")

        if !reminder.outcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("Outcome: \(reminder.outcome.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        if !reminder.subtasks.isEmpty {
            let steps = reminder.subtasks
                .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { "- \($0)" }
                .joined(separator: "\n")
            if !steps.isEmpty { sections.append("Steps:\n\(steps)") }
        }

        if let dueDate = reminder.dueDate {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .none
            sections.append("Due: \(fmt.string(from: dueDate))")
        }

        if let dueTime = reminder.dueTime {
            let fmt = DateFormatter()
            fmt.dateStyle = .none
            fmt.timeStyle = .short
            sections.append("Time: \(fmt.string(from: dueTime))")
        }

        if let deferDate = reminder.deferDate {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .none
            sections.append("Start / defer: \(fmt.string(from: deferDate))")
        }

        if let endTime = reminder.endTime {
            let fmt = DateFormatter()
            fmt.dateStyle = .none
            fmt.timeStyle = .short
            sections.append("Ends: \(fmt.string(from: endTime))")
        }

        sections.append("Repeat: \(reminder.repeatRule.label)")
        sections.append("Early reminder: \(reminder.earlyReminder.label)")
        sections.append("Urgent: \(reminder.urgent ? "Yes" : "No")")
        sections.append("Lift: \(reminder.listName.isEmpty ? "None" : reminder.listName)")
        sections.append("Priority: \(reminder.priority.label)")
        sections.append("Effort: \(reminder.effort.label)")
        sections.append("Energy: \(reminder.energy.label)")
        sections.append("Pattern: \(reminder.context.label)")
        sections.append("Flag: \(reminder.flag ? "Yes" : "No")")

        if !reminder.tags.isEmpty {
            sections.append("Tags: \(reminder.tags.joined(separator: ", "))")
        }

        if !reminder.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("Location: \(reminder.locationName.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        if !reminder.whenMessagingPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("When messaging: \(reminder.whenMessagingPerson.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        if !reminder.waitingOn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("Waiting on / delegate: \(reminder.waitingOn.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        if !reminder.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("Link: \(reminder.url.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        if !reminder.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("Notes:\n\(reminder.notes.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        return sections.joined(separator: "\n\n")
    }
}

// MARK: - Save (floppy disk) icon

/// A classic floppy-disk "save" glyph drawn as line art — iOS has no built-in floppy symbol.
/// Body with a beveled top-right corner, a shutter window up top, and a label at the bottom.
struct FloppyDisk: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let ox = rect.midX - s / 2, oy = rect.midY - s / 2
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x / 24 * s, y: oy + y / 24 * s) }
        var p = Path()
        // Body outline (rounded corners, beveled top-right)
        p.move(to: pt(3, 2))
        p.addLine(to: pt(16, 2))
        p.addLine(to: pt(22, 8))
        p.addLine(to: pt(22, 21))
        p.addQuadCurve(to: pt(21, 22), control: pt(22, 22))
        p.addLine(to: pt(3, 22))
        p.addQuadCurve(to: pt(2, 21), control: pt(2, 22))
        p.addLine(to: pt(2, 3))
        p.addQuadCurve(to: pt(3, 2), control: pt(2, 2))
        p.closeSubpath()
        // Shutter window (open at the top edge)
        p.move(to: pt(8, 2))
        p.addLine(to: pt(8, 9))
        p.addLine(to: pt(15, 9))
        p.addLine(to: pt(15, 2))
        // Label (rounded top, open at the bottom edge)
        p.move(to: pt(6, 22))
        p.addLine(to: pt(6, 15))
        p.addQuadCurve(to: pt(7, 14), control: pt(6, 14))
        p.addLine(to: pt(17, 14))
        p.addQuadCurve(to: pt(18, 15), control: pt(18, 14))
        p.addLine(to: pt(18, 22))
        return p
    }
}

struct SaveDiskIcon: View {
    var size: CGFloat = 24
    var body: some View {
        FloppyDisk()
            .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview {
    EntryComposerView()
}
