import Foundation

struct TrainingMetrics: Equatable, Codable, Sendable {
    let effectiveDuration: TimeInterval
    let effectiveTextUnits: Int
    let unitsPerMinute: Double?
    let issueCount: Int

    static func calculate(
        transcript: String,
        startedAt: Date,
        endedAt: Date,
        pausedIntervals: [DateInterval],
        issueCount: Int
    ) -> TrainingMetrics {
        let session = DateInterval(start: startedAt, end: max(startedAt, endedAt))
        let pauses = mergedDuration(
            pausedIntervals.compactMap { $0.intersection(with: session) }
        )
        let duration = max(0, session.duration - pauses)
        let units = TextUnitCounter.count(in: transcript)
        let rate = duration >= 10 ? Double(units) / (duration / 60) : nil

        return TrainingMetrics(
            effectiveDuration: duration,
            effectiveTextUnits: units,
            unitsPerMinute: rate,
            issueCount: max(0, issueCount)
        )
    }

    private static func mergedDuration(_ intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return 0 }
        var total: TimeInterval = 0

        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                total += current.duration
                current = interval
            }
        }
        return total + current.duration
    }
}

enum TextUnitCounter {
    static func count(in text: String) -> Int {
        var count = 0
        var insideLatinOrNumberToken = false

        for character in text {
            if character.unicodeScalars.contains(where: isHan) {
                count += 1
                insideLatinOrNumberToken = false
            } else if character.unicodeScalars.allSatisfy(isLetterOrNumber) {
                if !insideLatinOrNumberToken {
                    count += 1
                    insideLatinOrNumberToken = true
                }
            } else {
                insideLatinOrNumberToken = false
            }
        }
        return count
    }

    private static func isLetterOrNumber(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet.alphanumerics.contains(scalar)
    }

    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xF900...0xFAFF,
             0x20000...0x2FA1F:
            true
        default:
            false
        }
    }
}
