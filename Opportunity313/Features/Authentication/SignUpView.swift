//
//  SignUpView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct SignUpView: View {

    @Environment(\.dismiss)
    private var dismiss

    @EnvironmentObject var authService:
        AuthService

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var didSendConfirmation =
        false

    @State private var resendMessage:
        String?


    var body: some View {

        NavigationStack {

            Group {

                if didSendConfirmation {

                    confirmationView

                } else {

                    signUpForm
                }
            }
            .navigationBarTitleDisplayMode(
                .inline
            )
        }
        .onAppear {

            authService.clearError()
        }
    }


    // MARK: - Sign Up Form

    private var signUpForm:
        some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 24
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Text(
                        "Create Your Account"
                    )
                    .font(.largeTitle)
                    .fontWeight(.bold)

                    Text(
                        "Discover opportunities across Detroit."
                    )
                    .font(.title3)
                    .foregroundStyle(
                        .secondary
                    )
                }


                VStack(spacing: 16) {

                    TextField(
                        "Email",
                        text: $email
                    )
                    .textInputAutocapitalization(
                        .never
                    )
                    .keyboardType(
                        .emailAddress
                    )
                    .textContentType(
                        .emailAddress
                    )
                    .padding()
                    .background(
                        Color(
                            .secondarySystemBackground
                        )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14
                        )
                    )


                    SecureField(
                        "Password",
                        text: $password
                    )
                    .textContentType(
                        .newPassword
                    )
                    .padding()
                    .background(
                        Color(
                            .secondarySystemBackground
                        )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14
                        )
                    )


                    SecureField(
                        "Confirm Password",
                        text:
                            $confirmPassword
                    )
                    .textContentType(
                        .newPassword
                    )
                    .padding()
                    .background(
                        Color(
                            .secondarySystemBackground
                        )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14
                        )
                    )
                }


                if passwordsDoNotMatch {

                    Text(
                        "Passwords do not match."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.red)
                }


                if let error =
                    authService.errorMessage {

                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }


                Button {

                    Task {
                        await createAccount()
                    }

                } label: {

                    if authService.isLoading {

                        ProgressView()
                            .tint(.white)
                            .frame(
                                maxWidth:
                                    .infinity
                            )

                    } else {

                        Text(
                            "Create Account"
                        )
                        .fontWeight(
                            .semibold
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                    }
                }
                .buttonStyle(
                    .borderedProminent
                )
                .controlSize(.large)
                .disabled(
                    !formIsValid ||
                    authService.isLoading
                )


                Button(
                    "Already have an account? Sign In"
                ) {

                    dismiss()
                }
                .frame(
                    maxWidth: .infinity
                )
            }
            .padding()
        }
        .navigationTitle(
            "Sign Up"
        )
    }


    // MARK: - Confirmation View

    private var confirmationView:
        some View {

        VStack(spacing: 28) {

            Spacer()


            Image(
                systemName:
                    "envelope.badge.fill"
            )
            .font(
                .system(size: 72)
            )


            VStack(spacing: 10) {

                Text(
                    "Check Your Email"
                )
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(
                    .center
                )


                Text(
                    "We sent a confirmation link to"
                )
                .foregroundStyle(
                    .secondary
                )


                Text(cleanEmail)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(
                        .center
                    )


                Text(
                    "Confirm your email, then return to Opportunity313 and sign in."
                )
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )
                .padding(
                    .top,
                    4
                )
            }


            if let resendMessage {

                Text(resendMessage)
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                    .multilineTextAlignment(
                        .center
                    )
            }


            if let error =
                authService.errorMessage {

                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(
                        .red
                    )
                    .multilineTextAlignment(
                        .center
                    )
            }


            VStack(spacing: 12) {

                Button {

                    Task {

                        await resendConfirmation()
                    }

                } label: {

                    if authService.isLoading {

                        ProgressView()
                            .frame(
                                maxWidth:
                                    .infinity
                            )

                    } else {

                        Label(
                            "Resend Email",
                            systemImage:
                                "arrow.clockwise"
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                    }
                }
                .disabled(authService.isLoading)
                .buttonStyle(
                    .bordered
                )
                .controlSize(.large)


                Button {

                    authService.clearError()
                    dismiss()

                } label: {

                    Text(
                        "Back to Sign In"
                    )
                    .fontWeight(
                        .semibold
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .controlSize(.large)
            }


            Spacer()
        }
        .padding()
        .navigationTitle(
            "Email Verification"
        )
    }


    // MARK: - Create Account

    private func createAccount() async {

        authService.clearError()

        await authService.signUp(
            email: cleanEmail,
            password: password
        )


        if authService.errorMessage ==
            nil {

            password = ""
            confirmPassword = ""

            withAnimation {

                didSendConfirmation =
                    true
            }
        }
    }


    // MARK: - Resend

    private func resendConfirmation()
        async {

        authService.clearError()

        let success =
            await authService
                .resendSignupConfirmation(
                    email: cleanEmail
                )

        if success {

            resendMessage =
                "A new confirmation email was sent."
        }
    }


    // MARK: - Validation

    private var cleanEmail:
        String {

        email
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
    }


    private var passwordsDoNotMatch:
        Bool {

        !confirmPassword.isEmpty &&
        password != confirmPassword
    }


    private var formIsValid:
        Bool {

        cleanEmail.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword
    }
}
