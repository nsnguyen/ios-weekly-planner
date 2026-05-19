import XCTest
@testable import WeeklyPlanner

final class SystemPromptTests: XCTestCase {
    func testPromptIncludesPersona() {
        let prompt = SystemPrompt.default
        XCTAssertTrue(prompt.contains("You are The Planner"))
    }

    func testPromptIncludesOnDevicePrivacyReminder() {
        XCTAssertTrue(SystemPrompt.default.contains("on-device"))
    }

    func testPromptListsAllToolsByName() {
        let prompt = SystemPrompt.default
        for name in ["findEvents", "findFreeSlots", "scanInbox", "summarizeWeek", "lastInteraction"] {
            XCTAssertTrue(prompt.contains(name), "Prompt missing tool '\(name)'")
        }
    }

    func testPromptRefusalLineMatchesSpec() {
        XCTAssertTrue(SystemPrompt.default.contains("scoped to your planner"))
    }
}
