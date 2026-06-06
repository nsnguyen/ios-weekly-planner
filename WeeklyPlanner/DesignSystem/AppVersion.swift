import Foundation

/// Marketing + build version for user-facing display ("v1.0.0 (1)").
enum AppVersion {
    static func display(marketing: String?, build: String?) -> String {
        "v\(marketing ?? "1.0") (\(build ?? "1"))"
    }

    static func current(bundle: Bundle = .main) -> String {
        display(marketing: bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
                build: bundle.infoDictionary?["CFBundleVersion"] as? String)
    }
}
