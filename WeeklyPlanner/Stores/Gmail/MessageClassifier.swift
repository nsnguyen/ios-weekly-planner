import Foundation

/// Cheap pre-filter that decides whether a Gmail message is worth handing
/// to `EventExtractor` (which is expensive). Subject keywords + sender
/// domain rules. The downstream extractor makes the final isEvent call.
enum MessageClassifier {
    struct Verdict: Equatable {
        let passes: Bool
        let ruleHits: [String]
    }

    private static let eventDomains: Set<String> = [
        "resy.com",
        "opentable.com",
        "ticketmaster.com",
        "eventbrite.com",
        "airbnb.com",
        "doordash.com",
    ]

    private static let noiseDomains: Set<String> = [
        "unsubscribe.com",
        "marketing.com",
    ]

    private static let subjectKeywords: [String] = [
        "appointment",
        "confirmation",
        "confirmed",
        "ticket",
        "reservation",
        "invite",
        "rsvp",
        "booking",
    ]

    private static let promoKeywords: [String] = [
        "% off",
        "sale",
        "newsletter",
        "unsubscribe",
        "promo",
    ]

    static func classify(subject: String, fromName: String, fromEmail: String) -> Verdict {
        var hits: [String] = []
        let lowerSubject = subject.lowercased()
        let lowerName = fromName.lowercased()
        let lowerEmail = fromEmail.lowercased()
        let domain = lowerEmail.split(separator: "@").last.map(String.init) ?? ""

        // Hard-fail on noise senders / promo keywords first.
        if noiseDomains.contains(domain) {
            return Verdict(passes: false, ruleHits: ["sender:noise"])
        }
        if promoKeywords.contains(where: { lowerSubject.contains($0) }) {
            return Verdict(passes: false, ruleHits: ["subject:promo"])
        }
        if lowerName.contains("newsletter") {
            return Verdict(passes: false, ruleHits: ["sender:newsletter"])
        }

        // Sender domains.
        if eventDomains.contains(domain) {
            hits.append("sender:\(domain)")
        }

        // Subject keywords.
        for keyword in subjectKeywords where lowerSubject.contains(keyword) {
            hits.append("subject:\(keyword)")
        }

        return Verdict(passes: !hits.isEmpty, ruleHits: hits)
    }
}
