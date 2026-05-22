import Foundation
import SwiftUI
import XCTest
@testable import WeeklyPlanner

final class ReduceMotionTests: XCTestCase {
    func testPageFlip_apiExists() {
        // SwiftUI's Animation isn't introspectable for duration/curve,
        // so we just verify the factories compile and return.
        let _ = AnimationTokens.pageFlip(reduced: true)
        let _ = AnimationTokens.pageFlip(reduced: false)
    }

    func testSheetSlide_apiExists() {
        let _ = AnimationTokens.sheetSlide(reduced: true)
        let _ = AnimationTokens.sheetSlide(reduced: false)
    }

    func testStickyPeel_apiExists() {
        let _ = AnimationTokens.stickyPeel(reduced: true)
        let _ = AnimationTokens.stickyPeel(reduced: false)
    }

    func testPickerDrop_apiExists() {
        let _ = AnimationTokens.pickerDrop(reduced: true)
        let _ = AnimationTokens.pickerDrop(reduced: false)
    }

    func testAIOverlaySlide_apiExists() {
        let _ = AnimationTokens.aiOverlaySlide(reduced: true)
        let _ = AnimationTokens.aiOverlaySlide(reduced: false)
    }
}
