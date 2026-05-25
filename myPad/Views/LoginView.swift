import SwiftUI
import MyPadKit

/// Login screen — username/password form that calls APIClient.login().
/// On success, fires the onLoginSuccess closure so the app root can swap to ContentView.
struct LoginView: View {
    let onLoginSuccess: () -> Void

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.studioSurface
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Branding
                VStack(spacing: 8) {
                    Image(systemName: "house.lodge")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(Color.studioAccent)
                    Text("myPad")
                        .font(.studioHeading(size: 44))
                        .foregroundStyle(Color.studioText)
                    Text("Interior Design Platform")
                        .font(.studioCaption(size: 14))
                        .foregroundStyle(Color.studioSecondary)
                }

                // Login form card
                VStack(spacing: 16) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.plain)
                        .font(.studioCaption(size: 15))
                        .foregroundStyle(Color.studioText)
                        .padding(12)
                        .background(Color.studioSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.studioDivider.opacity(0.8), lineWidth: 0.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .disabled(isLoading)
                        .onSubmit { Task { await login() } }

                    SecureField("Password", text: $password)
                        .textFieldStyle(.plain)
                        .font(.studioCaption(size: 15))
                        .foregroundStyle(Color.studioText)
                        .padding(12)
                        .background(Color.studioSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.studioDivider.opacity(0.8), lineWidth: 0.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .textContentType(.password)
                        .disabled(isLoading)
                        .onSubmit { Task { await login() } }

                    if let error = errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(Color.studioRejected)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    }

                    Button {
                        Task { await login() }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(isLoading ? "Signing In…" : "Log In")
                                .font(.studioCaption(size: 14))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.isEmpty || password.isEmpty || isLoading)
                    .animation(.default, value: isLoading)
                }
                .padding(32)
                .background(Color.studioCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.studioDivider.opacity(0.65), lineWidth: 0.5)
                }
                .shadow(color: Color.studioBrown.opacity(0.055), radius: 12, y: 4)
                .padding(.horizontal, 48)

                Spacer()
            }
            .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func login() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            _ = try await APIClient.shared.login(username: username, password: password)
            onLoginSuccess()
        } catch {
            withAnimation {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}
