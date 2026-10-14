import SwiftUI
import AppKit

struct AlarmButtonStyle: ButtonStyle {
    var filled = false
    var destructive = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 14).frame(minHeight: 34)
            .foregroundStyle(filled ? AlarmTheme.accentLabel : destructive ? AlarmTheme.destructive : AlarmTheme.accentText)
            .background(filled ? AlarmTheme.accent : AlarmTheme.field)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
    }
}

struct AlarmMenu: View {
    @ObservedObject var store: AlarmStore
    @State private var editing: Alarm?
    @State private var adding = false
    @State private var editMode = false
    @State private var revealedDelete: UUID?

    var body: some View {
        VStack(spacing: 0) {
            if adding || editing != nil {
                AlarmEditor(store: store, alarm: editing, close: { adding = false; editing = nil })
                    .id(editing?.id)
            } else {
                list
            }
        }
        .frame(width: AlarmTheme.width, height: AlarmTheme.height)
        .background(AlarmTheme.background)
        .foregroundStyle(AlarmTheme.text)
        .tint(AlarmTheme.accent)
        .background(PanelDismissObserver(onDismiss: resetMenu).frame(width: 0, height: 0))
        .onDisappear(perform: resetMenu)
        .alert("Talking Alarm", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }

    private func resetMenu() {
        adding = false
        editing = nil
        editMode = false
        revealedDelete = nil
    }

    private var list: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Talking Alarm", systemImage: "clock").font(.system(size: 13, weight: .medium)).foregroundStyle(AlarmTheme.secondary)
                Spacer()
                Button(editMode ? "Done" : "Edit") { editMode.toggle(); revealedDelete = nil }
                    .buttonStyle(.plain).foregroundStyle(AlarmTheme.accentText)
                    .disabled(store.alarms.isEmpty)
            }.padding(.horizontal, 22).padding(.top, 22)

            HStack(alignment: .center) {
                Text("Alarms").font(.system(size: 32, weight: .bold)).tracking(-0.6)
                Spacer()
                Button { adding = true } label: {
                    Image(systemName: "plus").font(.system(size: 19, weight: .medium))
                        .frame(width: 38, height: 38)
                        .background(AlarmTheme.accent).foregroundStyle(AlarmTheme.accentLabel)
                        .clipShape(Circle())
                }.buttonStyle(.plain).accessibilityLabel("Add alarm")
            }.padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 22)

            if store.alarms.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "alarm").font(.system(size: 38, weight: .light)).foregroundStyle(AlarmTheme.accentText)
                    Text("No alarms yet").font(.system(size: 19, weight: .semibold))
                    Text("Use + to set a time and a spoken message.")
                        .font(.system(size: 13)).foregroundStyle(AlarmTheme.secondary)
                        .multilineTextAlignment(.center).frame(maxWidth: 245)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(store.alarms) { alarm in
                            AlarmRow(alarm: alarm, editMode: editMode, revealDelete: revealedDelete == alarm.id,
                                edit: { editing = alarm }, toggle: { store.toggle(alarm.id) },
                                delete: { store.remove(alarm.id); revealedDelete = nil },
                                beginSwipe: { if revealedDelete != alarm.id { revealedDelete = nil } },
                                setRevealed: { revealedDelete = $0 ? alarm.id : nil })
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 16)
                }
            }

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "power").foregroundStyle(AlarmTheme.secondary)
                    Text("Launch at login").font(.system(size: 13))
                    Spacer()
                    Toggle("Launch at login", isOn: Binding(get: { store.loginEnabled }, set: { store.setLogin($0) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }.padding(14).background(AlarmTheme.surface).clipShape(RoundedRectangle(cornerRadius: AlarmTheme.radius))
                HStack {
                    Label("System voice", systemImage: "speaker.wave.2").foregroundStyle(AlarmTheme.secondary)
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.plain).foregroundStyle(AlarmTheme.secondary)
                }.font(.system(size: 12))
            }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 20)
        }
    }
}

struct AlarmEditor: View {
    @ObservedObject var store: AlarmStore
    let alarm: Alarm?
    let close: () -> Void
    @State private var time: Date
    @State private var message: String
    @State private var days: Set<Int>
    @FocusState private var messageFocused: Bool

    init(store: AlarmStore, alarm: Alarm?, close: @escaping () -> Void) {
        self.store = store; self.alarm = alarm; self.close = close
        _time = State(initialValue: alarm?.time ?? Date())
        _message = State(initialValue: alarm?.message ?? "")
        _days = State(initialValue: alarm?.days ?? [])
    }

    private var hasMessage: Bool { !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isPM: Bool { Calendar.current.component(.hour, from: time) >= 12 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: close).buttonStyle(.plain).foregroundStyle(AlarmTheme.accentText).keyboardShortcut(.cancelAction)
                Spacer()
                Text(alarm == nil ? "Add Alarm" : "Edit Alarm").font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Save", action: save).buttonStyle(AlarmButtonStyle(filled: true)).disabled(!hasMessage)
            }.padding(.horizontal, 22).padding(.vertical, 18)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    timeControls
                    messageControls
                    repeatControls
                    if let alarm {
                        Button("Delete Alarm") { store.remove(alarm.id); close() }
                            .buttonStyle(AlarmButtonStyle(destructive: true)).frame(maxWidth: .infinity)
                    }
                }.padding(.horizontal, 18).padding(.top, 6).padding(.bottom, 20)
            }
        }
        .foregroundStyle(AlarmTheme.text).tint(AlarmTheme.accent).background(AlarmTheme.background)
    }

    private var timeControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                AlarmClockFace(time: $time).frame(width: 178, height: 178)
                VStack(alignment: .leading, spacing: 13) {
                    Text("Alarm time").font(.system(size: 12, weight: .medium)).foregroundStyle(AlarmTheme.secondary)
                    Text(time.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits)))
                        .font(.system(size: 35, weight: .light)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
                    HStack(spacing: 2) {
                        periodButton(DateFormatter().amSymbol, pm: false)
                        periodButton(DateFormatter().pmSymbol, pm: true)
                    }.padding(3).background(AlarmTheme.field).clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Set time").font(.system(size: 12)).foregroundStyle(AlarmTheme.secondary)
                        DatePicker("Set time", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.field).labelsHidden().controlSize(.regular)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Drag either hand, or type a time.").font(.system(size: 12)).foregroundStyle(AlarmTheme.secondary)
        }.padding(.vertical, 6)
    }

    private func periodButton(_ title: String, pm: Bool) -> some View {
        Button {
            let hour = Calendar.current.component(.hour, from: time)
            time = Calendar.current.date(bySettingHour: hour % 12 + (pm ? 12 : 0), minute: Calendar.current.component(.minute, from: time), second: 0, of: time) ?? time
        } label: {
            Text(title).font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 28)
                .background(isPM == pm ? AlarmTheme.accent : .clear)
                .foregroundStyle(isPM == pm ? AlarmTheme.accentLabel : AlarmTheme.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).accessibilityAddTraits(isPM == pm ? .isSelected : [])
    }

    private var messageControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Message").font(.system(size: 14, weight: .semibold))
                Spacer()
                Button { store.speak(message) } label: {
                    Label("Test voice", systemImage: "speaker.wave.2.fill")
                }.buttonStyle(AlarmButtonStyle()).disabled(!hasMessage || store.isSpeaking)
            }
            TextEditor(text: $message).font(.system(size: 14)).scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .padding(10).frame(height: 94).background(AlarmTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AlarmTheme.radius))
                .overlay(RoundedRectangle(cornerRadius: AlarmTheme.radius).stroke(messageFocused ? AlarmTheme.accent : .clear, lineWidth: 1))
                .focused($messageFocused).accessibilityLabel("Spoken message")
        }
    }

    private var repeatControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Repeat").font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(days.count == 7 ? "Clear" : "Every day") { days = days.count == 7 ? [] : Set(1...7) }
                    .font(.system(size: 12, weight: .medium)).buttonStyle(.plain).foregroundStyle(AlarmTheme.accentText)
            }
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 5) {
                    ForEach(1...7, id: \.self) { day in
                        Button { if days.contains(day) { days.remove(day) } else { days.insert(day) } } label: {
                            Text(Calendar.current.veryShortWeekdaySymbols[day - 1]).font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity).frame(height: 36)
                                .background(days.contains(day) ? AlarmTheme.accent : AlarmTheme.field)
                                .foregroundStyle(days.contains(day) ? AlarmTheme.accentLabel : AlarmTheme.text)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain).accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                            .accessibilityValue(days.contains(day) ? "Selected" : "Not selected")
                    }
                }
                Text(days.isEmpty ? "Once, at the next selected time" : days.count == 7 ? "Every day" : days.sorted().map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", "))
                    .font(.system(size: 12)).foregroundStyle(AlarmTheme.secondary)
            }.padding(13).background(AlarmTheme.surface).clipShape(RoundedRectangle(cornerRadius: AlarmTheme.radius))
        }
    }

    private func save() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        var value = alarm ?? Alarm(hour: parts.hour!, minute: parts.minute!, message: message)
        value.hour = parts.hour!; value.minute = parts.minute!; value.message = message; value.days = days
        value.enabled = true
        store.save(value); close()
    }
}

struct AlarmClockFace: View {
    @Binding var time: Date
    @State private var selectedHand: ClockHand?

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
            let hour = parts.hour ?? 0, minute = parts.minute ?? 0
            ZStack {
                Circle().fill(AlarmTheme.surface).overlay(Circle().stroke(AlarmTheme.border, lineWidth: 1.5))
                ForEach(0..<60, id: \.self) { tick in
                    let start = ClockGeometry.point(phase: Double(tick) / 60, center: center, length: size * (tick % 5 == 0 ? 0.435 : 0.455))
                    let end = ClockGeometry.point(phase: Double(tick) / 60, center: center, length: size * 0.473)
                    Path { path in path.move(to: start); path.addLine(to: end) }
                        .stroke(tick % 5 == 0 ? AlarmTheme.majorTick : AlarmTheme.minorTick, lineWidth: tick % 5 == 0 ? 1.4 : 0.7)
                }
                ForEach(1...12, id: \.self) { number in
                    Text("\(number)").font(.system(size: 13, weight: .medium)).foregroundStyle(AlarmTheme.text)
                        .position(ClockGeometry.point(phase: Double(number) / 12, center: center, length: size * 0.385))
                }
                hand(.hour, phase: (Double(hour % 12) + Double(minute) / 60) / 12, center: center, length: size * ClockGeometry.hourLength)
                hand(.minute, phase: Double(minute) / 60, center: center, length: size * ClockGeometry.minuteLength)
                Circle().fill(AlarmTheme.accentText).frame(width: 10, height: 10).position(center)
            }
            .contentShape(Circle())
            .overlay(ClockInputSurface(time: $time, selectedHand: $selectedHand))
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("Alarm clock")
        .accessibilityValue(time.formatted(date: .omitted, time: .shortened))
        .accessibilityHint("Drag the short hand to change hours or the long hand to change minutes. You can also use Set time.")
        .accessibilityAdjustableAction { direction in
            let delta = direction == .increment ? 1 : -1
            time = Calendar.current.date(byAdding: .minute, value: delta, to: time) ?? time
        }
    }

    private func hand(_ hand: ClockHand, phase: Double, center: CGPoint, length: Double) -> some View {
        let tip = ClockGeometry.point(phase: phase, center: center, length: length)
        let color = hand == .minute ? AlarmTheme.accentText : AlarmTheme.text
        return ZStack {
            Path { path in path.move(to: center); path.addLine(to: tip) }
                .stroke(color, style: StrokeStyle(lineWidth: hand == .hour ? 5 : 3, lineCap: .round))
            Circle().fill(color).frame(width: selectedHand == hand ? 12 : 8, height: selectedHand == hand ? 12 : 8)
                .overlay(Circle().stroke(AlarmTheme.surface, lineWidth: 1.5)).position(tip)
        }
    }
}

struct AlarmAlert: View {
    let alarm: Alarm
    let dismiss: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Label("Alarm", systemImage: "alarm").font(.system(size: 14, weight: .medium)).foregroundStyle(AlarmTheme.accentText)
            Text(alarm.time, style: .time).font(.system(size: 42, weight: .light)).monospacedDigit()
            ScrollView(showsIndicators: false) { Text(alarm.message).font(.system(size: 18)).multilineTextAlignment(.center).textSelection(.enabled).frame(maxWidth: .infinity) }
            Button("Dismiss", action: dismiss).buttonStyle(AlarmButtonStyle(filled: true))
        }.padding(28).frame(width: 440, height: 280).background(AlarmTheme.background)
            .foregroundStyle(AlarmTheme.text)
    }
}
