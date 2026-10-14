import Foundation

enum ClockHand { case hour, minute }

/// Clock geometry uses clockwise turns, with zero at twelve o'clock.
enum ClockGeometry {
    static let hourLength = 0.245
    static let minuteLength = 0.315
    static func phase(at point: CGPoint, center: CGPoint) -> Double {
        let turns = atan2(point.x - center.x, center.y - point.y) / (2 * .pi)
        return turns < 0 ? turns + 1 : turns
    }

    static func point(phase: Double, center: CGPoint, length: Double) -> CGPoint {
        CGPoint(x: center.x + sin(phase * 2 * .pi) * length,
                y: center.y - cos(phase * 2 * .pi) * length)
    }

    static func nearestHand(at point: CGPoint, center: CGPoint, size: Double, hour: Int, minute: Int) -> ClockHand {
        let hourTip = self.point(phase: (Double(hour % 12) + Double(minute) / 60) / 12, center: center, length: size * hourLength)
        let minuteTip = self.point(phase: Double(minute) / 60, center: center, length: size * minuteLength)
        let hourDistance = segmentDistance(point, from: center, to: hourTip)
        let minuteDistance = segmentDistance(point, from: center, to: minuteTip)
        // When the hands overlap, their different grip radii disambiguate them.
        if abs(hourDistance - minuteDistance) < 3 {
            return hypot(point.x - center.x, point.y - center.y) < size * 0.28 ? .hour : .minute
        }
        return hourDistance < minuteDistance ? .hour : .minute
    }

    private static func segmentDistance(_ point: CGPoint, from start: CGPoint, to end: CGPoint) -> Double {
        let dx = end.x - start.x, dy = end.y - start.y
        let projection = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / (dx * dx + dy * dy)))
        return hypot(point.x - start.x - projection * dx, point.y - start.y - projection * dy)
    }
}

/// Tracks rotations across twelve without jumping or losing AM/PM.
struct ClockDrag {
    let hand: ClockHand
    private let startMinutes: Int
    private var previousPhase: Double
    private var turns = 0.0

    init(hand: ClockHand, phase: Double, hour: Int, minute: Int) {
        self.hand = hand
        self.previousPhase = phase
        self.startMinutes = hour * 60 + minute
    }

    mutating func update(phase: Double) -> (hour: Int, minute: Int) {
        var delta = phase - previousPhase
        if delta > 0.5 { delta -= 1 }
        if delta < -0.5 { delta += 1 }
        turns += delta
        previousPhase = phase
        let minutesPerTurn = hand == .minute ? 60.0 : 720.0
        let total = startMinutes + Int((turns * minutesPerTurn).rounded())
        let wrapped = (total % 1440 + 1440) % 1440
        return (wrapped / 60, wrapped % 60)
    }
}
