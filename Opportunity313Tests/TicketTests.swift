import Foundation
import Testing
@testable import Opportunity313

struct TicketTests {
    @Test func entryCodesAcceptOnlyRawTokensOrTicketPayloads() {
        let valid = String(repeating: "a1", count: 32)
        #expect(TicketCode.token(from: valid) == valid)
        #expect(TicketCode.token(from: "  \(TicketCode.prefix)\(valid)\n") == valid)
        #expect(TicketCode.token(from: "https://example.com/\(valid)") == nil)
        #expect(TicketCode.token(from: String(repeating: "g", count: 64)) == nil)
        #expect(TicketCode.token(from: String(valid.dropLast())) == nil)
        #expect(TicketCode.token(from: valid + "0") == nil)
    }

    @Test func quantityHonorsInventoryAccountLimitAndClientMaximum() {
        let id = UUID()
        #expect(TicketAllocation(id: id, name: "Admission", limitPerUser: 4, capacity: 50, eligibilityKind: "general", remaining: 50, myRemaining: 2).maximumQuantity == 2)
        #expect(TicketAllocation(id: id, name: "Admission", limitPerUser: 4, capacity: 50, eligibilityKind: "general", remaining: 0, myRemaining: 4).maximumQuantity == 0)
        #expect(TicketAllocation(id: id, name: "Admission", limitPerUser: 50, capacity: 100, eligibilityKind: "general", remaining: 100, myRemaining: 50).maximumQuantity == 20)
    }

    @Test func studentAllocationIsDistinctFromGuestAllocation() {
        let student = TicketAllocation(id: UUID(), name: "Students", limitPerUser: 2, capacity: 20,
                                       eligibilityKind: "student", remaining: 10, myRemaining: 2)
        let guest = TicketAllocation(id: UUID(), name: "Families", limitPerUser: 2, capacity: 20,
                                     eligibilityKind: "general", remaining: 10, myRemaining: 2)
        #expect(student.requiresSchoolVerification)
        #expect(!guest.requiresSchoolVerification)
    }

    @Test func reservationsRespectExactOpeningClosingAndEventStatus() {
        let open = Date(timeIntervalSince1970: 1_000)
        let close = Date(timeIntervalSince1970: 2_000)
        func event(_ status: String) -> TicketEvent {
            TicketEvent(id: UUID(), title: "Event", sport: nil, startsAt: Date(timeIntervalSince1970: 3_000), timezone: "America/Detroit", salesOpenAt: open, salesCloseAt: close, eventStatus: status, isDemo: true, venueName: "Venue", schoolName: nil, schoolID: nil, venueID: UUID(), venuePhysicalCapacity: 100, operationalCapacity: 80, canManageCapacity: false, address: "Detroit", canManage: false, allocations: [])
        }
        #expect(!event("on_sale").reservationsOpen(at: open.addingTimeInterval(-1)))
        #expect(event("on_sale").reservationsOpen(at: open))
        #expect(!event("on_sale").reservationsOpen(at: close))
        #expect(!event("cancelled").reservationsOpen(at: open))
        #expect(!event("paused").reservationsOpen(at: open))
        #expect(!event("sold_out").reservationsOpen(at: open))
    }

    @Test func checkoutHoldExpiresAtServerDeadline() {
        let allocation = UUID()
        let active = TicketHold(id: UUID(), allocationID: allocation, quantity: 2, assignedYouthProfileID: nil,
                                expiresAt: Date().addingTimeInterval(300), status: "active")
        let expired = TicketHold(id: UUID(), allocationID: allocation, quantity: 2, assignedYouthProfileID: nil,
                                 expiresAt: Date().addingTimeInterval(-1), status: "active")
        #expect(active.isActive)
        #expect(!expired.isActive)
    }

    @Test func scannedVoidedAndCancelledTicketsNeverDisplayEntryCodes() {
        let start = Date(timeIntervalSince1970: 5_000)
        func ticket(_ status: String, eventStatus: String = "on_sale") -> EventTicket {
            EventTicket(id: UUID(), eventID: UUID(), eventTitle: "Event", allocationName: "Admission", assignedYouthName: nil, startsAt: start, timezone: "America/Detroit", venueName: "Venue", address: "Detroit", status: status, eventStatus: eventStatus, isDemo: true, issuedAt: Date(timeIntervalSince1970: 1_000))
        }
        #expect(ticket("issued").canShowCode)
        #expect(!ticket("scanned").canShowCode)
        #expect(!ticket("void").canShowCode)
        #expect(!ticket("issued", eventStatus: "cancelled").canShowCode)
        #expect(ticket("scanned").statusText == "Checked In")
        #expect(ticket("issued").canCancel(at: start.addingTimeInterval(-1)))
        #expect(!ticket("issued").canCancel(at: start))
        #expect(!ticket("scanned").canCancel(at: start.addingTimeInterval(-1)))
    }

    @Test func keychainCodesAreScopedToOwnerAndTicket() {
        let user = UUID(), otherUser = UUID(), ticket = UUID(), otherTicket = UUID()
        let code = String(repeating: "a1", count: 32)
        defer { TicketTokenStore.remove(userID: user, ticketID: ticket) }
        #expect(TicketTokenStore.save(code, userID: user, ticketID: ticket))
        #expect(TicketTokenStore.read(userID: user, ticketID: ticket) == code)
        #expect(TicketTokenStore.read(userID: otherUser, ticketID: ticket) == nil)
        #expect(TicketTokenStore.read(userID: user, ticketID: otherTicket) == nil)
    }
}
