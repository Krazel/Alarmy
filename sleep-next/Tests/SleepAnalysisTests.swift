import XCTest
@testable import AlarmaNext

final class SleepAnalysisTests: XCTestCase {
    let origin = Date(timeIntervalSince1970:1_800_000_000)
    func night(_ duration: Double = 3600) -> SleepSession {
        SleepSession(id:UUID(),start:origin,checkpoint:origin.addingTimeInterval(duration),end:origin.addingTimeInterval(duration),wake:origin.addingTimeInterval(duration),alarmID:UUID(),soundID:"aurora")
    }
    func epoch(_ offset:Double,_ active:Double = 0) -> AcousticEpoch { AcousticEpoch(id:UUID(),start:origin.addingTimeInterval(offset),duration:30,activeSeconds:active,meanDBFS:-60) }
    func testAudioGapsAreNeverSleepOrQuietLatency() {
        var n = night(); n.acousticEpochs = (0..<20).map { epoch(Double($0*30)) } + (40..<60).map { epoch(Double($0*30)) }
        let m = NightMetrics(nights:[n])
        XCTAssertEqual(m.rest!,1200,accuracy:0.01); XCTAssertEqual(m.observed,1200,accuracy:0.01)
        XCTAssertEqual(m.quietLatency,0); XCTAssertEqual(m.coverage!,1.0/3,accuracy:0.001)
        n.acousticEpochs = (40..<60).map { epoch(Double($0*30)) }
        XCTAssertNil(NightMetrics(nights:[n]).quietLatency)
        XCTAssertNil(NightMetrics(nights:[n]).healthSeconds([]))
    }
    func testBedHealthAndSoundIntervalsDoNotDoubleCount() {
        var n = night(100)
        var clip = NightClip(id:UUID(),created:origin,filename:"test.wav",duration:100)
        clip.analysisDone = true; clip.suggestion = true
        clip.events = [SoundEvent(start:0,duration:30,kind:.snore,confidence:0.9),SoundEvent(start:20,duration:30,kind:.snore,confidence:0.9)]
        n.clips = [clip]; n.soundSummaries = [NightSoundSummary(clip:clip)]
        let m = NightMetrics(nights:[n,n])
        XCTAssertEqual(m.inBed,100); XCTAssertEqual(m.soundSeconds(.snore),50)
        let stages = [SleepStage(id:UUID(),start:origin.addingTimeInterval(-50),end:origin.addingTimeInterval(150),key:"deep")]
        XCTAssertEqual(m.healthSeconds(stages),100)
        n.clips = []
        XCTAssertEqual(NightMetrics(nights:[n]).soundSeconds(.snore),50)
    }
    func testManualLabelReplacesAcousticSummary() {
        var n = night(100)
        var c = NightClip(id:UUID(),created:origin,filename:"test.wav",duration:30)
        c.analysisDone = true; c.kind = .cough; c.suggestion = false
        c.events = [SoundEvent(start:0,duration:20,kind:.snore,confidence:0.8)]
        n.clips = [c]
        XCTAssertEqual(NightMetrics(nights:[n]).soundSeconds(.snore),0)
        XCTAssertEqual(NightMetrics(nights:[n]).soundSeconds(.cough),30)
    }
    func testClockRegularityCrossesMidnight() throws {
        var cal = Calendar(identifier:.gregorian); cal.timeZone = TimeZone(secondsFromGMT:0)!
        let a = cal.date(from:DateComponents(year:2026,month:10,day:12,hour:23,minute:55))!
        let b = a.addingTimeInterval(600)
        let stats = try XCTUnwrap(SleepMath.clockStats([a,b],calendar:cal))
        XCTAssertEqual(min(stats.mean,1440-stats.mean),0,accuracy:0.01)
        XCTAssertEqual(stats.spread,5,accuracy:0.01)
    }
    func testSmartWindowNeedsContinuousRecentQuietThenActivity() {
        var n = night(3600); n.mode = .smart; n.windowStart = origin.addingTimeInterval(600); n.latestWake = origin.addingTimeInterval(3600)
        n.acousticEpochs = (0..<20).map { epoch(Double($0*30)) } + [epoch(600,8)]
        XCTAssertTrue(SmartWakePolicy.shouldWake(n,now:origin.addingTimeInterval(630)))
        XCTAssertFalse(SmartWakePolicy.shouldWake(n,now:origin.addingTimeInterval(590)))
        XCTAssertFalse(SmartWakePolicy.shouldWake(n,now:origin.addingTimeInterval(3599)))
        n.acousticEpochs?.remove(at:5)
        XCTAssertFalse(SmartWakePolicy.shouldWake(n,now:origin.addingTimeInterval(630)))
        n.mode = .analysis
        XCTAssertFalse(SmartWakePolicy.shouldWake(n,now:origin.addingTimeInterval(630)))
    }
    func testEpochAccumulatorUsesEveryFrameAndFlushesTail() {
        var epochs: [AcousticEpoch] = []
        let accumulator = EpochAccumulator(start:origin) { epochs.append($0) }
        for i in 0..<1750 { accumulator.add(duration:0.02,level:i < 500 ? -20 : -60,loud:i < 500) }
        accumulator.flush()
        XCTAssertEqual(epochs.count,2); XCTAssertEqual(epochs[0].duration,30,accuracy:0.001)
        XCTAssertEqual(epochs[0].activeSeconds,10,accuracy:0.001); XCTAssertEqual(epochs[1].duration,5,accuracy:0.001)
        XCTAssertEqual(epochs[0].end,epochs[1].start)
        XCTAssertFalse(epochs[0].quiet); XCTAssertFalse(epochs[1].quiet)
    }
    func testLegacyPlanAndSessionRemainReadable() throws {
        var archive = AppArchive(); archive.sessions = [night()]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(archive)) as? [String:Any])
        var plan = json["plan"] as! [String:Any]; plan.removeValue(forKey:"mode"); plan.removeValue(forKey:"windowMinutes"); json["plan"] = plan
        let decoded = try JSONDecoder().decode(AppArchive.self,from:JSONSerialization.data(withJSONObject:json))
        XCTAssertEqual(decoded.plan.resolvedMode,.exact); XCTAssertTrue(decoded.sessions[0].hasAlarm)
        XCTAssertNil(decoded.sessions[0].acousticEpochs); XCTAssertEqual(decoded.preferences.keepDays,90)
    }
    func testNoAlarmSnoozeAndHealthMissingPrefix() {
        var n = night(); n.mode = .analysis; XCTAssertFalse(n.hasAlarm)
        n.mode = .smart; n.windowStart = origin; n.backupAlarmID = UUID()
        let snoozed = n.snoozed(until:origin.addingTimeInterval(5000))
        XCTAssertNil(snoozed.windowStart); XCTAssertNil(snoozed.backupAlarmID)
        let stages = [SleepStage(id:UUID(),start:origin.addingTimeInterval(600),end:origin.addingTimeInterval(1200),key:"core")]
        XCTAssertNil(NightMetrics(nights:[n]).healthLatency(stages))
    }
}
