import XCTest
#if canImport(UIKit)
    import UIKit
#endif

@testable import WeeklyPlanner

final class SmokeTests: XCTestCase {
    /// Every PostScript name we declare in Info.plist's `UIAppFonts` must resolve
    /// to a real, loaded font at runtime. If this fails, either the .ttf file is
    /// missing from `Copy Bundle Resources` or the PostScript name in
    /// `expectedPostScriptNames` does not match what is inside the .ttf.
    func testFontsRegistered() {
        for psName in Self.expectedPostScriptNames {
            let font = UIFont(name: psName, size: 12)
            XCTAssertNotNil(font,
                            "Font with PostScript name '\(psName)' is not registered. " +
                                "Loaded font names containing handwriting fonts: \(Self.candidateLoadedNames())")
        }
    }

    func testBundleIdentifier() {
        let bundleID = Bundle.main.bundleIdentifier
        XCTAssertEqual(bundleID, "com.weeklyplanner.WeeklyPlanner")
    }

    /// Deployment target should be iOS 26.0 or higher.
    /// `MinimumOSVersion` is set by Xcode based on the IPHONEOS_DEPLOYMENT_TARGET build setting.
    func testDeploymentTarget() {
        let key = "MinimumOSVersion"
        guard let minVersion = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            XCTFail("\(key) missing from Info.plist")
            return
        }
        let parts = minVersion.split(separator: ".").compactMap { Int($0) }
        let major = parts.first ?? 0
        XCTAssertGreaterThanOrEqual(major, 26, "Deployment target must be iOS 26+, got \(minVersion)")
    }

    // MARK: - Helpers

    /// Canonical PostScript names for every font we ship. These must match the
    /// `name` table inside the .ttf files. Verified with `otfinfo --info`.
    static let expectedPostScriptNames: [String] = [
        "Caveat-Regular",
        "Caveat-Medium",
        "Caveat-SemiBold",
        "Caveat-Bold",
        "ArchitectsDaughter-Regular",
        "Kalam-Light",
        "Kalam-Regular",
        "Kalam-Bold",
        "IndieFlower-Regular",
    ]

    /// Returns every loaded PostScript name whose family resembles one of our
    /// handwriting fonts. Used as a diagnostic when `testFontsRegistered` fails.
    static func candidateLoadedNames() -> [String] {
        let needles = ["caveat", "architects", "kalam", "indie"]
        var matches: [String] = []
        for family in UIFont.familyNames {
            let lower = family.lowercased()
            guard needles.contains(where: { lower.contains($0) }) else { continue }
            matches.append(contentsOf: UIFont.fontNames(forFamilyName: family))
        }
        return matches.sorted()
    }
}
