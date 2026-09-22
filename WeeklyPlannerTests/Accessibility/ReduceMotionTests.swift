import Foundation
import SwiftUI
import XCTest
@testable import WeeklyPlanner

final class ReduceMotionTests: XCTestCase {
    func testPageFlip_apiExists() {
        // SwiftUI's Animation isn't introspectable for duration/curve,
        // so we just verify the factories compile and return.
        _ = AnimationTokens.pageFlip(reduced: true)
        _ = AnimationTokens.pageFlip(reduced: false)
    }

    func testSheetSlide_apiExists() {
        _ = AnimationTokens.sheetSlide(reduced: true)
        _ = AnimationTokens.sheetSlide(reduced: false)
    }

    func testStickyPeel_apiExists() {
        _ = AnimationTokens.stickyPeel(reduced: true)
        _ = AnimationTokens.stickyPeel(reduced: false)
    }

    func testPickerDrop_apiExists() {
        _ = AnimationTokens.pickerDrop(reduced: true)
        _ = AnimationTokens.pickerDrop(reduced: false)
    }

    func testAIOverlaySlide_apiExists() {
        _ = AnimationTokens.aiOverlaySlide(reduced: true)
        _ = AnimationTokens.aiOverlaySlide(reduced: false)
    }
}
