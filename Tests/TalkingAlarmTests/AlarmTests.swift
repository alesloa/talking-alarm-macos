import XCTest
@testable import TalkingAlarm

final class AlarmTests: XCTestCase {
    func testWeekdayRepeatAndDuplicateSuppression() {
        var alarm = Alarm(hour: 7, minute: 30, message: "Wake Up Alarm", days: [2, 3, 4, 5, 6])
        XCTAssertTrue(alarm.isDue(hour: 7, minute: 30, weekday: 2, dateKey: "2026-10-19"))
        XCTAssertFalse(alarm.isDue(hour: 7, minute: 30, weekday: 1, dateKey: "2026-10-18"))
        XCTAssertFalse(alarm.isDue(hour: 7, minute: 31, weekday: 2, dateKey: "2026-10-19"))
        alarm.lastFired = "2026-10-19"
        XCTAssertFalse(alarm.isDue(hour: 7, minute: 30, weekday: 2, dateKey: "2026-10-19"))
        XCTAssertTrue(alarm.isDue(hour: 7, minute: 30, weekday: 3, dateKey: "2026-10-20"))
        alarm.enabled = false
        XCTAssertFalse(alarm.isDue(hour: 7, minute: 30, weekday: 3, dateKey: "2026-10-20"))
    }
    func testOneTimeAndPersistenceRoundTrip() throws {
        let alarm = Alarm(hour: 23, minute: 59, message: "User's exact message")
        XCTAssertTrue(alarm.isDue(hour: 23, minute: 59, weekday: 7, dateKey: "2026-10-17"))
        let loaded = try JSONDecoder().decode(Alarm.self, from: JSONEncoder().encode(alarm))
        XCTAssertEqual(loaded.id, alarm.id)
        XCTAssertEqual(loaded.message, alarm.message)
        XCTAssertEqual(loaded.hour, 23)
        XCTAssertEqual(loaded.minute, 59)
        XCTAssertEqual(loaded.days, [])
    }
}
