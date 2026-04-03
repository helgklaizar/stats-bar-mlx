import XCTest
@testable import AntigravityBar

final class AntigravityBarTests: XCTestCase {
    func testModelQuotaInitialization() throws {
        // Проверка структур данных, используемых в AntigravityAPI
        let quota = ModelQuota(
            label: "Gemma 4",
            remainingPercentage: 80.5,
            isExhausted: false,
            timeUntilReset: "5m",
            secondsUntilReset: 300.0
        )
        
        XCTAssertEqual(quota.label, "Gemma 4")
        XCTAssertEqual(quota.remainingPercentage, 80.5)
        XCTAssertFalse(quota.isExhausted)
        XCTAssertEqual(quota.timeUntilReset, "5m")
    }
}
