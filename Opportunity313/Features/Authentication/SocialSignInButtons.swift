import AuthenticationServices
import SwiftUI

struct SocialSignInButtons: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.scenePhase) private var scenePhase
    var accountType: SignupAccountType? = nil
    var confirmsAdultAge = false
    @State private var appleNonce: String?

    private var ageAllowed: Bool { accountType != .youth || confirmsAdultAge }

    var body: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.continue) { request in
                appleNonce = authService.prepareAppleSignIn(accountType: accountType, confirmsAdultAge: confirmsAdultAge)
                request.requestedScopes = [.fullName, .email]
                request.nonce = appleNonce.map(SocialSignIn.hash)
            } onCompletion: { result in
                let nonce = appleNonce
                appleNonce = nil
                Task { await authService.completeAppleSignIn(result, nonce: nonce) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(maxWidth: 228)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(authService.isLoading || !ageAllowed || authService.socialProviders?.apple != true)
            .opacity(authService.isLoading || !ageAllowed || authService.socialProviders?.apple != true ? 0.5 : 1)
            .accessibilityIdentifier("continueWithApple")

            Button {
                Task { await authService.signInWithGoogle(accountType: accountType, confirmsAdultAge: confirmsAdultAge) }
            } label: {
                // Google's unmodified, pre-approved iOS button artwork.
                Image("GoogleSignIn").resizable().scaledToFit()
                    .frame(width: 228, height: 54)
            }
            .buttonStyle(.plain)
            .disabled(authService.isLoading || !ageAllowed || authService.socialProviders?.google != true)
            .accessibilityLabel("Sign in with Google")
            .accessibilityIdentifier("continueWithGoogle")

            if let status = authService.socialProviderMessage {
                Text(status).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("socialProviderStatus")
                if authService.socialProviders == nil && !authService.isCheckingSocialProviders {
                    Button("Retry sign-in options") { Task { await authService.refreshSocialProviders() } }
                        .font(.subheadline).frame(minHeight: 44)
                }
            }
            if authService.isLoading { ProgressView("Signing in…") }
            HStack { Rectangle().frame(height: 1); Text("or use email").fixedSize(); Rectangle().frame(height: 1) }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .task { await authService.refreshSocialProviders() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await authService.refreshSocialProviders() } }
        }
    }
}
