import SwiftUI

struct ProviderSetupView: View {
    @ObservedObject var providerService: ProviderService
    var body: some View {
        OrganizationProfileEditor(service: providerService, organization: nil)
    }
}
