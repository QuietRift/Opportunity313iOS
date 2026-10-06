import Foundation

// Organization accounts retain the existing `provider` server role and memberships.
// This editable payload deliberately excludes identity and verification fields.
struct OrganizationProfileDraft: Encodable {
    var name = ""
    var organizationType = "nonprofit"
    var description = ""
    var website = ""
    var contactName = ""
    var contactEmail = ""
    var contactPhone = ""
    var serviceArea = ""
    var address = ""
    var city = ""

    static let types = ["nonprofit", "community_provider", "school", "youth_league", "little_league", "athletics_host", "city_program"]
    static func typeLabel(_ type: String) -> String {
        type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    init(organization: Organization? = nil) {
        guard let organization else { return }
        name = organization.name
        organizationType = organization.organizationType
        description = organization.description ?? ""
        website = organization.website ?? ""
        contactName = organization.contactName ?? ""
        contactEmail = organization.contactEmail ?? ""
        contactPhone = organization.contactPhone ?? ""
        serviceArea = organization.serviceArea ?? ""
        address = organization.address ?? ""
        city = organization.city ?? ""
    }

    var cleaned: Self {
        var value = self
        for key in [\Self.name, \.organizationType, \.description, \.website, \.contactName,
                    \.contactEmail, \.contactPhone, \.serviceArea, \.address, \.city] {
            value[keyPath: key] = value[keyPath: key].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    var validationMessage: String? {
        let value = cleaned
        if value.name.count < 3 || value.name.count > 200 { return "Enter an organization name between 3 and 200 characters." }
        if !Self.types.contains(value.organizationType) { return "Choose an organization type." }
        if !value.website.isEmpty {
            guard let url = URLComponents(string: value.website), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
                  !value.website.contains(where: { $0.isWhitespace }) else {
                return "Enter a website starting with https:// or http://."
            }
        }
        if !value.contactEmail.isEmpty && value.contactEmail.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) == nil {
            return "Enter a valid contact email address."
        }
        if [value.description, value.website, value.contactName, value.contactEmail, value.contactPhone,
            value.serviceArea, value.address, value.city].contains(where: { $0.count > 2000 }) {
            return "Keep each field to 2,000 characters or fewer."
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case name, description, website, address, city
        case organizationType = "organization_type", contactName = "contact_name"
        case contactEmail = "contact_email", contactPhone = "contact_phone", serviceArea = "service_area"
    }
}

enum OrganizationProfileError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): message } }
}

extension Opportunity {
    var organizationApprovalStatus: String {
        if verificationStatus == "rejected" { return "Rejected" }
        if status == "pending_review" { return "Pending" }
        if status == "published" { return "Approved" }
        return adminStatus
    }
}
