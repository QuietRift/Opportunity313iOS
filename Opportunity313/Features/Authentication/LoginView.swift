import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showChildAccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                Opportunity313Brand.heroGradient.ignoresSafeArea()

                Circle()
                    .stroke(Opportunity313Brand.accent.opacity(0.20), lineWidth: 1)
                    .frame(width: 420, height: 420)
                    .offset(x: 180, y: -290)
                    .accessibilityHidden(true)

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        Spacer(minLength: 44)
                        brandHeader
                        signInCard
                        childAccessButton
                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                }
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView().environmentObject(authService)
            }
            .sheet(isPresented: $showChildAccess) {
                ChildAccessLoginView().environmentObject(authService)
            }
        }
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(.white.opacity(0.9), lineWidth: 2)
                    .frame(width: 38, height: 38)
                    .overlay(Image(systemName: "circle.fill").font(.caption2).foregroundStyle(.white))
                (Text("Opportunity").foregroundStyle(.white) + Text("313").foregroundStyle(Opportunity313Brand.accent))
                    .font(.headline.bold())
            }
            Text("The right opportunity should find the right young person.")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("Trusted Detroit programs, matched by age, interests, grade, and eligibility.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.76))
        }
        .accessibilityElement(children: .combine)
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome back").font(.title2.bold())
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .brandField()
            SecureField("Password", text: $password)
                .textContentType(.password)
                .brandField()

            if let error = authService.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Button {
                Task { await authService.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password) }
            } label: {
                HStack {
                    if authService.isLoading { ProgressView().tint(.white) }
                    else { Text("Sign in"); Spacer(); Image(systemName: "arrow.right") }
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Opportunity313Brand.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(authService.isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

            Button("Create an account") { showSignUp = true }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .padding(22)
        .background(Opportunity313Brand.warmSurface)
        .foregroundStyle(Opportunity313Brand.deepBlue)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.18), radius: 22, y: 12)
    }

    private var childAccessButton: some View {
        Button { showChildAccess = true } label: {
            Label("Under 18? Use a parent access code", systemImage: "person.badge.key.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(.white)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.30)))
        }
    }
}

private extension View {
    func brandField() -> some View {
        padding()
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Opportunity313Brand.deepBlue.opacity(0.12)))
    }
}

#Preview {
    LoginView().environmentObject(AuthService())
}
