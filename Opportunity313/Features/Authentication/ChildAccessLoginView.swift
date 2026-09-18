import SwiftUI

struct ChildAccessLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @State private var accessCode = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Child Access").font(.largeTitle.bold())
                    Text("Enter the private code your parent or guardian created for your profile.")
                        .foregroundStyle(.secondary)
                }

                TextField("O313-XXXX-XXXX-XXXX", text: $accessCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityIdentifier("childAccessCode")

                if let error = authService.errorMessage {
                    Text(error).font(.subheadline).foregroundStyle(.red)
                }

                Button {
                    Task { await authService.signInWithChildAccessCode(accessCode) }
                } label: {
                    Group {
                        if authService.isLoading { ProgressView() }
                        else { Text("Open My Profile").fontWeight(.semibold) }
                    }
                    .frame(maxWidth: .infinity).padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(authService.isLoading || accessCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Text("Your parent can replace or revoke this code at any time.")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Access Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { authService.clearError() }
        }
    }
}
