import SwiftUI

struct AlarmRow: View {
    let alarm: Alarm
    let editMode: Bool
    let revealDelete: Bool
    let edit: () -> Void
    let toggle: () -> Void
    let delete: () -> Void
    var beginSwipe: () -> Void = {}
    var setRevealed: (Bool) -> Void = { _ in }
    @State private var offset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: delete) {
                VStack(spacing: 8) {
                    Image(systemName: "trash").font(.system(size: 21))
                    Text("Delete").font(.system(size: 12, weight: .semibold))
                }.foregroundStyle(AlarmTheme.destructive)
                    .frame(width: RowSwipe.actionWidth).frame(maxHeight: .infinity)
                    .background(AlarmTheme.destructive.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: AlarmTheme.radius))
            }.buttonStyle(.plain).accessibilityLabel("Delete alarm")
                .offset(x: RowSwipe.revealWidth + offset)
                .accessibilityHidden(offset == 0)

            HStack(spacing: 12) {
                if editMode {
                    Button(action: delete) {
                        Image(systemName: "minus.circle.fill").font(.system(size: 20)).foregroundStyle(AlarmTheme.destructive)
                    }.buttonStyle(.plain).accessibilityLabel("Delete alarm")
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text(alarm.time, style: .time).font(.system(size: 38, weight: .light)).monospacedDigit()
                        .foregroundStyle(alarm.enabled ? AlarmTheme.text : AlarmTheme.secondary)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Text(alarm.message).font(.system(size: 13, weight: .medium)).foregroundStyle(AlarmTheme.text).lineLimit(2)
                    Text(alarm.repeatLabel).font(.system(size: 12)).foregroundStyle(AlarmTheme.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityAction(named: "Edit Alarm", edit)
                .accessibilityAction(named: "Delete Alarm", delete)

                Toggle("Enabled", isOn: Binding(get: { alarm.enabled }, set: { _ in toggle() }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .frame(width: 44).accessibilityLabel("Alarm enabled")
            }
            .frame(maxHeight: .infinity)
            .padding(18).background(AlarmTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AlarmTheme.radius))
            .offset(x: offset)
        }
        .background(AlarmTheme.background)
        .clipped()
        .overlay(RowInputSurface(offset: offset, enabled: alarm.enabled, swipeEnabled: !editMode,
            begin: beginSwipe, changed: { offset = $0 }, settle: settle,
            edit: edit, toggle: toggle, delete: delete))
        .contextMenu {
            Button("Edit Alarm", action: edit)
            Button(alarm.enabled ? "Disable Alarm" : "Enable Alarm", action: toggle)
            Button("Delete Alarm", role: .destructive, action: delete)
        }
        .onAppear { offset = revealDelete ? -RowSwipe.revealWidth : 0 }
        .onChange(of: revealDelete) { opened in snap(opened) }
        .onChange(of: editMode) { _ in snap(false) }
    }

    private func settle(_ opened: Bool) {
        snap(opened)
        setRevealed(opened)
    }

    private func snap(_ opened: Bool) {
        withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.28, dampingFraction: 0.88)) {
            offset = opened ? -RowSwipe.revealWidth : 0
        }
    }
}
