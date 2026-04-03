import XCTest
@testable import AntigravityBar

// MARK: - Mock Environment

final class MockSystemEnvironment: @unchecked Sendable, SystemEnvironment {
    var mockedContents: [URL: [URL]] = [:]
    var mockedAttributes: [String: [FileAttributeKey: Any]] = [:]
    var removedURLs: [URL] = []
    
    // Using simple array matching for enumeration
    var mockedEnumeratorValues: [URL: [URL]] = [:]

    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        return mockedContents[url] ?? []
    }
    
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
        return mockedAttributes[path] ?? [:]
    }
    
    func removeItem(at url: URL) throws {
        removedURLs.append(url)
    }
    
    func enumerator(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) -> NSEnumerator? {
        let urls = mockedEnumeratorValues[url] ?? []
        return urls.isEmpty ? nil : (urls as NSArray).objectEnumerator()
    }
    
    func readData(contentsOf url: URL) throws -> Data {
        return Data() // Ignored for these tests
    }
}

// MARK: - Tests

final class AntigravityBarTests: XCTestCase {
    
    var mockEnv: MockSystemEnvironment!
    var api: AntigravityAPI!
    
    override func setUp() async throws {
        mockEnv = MockSystemEnvironment()
        api = AntigravityAPI(env: mockEnv)
    }
    
    func testTimeFormatting() {
        XCTAssertEqual(api.formatTime(0), "Ready")
        XCTAssertEqual(api.formatTime(30000), "1m") // 0.5m rounds to 1
        XCTAssertEqual(api.formatTime(60000), "1m")
        XCTAssertEqual(api.formatTime(120000), "2m")
        XCTAssertEqual(api.formatTime(3600000), "1h 0m")
        XCTAssertEqual(api.formatTime(5400000), "1h 30m") // 90 mins
        XCTAssertEqual(api.formatTime(90000000), "1d 1h") // 25 hours
    }

    func testParseQuota() {
        let jsonStr = """
        {
            "userStatus": {
                "cascadeModelConfigData": {
                    "clientModelConfigs": [
                        {
                            "label": "Gemma 4",
                            "quotaInfo": {
                                "remainingFraction": 0.75,
                                "resetTime": "2030-01-01T00:00:00Z"
                            }
                        },
                        {
                            "label": "Flash 2.5",
                            "quotaInfo": {
                                "remainingFraction": 0.0,
                                "resetTime": "2030-01-01T00:00:00Z"
                            }
                        }
                    ]
                }
            }
        }
        """
        guard let data = jsonStr.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(CascadeUserStatus.self, from: data) else {
            XCTFail("Failed to setup mock JSON")
            return
        }
        
        let quotaData = api.parseQuota(parsed)
        XCTAssertNotNil(quotaData)
        XCTAssertEqual(quotaData?.models.count, 2)
        
        let gemma = quotaData?.models.first { $0.label == "Gemma 4" }
        XCTAssertEqual(gemma?.remainingPercentage, 75.0)
        XCTAssertFalse(gemma?.isExhausted ?? true)
        
        let flash = quotaData?.models.first { $0.label == "Flash 2.5" }
        XCTAssertEqual(flash?.remainingPercentage, 0.0)
        XCTAssertTrue(flash?.isExhausted ?? false)
    }
    
    func testClearBrainAndCodeTrackerDeletesCorrectFiles() {
        let brainDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".gemini/antigravity/brain")
        
        let file1 = brainDir.appendingPathComponent("123.md")
        let fileDS = brainDir.appendingPathComponent(".DS_Store")
        
        mockEnv.mockedContents[brainDir] = [file1, fileDS]
        
        api.clearBrain()
        
        // Should delete file1, but NOT .DS_Store
        XCTAssertEqual(mockEnv.removedURLs.count, 1)
        XCTAssertEqual(mockEnv.removedURLs.first, file1)
    }
}
