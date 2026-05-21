import XCTest
@testable import WeeklyPlanner

final class MessageClassifierTests: XCTestCase {
    func testResyConfirmationSenderPasses() {
        let v = MessageClassifier.classify(
            subject: "Your reservation at Café Bleu is confirmed",
            fromName: "Resy",
            fromEmail: "reservations@resy.com"
        )
        XCTAssertTrue(v.passes)
        XCTAssertTrue(v.ruleHits.contains("sender:resy.com"))
    }

    func testTicketmasterSubjectKeywordPasses() {
        let v = MessageClassifier.classify(
            subject: "Your tickets for the show",
            fromName: "Ticketmaster",
            fromEmail: "no-reply@ticketmaster.com"
        )
        XCTAssertTrue(v.passes)
        XCTAssertTrue(v.ruleHits.contains("subject:ticket"))
    }

    func testPromotionalNewsletterFails() {
        let v = MessageClassifier.classify(
            subject: "50% off this weekend!",
            fromName: "Some Store Newsletter",
            fromEmail: "newsletter@store.com"
        )
        XCTAssertFalse(v.passes)
    }

    func testGenericTransactionalEmailPassesWhenSubjectHasKeyword() {
        let v = MessageClassifier.classify(
            subject: "Appointment confirmation — Dr. Smith",
            fromName: "Dental Office",
            fromEmail: "appointments@dentaloffice.example"
        )
        XCTAssertTrue(v.passes)
        XCTAssertTrue(v.ruleHits.contains("subject:appointment"))
        XCTAssertTrue(v.ruleHits.contains("subject:confirmation"))
    }
}
