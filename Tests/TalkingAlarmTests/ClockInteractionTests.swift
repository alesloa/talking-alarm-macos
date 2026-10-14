import XCTest
@testable import TalkingAlarm

final class ClockInteractionTests: XCTestCase {
    func testClockPositionsMatchPrintedNumbers() {
        let center = CGPoint(x: 100, y: 100)
        for number in 1...12 {
            let expectedPhase = Double(number % 12) / 12
            let point = ClockGeometry.point(phase: expectedPhase, center: center, length: 80)
            XCTAssertEqual(ClockGeometry.phase(at: point, center: center), expectedPhase, accuracy: 0.0001)
        }
    }

    func testGrabbingAHandDoesNotChangeTheTime() {
        for hand in [ClockHand.hour, .minute] {
            var drag = ClockDrag(hand: hand, phase: 0.27, hour: 19, minute: 37)
            let time = drag.update(phase: 0.27)
            XCTAssertEqual(time.hour, 19)
            XCTAssertEqual(time.minute, 37)
        }
    }

    func testMinuteDragCarriesAcrossMidnightAndBack() {
        var drag = ClockDrag(hand: .minute, phase: 59.0 / 60, hour: 23, minute: 59)
        var time = drag.update(phase: 1.0 / 60)
        XCTAssertEqual(time.hour, 0)
        XCTAssertEqual(time.minute, 1)
        time = drag.update(phase: 58.0 / 60)
        XCTAssertEqual(time.hour, 23)
        XCTAssertEqual(time.minute, 58)
    }

    func testHourDragTracksBothHandsAndAMPM() {
        var drag = ClockDrag(hand: .hour, phase: 11.5 / 12, hour: 11, minute: 30)
        let time = drag.update(phase: 0.5 / 12)
        XCTAssertEqual(time.hour, 12)
        XCTAssertEqual(time.minute, 30)
    }

    func testFullRotationsAccumulateInsteadOfResetting() {
        var drag = ClockDrag(hand: .minute, phase: 0, hour: 7, minute: 0)
        var time = (hour: 7, minute: 0)
        for step in 1...120 { time = drag.update(phase: Double(step % 60) / 60) }
        XCTAssertEqual(time.hour, 9)
        XCTAssertEqual(time.minute, 0)
    }

    func testHourAndMinuteGripsRemainSelectableWhenTheyOverlap() {
        let center = CGPoint(x: 100, y: 100)
        XCTAssertEqual(ClockGeometry.nearestHand(at: CGPoint(x: 100, y: 50), center: center, size: 200, hour: 0, minute: 0), .hour)
        XCTAssertEqual(ClockGeometry.nearestHand(at: CGPoint(x: 100, y: 30), center: center, size: 200, hour: 0, minute: 0), .minute)
        XCTAssertEqual(ClockGeometry.nearestHand(at: CGPoint(x: 150, y: 100), center: center, size: 200, hour: 3, minute: 0), .hour)
        XCTAssertEqual(ClockGeometry.nearestHand(at: CGPoint(x: 100, y: 30), center: center, size: 200, hour: 3, minute: 0), .minute)
    }
}
