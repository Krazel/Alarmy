import XCTest
@testable import AlarmaNext

final class MusicTests: XCTestCase {
    let a = MusicTrack(id:"a",title:"A",artist:"Artist")
    let b = MusicTrack(id:"b",title:"B",artist:"Artist")
    func testShuffleAvoidsPreviousAndDeduplicates() {
        let choice = AlarmMusic(provider:.apple,mode:.shuffle,tracks:[a,a,b])
        XCTAssertEqual(choice.selected(excluding:"a",index:{_ in 0}),b)
        XCTAssertEqual(choice.selected(excluding:"b",index:{_ in 999}),a)
    }
    func testFixedAndSingleTrackDoNotDisappear() {
        XCTAssertEqual(AlarmMusic(provider:.apple,tracks:[a,b]).selected(excluding:"a"),a)
        XCTAssertEqual(AlarmMusic(provider:.apple,mode:.shuffle,tracks:[a]).selected(excluding:"a"),a)
        XCTAssertNil(AlarmMusic(provider:.apple,tracks:[]).selected(excluding:nil))
    }
    func testResolutionFreezesTrackAcrossSnooze() throws {
        let choice = try XCTUnwrap(AlarmMusic(provider:.spotify,mode:.shuffle,tracks:[a,b],playlistName:"Morning",deviceID:"device").resolved(excluding:"a"))
        var night = SleepSession(id:UUID(),start:Date(),checkpoint:Date(),wake:Date(),alarmID:UUID(),soundID:"aurora")
        night.alarmMusic = choice
        let snoozed = night.snoozed(until:Date().addingTimeInterval(300))
        XCTAssertEqual(snoozed.alarmMusic,choice)
        XCTAssertEqual(snoozed.alarmMusic?.tracks,[b])
    }
    func testOldArchiveDoesNotRequireMusicConfiguration() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(AppArchive())) as? [String:Any])
        object.removeValue(forKey:"lastMusicTrack")
        var plan = try XCTUnwrap(object["plan"] as? [String:Any])
        plan.removeValue(forKey:"music"); plan.removeValue(forKey:"toneMode"); object["plan"] = plan
        let restored = try JSONDecoder().decode(AppArchive.self,from:JSONSerialization.data(withJSONObject:object))
        XCTAssertNil(restored.plan.music); XCTAssertNil(restored.plan.toneMode)
        XCTAssertFalse(restored.plan.sounds.isEmpty)
    }
    func testFixedLocalToneIgnoresPrevious() {
        var plan = AlarmPlan(); plan.sounds = ["aurora","rain"]; plan.toneMode = .fixed
        XCTAssertEqual(plan.sound(excluding:"aurora"),"aurora")
    }
    @MainActor func testPKCEAndCallbackRejectSubstitution() throws {
        XCTAssertEqual(SpotifyLibrary.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),"E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        XCTAssertEqual(try SpotifyLibrary.callbackCode(URL(string:"alarma-spotify://callback?state=expected&code=one")!,state:"expected"),"one")
        for url in ["alarma-spotify://callback?state=wrong&code=one","alarma-spotify://other?state=expected&code=one","alarma-spotify://callback?state=expected&code=one&code=two","https://example.com?state=expected&code=one"] {
            XCTAssertThrowsError(try SpotifyLibrary.callbackCode(URL(string:url)!,state:"expected"))
        }
    }
}
