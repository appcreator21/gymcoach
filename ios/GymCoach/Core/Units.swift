import Foundation

/// Data is always stored in kg; the profile only changes presentation.
struct Units {
    var isPounds: Bool
    static let kgPerLb = 0.45359237

    var label: String { isPounds ? "lb" : "kg" }
    var step: Double { isPounds ? 5 : 2.5 }

    func display(_ kg: Double) -> Double { isPounds ? kg / Units.kgPerLb : kg }
    func toKg(_ value: Double) -> Double { isPounds ? value * Units.kgPerLb : value }

    func format(_ kg: Double, withUnit: Bool = true) -> String {
        let v = display(kg)
        let text = v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
        return withUnit ? "\(text) \(label)" : text
    }

    func formatVolume(_ kg: Double) -> String {
        let v = display(kg)
        if v >= 1000 { return String(format: "%.1fk %@", v / 1000, label) }
        return String(format: "%.0f %@", v, label)
    }
}

enum PlateMath {
    static func perSide(target: Double, bar: Double, plates: [Double]) -> (plates: [(Double, Int)], remainder: Double) {
        var remaining = max(0, (target - bar) / 2)
        var result: [(Double, Int)] = []
        for plate in plates.sorted(by: >) {
            let count = Int((remaining / plate + 1e-9).rounded(.down))
            if count > 0 {
                result.append((plate, count))
                remaining -= Double(count) * plate
            }
        }
        return (result, remaining * 2)
    }
}
