//
//  LoginView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct LoginView: View {

    @EnvironmentObject var authService: AuthService

    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showChildAccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                Spacer()

                VStack(spacing: 8) {
                    Text("Opportunity313")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Discover opportunities across Detroit.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    SecureField("Password", text: $password)
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if let error = authService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        await authService.signIn(
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password
                        )
                    }
                } label: {
                    HStack {
                        if authService.isLoading {
                            ProgressView()
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primary)
                    .foregroundStyle(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                .disabled(authService.isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

                Button("Create an Account") {
                    showSignUp = true
                }

                Button {
                    showChildAccess = true
                } label: {
                    Label("I'm under 18 — use a parent code", systemImage: "person.badge.key.fill")
                }

                Spacer()
            }
            .padding()
            .sheet(isPresented: $showSignUp) {
                SignUpView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showChildAccess) {
                ChildAccessLoginView().environmentObject(authService)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}
