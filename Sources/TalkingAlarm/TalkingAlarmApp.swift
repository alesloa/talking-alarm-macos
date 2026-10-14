import SwiftUI
import AppKit
import ServiceManagement

struct Alarm: Identifiable, Codable {
    var id = UUID()
    var hour: Int
    var minute: Int
    var message: String
    var days: Set<Int> = []
    var enabled = true
    var lastFired: String?
    func isDue(hour: Int, minute: Int, weekday: Int, dateKey: String) -> Bool {
        enabled && self.hour == hour && self.minute == minute && lastFired != dateKey && (days.isEmpty || days.contains(weekday))
    }
    var time: Date { Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date() }
    var repeatLabel: String {
        if days.isEmpty { return "Once" }
        if days.count == 7 { return "Every day" }
        return days.sorted().map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
    }
}

@MainActor final class AlarmStore: ObservableObject {
    @Published var alarms: [Alarm] = []
    @Published var error: String?
    @Published private(set) var isSpeaking = false
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    private var speechQueue: [String] = []
    private var speechProcess: Process?
    private var timer: Timer?
    private var alertWindow: NSWindow?
    private let file: URL

    init(file: URL? = nil, startsScheduling: Bool = true) {
        self.file = file ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TalkingAlarm/alarms.json")
        do {
            if FileManager.default.fileExists(atPath: self.file.path) { alarms = try JSONDecoder().decode([Alarm].self, from: Data(contentsOf: self.file)) }
        } catch { self.error = error.localizedDescription }
        guard startsScheduling else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.check() } }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.check() } }
        if Bundle.main.bundleURL.path.hasPrefix("/Applications/"), !UserDefaults.standard.bool(forKey: "loginSetupAttempted") {
            UserDefaults.standard.set(true, forKey: "loginSetupAttempted")
            setLogin(true)
        }
    }

    func save(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) { alarms[index] = alarm } else { alarms.append(alarm) }
        alarms.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        persist()
    }
    func remove(_ id: UUID) { alarms.removeAll { $0.id == id }; persist() }
    func toggle(_ id: UUID) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].enabled.toggle(); persist()
    }
    func persist() {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(alarms).write(to: file, options: .atomic)
        } catch { self.error = error.localizedDescription }
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { self.error = error.localizedDescription }
        loginEnabled = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }
    func speak(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        speechQueue.append(text)
        playNextMessage()
    }
    private func playNextMessage() {
        guard speechProcess == nil else { return }
        guard !speechQueue.isEmpty else { isSpeaking = false; return }
        let text = speechQueue.removeFirst()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        // Pass the message as one literal argument, never through a shell.
        // No voice override: use the same default as Terminal's `say`.
        process.arguments = ["--", text]
        let errors = Pipe()
        process.standardError = errors
        process.terminationHandler = { [weak self] completed in
            let data = errors.fileHandleForReading.readDataToEndOfFile()
            let detail = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { @MainActor in
                guard let self else { return }
                if completed.terminationStatus != 0, let detail, !detail.isEmpty { self.error = detail }
                self.speechProcess = nil
                self.playNextMessage()
            }
        }
        speechProcess = process
        do { try process.run(); isSpeaking = true }
        catch {
            speechProcess = nil
            self.error = error.localizedDescription
            playNextMessage()
        }
    }
    func check(now: Date = Date()) {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: now)
        let key = "\(parts.year!)-\(parts.month!)-\(parts.day!)"
        for index in alarms.indices {
            let alarm = alarms[index]
            guard alarm.isDue(hour: parts.hour!, minute: parts.minute!, weekday: parts.weekday!, dateKey: key) else { continue }
            alarms[index].lastFired = key
            if alarm.days.isEmpty { alarms[index].enabled = false }
            persist()
            speak(alarm.message)
            showAlert(alarm)
        }
    }
    func showAlert(_ alarm: Alarm) {
        alertWindow?.close()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 280), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Talking Alarm"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: AlarmAlert(alarm: alarm, dismiss: { window.close() }))
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        alertWindow = window
    }
}

@main struct TalkingAlarmApp: App {
    @StateObject private var store: AlarmStore
    init() {
        let instance = AlarmStore()
        _store = StateObject(wrappedValue: instance)
    }
    var body: some Scene {
        MenuBarExtra("Talking Alarm", systemImage: "clock") { AlarmMenu(store: store) }.menuBarExtraStyle(.window)
    }
}
