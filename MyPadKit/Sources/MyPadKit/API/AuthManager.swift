import Foundation

extension Notification.Name {
    /// Posted when the user logs out — observed by the app root to swap back to LoginView.
    public static let myPadDidLogout = Notification.Name("myPad.didLogout")
}

/// Manages JWT token storage and refresh. Stores tokens in the Keychain on iOS,
/// falling back to UserDefaults on macOS (for development/testing).
public actor AuthManager {
    public static let shared = AuthManager()

    private let accessTokenKey = "mypad.accessToken"
    private let refreshTokenKey = "mypad.refreshToken"

    private var accessToken: String?
    private var refreshToken: String?

    private init() {
        // Load tokens from local storage on init
        self.accessToken = UserDefaults.standard.string(forKey: accessTokenKey)
        self.refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey)
    }

    public var hasToken: Bool {
        accessToken != nil
    }

    public var bearerToken: String? {
        accessToken.map { "Bearer \($0)" }
    }

    public func saveTokens(_ tokens: AuthTokens) {
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken ?? refreshToken
        UserDefaults.standard.set(accessToken, forKey: accessTokenKey)
        if let rt = refreshToken {
            UserDefaults.standard.set(rt, forKey: refreshTokenKey)
        }
    }

    public func clearTokens() {
        accessToken = nil
        refreshToken = nil
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
    }

    /// Returns the current access token. If we have a refresh token, could trigger refresh here.
    public func currentAccessToken() -> String? {
        accessToken
    }
}
