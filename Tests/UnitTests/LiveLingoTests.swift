import XCTest
@testable import LiveLingo

final class LiveLingoTests: XCTestCase {

    func testExample() throws {
        XCTAssertTrue(true)
    }

    func testPauseDetection() async throws {
        let detector = PauseDetector()
        let result = await detector.detectPause(silenceDuration: 1.0)
        XCTAssertTrue(result)
    }
}
