# Native interface redesign

## Design read and audit

This is a redesign of a personal native Mac utility inspired by the owner's iPhone Clock reference, not a website. Use SwiftUI, AppKit, San Francisco type, and SF Symbols. The owner's latest request replaces the original dark-only theme: follow macOS light/dark appearance and system color choices automatically.

The old UI had pure black surfaces, uneven 22-point gaps, a small read-only clock, and a cramped direct time field. Preserve the clock/menu bar entry, saved data format, Message and Repeat workflow, Terminal `say` speech, launch at login, and delete access. Restore hand manipulation instead of removing the clock.

DESIGN_VARIANCE: 4, MOTION_INTENSITY: 3, VISUAL_DENSITY: 5. This daily utility benefits from familiar alignment, immediate drag feedback, and compact grouped settings. The only animated state change is revealing Delete, with reduced-motion support.

## Visual system

Neutral light surfaces or charcoal dark surfaces, system label colors, the user's macOS accent color, and red only for destructive actions. AppKit dynamic colors resolve the shared palette using the containing window's appearance; no app window or SwiftUI view forces a theme. Filled controls choose black or white labels for contrast, and plain accent action text adjusts its brightness for legibility. Use 16-point group corners, 10-point control corners, and circles for the clock and add icon. Main list and editor are 390 by 700 points, with the extra height requested by the owner to give the editor more room. Scrollbars are hidden throughout the panel and message field as requested; scrolling remains available for longer content. The clock, digital readout, editable field, and AM/PM selector share one Date binding.

## Visible-value provenance

- The owner's requests and iPhone screenshot supply the alarm workflow, labels, editable time, repeat controls, hand dragging, voice test, and delete behavior. The latest request supplies automatic system appearance; macOS supplies the current appearance, accent, and label colors.
- Alarm hours, minutes, messages, repeat days, and enabled state come from owner input or the existing saved alarms JSON file.
- Clock digits and minute marks come from the implemented twelve-hour/sixty-minute clock scale; geometry derives both hands from the selected Date.
- Displayed dates, time formatting, weekday names, and AM/PM symbols come from Foundation's current calendar and locale.
- Launch state comes from SMAppService; speaking state comes from the launched `/usr/bin/say` process; System voice describes that command's default voice with no override.
- Empty-state copy, drag instructions, and action names describe working controls in AlarmViews.swift. Error text passes through actual system/process errors.
- Render artifacts use an isolated temporary alarms file. The fixture message "Wake Up Alarm", time 06:00, and weekday repeat come from the owner's README screenshot. The fixture never reads or writes the user's saved alarms or speaks.

## Pre-flight application

Audit contrast, accent/radius consistency, labels, one-line buttons, keyboard access, light and dark surfaces, empty and error states, repeat selection, direct entry, clock geometry, and native screen renders. The frontend skill's SEO, web frameworks, heroes, photography, responsive website layouts, marketing copy, and browser metrics do not apply to this native utility. No third-party UI system or image assets are needed.

AppearanceTests checks body, secondary, accent action, and destructive labels against all three surfaces at a minimum 4.5:1 contrast in both appearances, and exercises a light-dark-light switch on the same live panel. Native render artifacts cover both appearances. Tests cover twelve clock positions, no-jump grabbing, full rotations, midnight and AM/PM rollover, overlapping grips, and native AppKit mouse events updating both hands through the SwiftUI binding. AppKit's first-mouse handling restores grabbing in the menu bar panel without the ScrollView competing for the pointer.

## Alarm row interaction

The owner's clarified request supplies the sliding whole alarm card, separate trailing Delete panel, visible toggle, and right-click actions. RowInputSurface.swift handles native pointer and horizontal scroll-wheel input; AlarmRow.swift translates the entire rounded card, including the toggle, and uses a brief spring to settle open or closed. The Delete panel follows alongside the card with an eight-point gap, outside its container. Each alarm has its own rounded container. Vertical scrolling passes through to the list. Reveal distance is an internal layout measurement, never displayed as user data. There is no automatic deletion on a full swipe. The visible Delete label is the owner's requested action, already implemented by the alarm-removal callback.

The native context menu uses the existing Edit Alarm, Enable/Disable Alarm, and Delete Alarm actions. Its enable/disable label derives from the stored enabled state. Tests send AppKit drag events in both directions, verify intermediate movement and the switch moving with the card, click the switch while open, verify the Delete panel lies to the right of it, click Delete, exercise context-menu and edit-mode actions, and simulate horizontal scroll-wheel input. Render artifacts include closed and revealed rows.
