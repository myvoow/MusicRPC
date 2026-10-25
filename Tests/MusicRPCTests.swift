import Foundation
import Testing
@testable import MusicRPC

@Test func frameHasLittleEndianHeader() {
    let frame = DiscordIPC.frame(op: 1, Data("{}".utf8))
    #expect(Array(frame) == [1, 0, 0, 0, 2, 0, 0, 0, UInt8(ascii: "{"), UInt8(ascii: "}")])
}

@Test func parsesAdapterLineIntoActivity() throws {
    let line = #"{"type":"data","diff":false,"payload":{"title":"Song","artist":"Artist","album":"LP","bundleIdentifier":"com.apple.Music","playing":true,"durationMicros":120000000,"elapsedTimeMicros":30000000,"timestampEpochMicros":1000000000000}}"#
    let np = try #require(NowPlayingMonitor.parse(Data(line.utf8)))

    let activity = Activity(np, artwork: "https://x/cover.jpg")
    #expect(activity.details == "Song")
    #expect(activity.state == "Artist")
    #expect(activity.assets == .init(large_image: "https://x/cover.jpg", large_text: "LP"))
    #expect(activity.timestamps == .init(start: 999_970_000, end: 1_000_090_000))
}

@Test func onlyPlayingAppleMusicCounts() {
    #expect(NowPlayingMonitor.parse(Data(#"{"type":"data","diff":false,"payload":{}}"#.utf8)) == nil)
    #expect(NowPlayingMonitor.parse(Data(#"{"payload":{"title":"T","bundleIdentifier":"com.apple.Music","playing":false}}"#.utf8)) == nil)
    #expect(NowPlayingMonitor.parse(Data(#"{"payload":{"title":"T","bundleIdentifier":"com.apple.Safari","playing":true}}"#.utf8)) == nil)
}
