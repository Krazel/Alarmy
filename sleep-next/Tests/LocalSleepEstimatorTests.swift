import XCTest
@testable import AlarmaNext

final class LocalSleepEstimatorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970:1700000000)
    private func night(count: Int,features: BreathingFeatures?,gap: Int? = nil) -> SleepSession {
        let end = start.addingTimeInterval(Double(count)*30)
        var value = SleepSession(id:UUID(),start:start,checkpoint:end,end:end,wake:end,alarmID:UUID(),soundID:"aurora")
        value.acousticEpochs = (0..<count).compactMap { i in
            if i == gap {return nil}
            return AcousticEpoch(id:UUID(),start:start.addingTimeInterval(Double(i)*30),duration:30,activeSeconds:0,meanDBFS:-50,breathing:features)
        }
        return value
    }
    func testSilenceAndLegacyQuietNeverBecomeSleep() {
        XCTAssertTrue(LocalSleepEstimator.stages(night:night(count:120,features:nil)).isEmpty)
        let flat = RespiratoryEnvelope.features(Array(repeating:-50,count:300))
        XCTAssertFalse(flat!.usable)
        XCTAssertTrue(LocalSleepEstimator.stages(night:night(count:120,features:flat)).isEmpty)
    }
    func testEnvelopeFindsSyntheticBreathingAndRejectsFlatFan() {
        let signal = (0..<300).map {-50+6*sin(Double($0)*2*Double.pi/40)}
        let result = RespiratoryEnvelope.features(signal)!
        XCTAssertTrue(result.usable); XCTAssertGreaterThan(result.periodicity,0.95)
        XCTAssertLessThan(result.intervalVariation!,0.05)
        XCTAssertNil(RespiratoryEnvelope.features(Array(signal.prefix(100))))
    }
    func testStableAndVariableHypothesesRequireObservedContext() {
        let stable = BreathingFeatures(version:1,contrast:8,periodicity:0.9,intervalVariation:0.05,peaks:8)
        let variable = BreathingFeatures(version:1,contrast:8,periodicity:0.4,intervalVariation:0.3,peaks:8)
        XCTAssertTrue(LocalSleepEstimator.stages(night:night(count:9,features:stable)).isEmpty)
        let calm = LocalSleepEstimator.stages(night:night(count:50,features:stable))
        XCTAssertTrue(calm.contains {$0.key == "core"}); XCTAssertTrue(calm.contains {$0.key == "deep"}); XCTAssertFalse(calm.contains {$0.key == "rem"})
        let varied = LocalSleepEstimator.stages(night:night(count:30,features:variable))
        XCTAssertTrue(varied.contains {$0.key == "rem"}); XCTAssertFalse(varied.contains {$0.key == "deep"})
    }
    func testCaptureGapResetsInferenceAndIsNotFilled() {
        let features = BreathingFeatures(version:1,contrast:8,periodicity:0.9,intervalVariation:0.05,peaks:8)
        let result = LocalSleepEstimator.stages(night:night(count:30,features:features,gap:15))
        let gap = start.addingTimeInterval(15*30)
        XCTAssertFalse(result.contains {$0.start <= gap && $0.end > gap})
        XCTAssertFalse(result.contains {$0.key == "deep"})
    }
    func testSingleNoiseDoesNotBecomeAwakening() {
        var n = night(count:20,features:nil)
        n.acousticEpochs?[4] = AcousticEpoch(id:UUID(),start:start.addingTimeInterval(120),duration:30,activeSeconds:25,meanDBFS:-25)
        XCTAssertTrue(LocalSleepEstimator.stages(night:n).isEmpty)
    }
    func testAccumulatorPersistsFeaturesWithoutRetainingEnvelope() {
        var epochs:[AcousticEpoch] = []
        let accumulator = EpochAccumulator(start:start) {epochs.append($0)}
        for i in 0..<1500 {accumulator.add(duration:0.02,level:-50+6*sin(Double(i)*2*Double.pi/200),loud:false)}
        accumulator.flush()
        XCTAssertEqual(epochs.count,1); XCTAssertTrue(epochs[0].breathing?.usable == true)
        XCTAssertEqual(epochs[0].duration,30,accuracy:0.001)
    }
}
