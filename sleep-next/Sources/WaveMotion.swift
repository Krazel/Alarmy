import Foundation

struct WaveEnvelope {
    var from = 0.0
    var target = 0.0
    var changedAt = 0.0
    func level(at time: Double) -> Double {
        let progress = min(1,max(0,(time-changedAt)/0.22))
        let eased = progress*progress*(3-2*progress)
        return from + (target-from)*eased
    }
    mutating func update(_ value: Double, at time: Double) {
        from = level(at:time); target = value.isFinite ? min(1,max(0,value)) : 0; changedAt = time
    }
}

enum WaveMotion {
    static func offset(x: Double, phase: Double, layer: Int, level: Double, height: Double) -> Double {
        let amplitude = level.isFinite ? min(1,max(0,level)) : 0
        let envelope = pow(sin(.pi*x),2)
        // Both harmonics share a bounded envelope; even peak input leaves stroke headroom.
        let wave = 0.78*sin(x * .pi * 3.4 - phase + Double(layer)*0.075)
                 + 0.14*sin(x * .pi * 6 + phase*0.65 + Double(layer)*0.09)
        let spread = Double(layer-6)*0.012
        return (wave+spread)*envelope*amplitude*max(0,height-8)*0.42
    }
}
