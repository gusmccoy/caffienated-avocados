// Services/StravaService.swift
// Handles Strava OAuth 2.0 authentication and REST API calls.
//
// SETUP REQUIRED:
//   1. Register your app at https://www.strava.com/settings/api
//   2. Add your Client ID and Client Secret to Secrets.plist (not committed to git)
//   3. Register the URL scheme "mccoy-fitness" in your app's Info.plist
//      under CFBundleURLSchemes so that Strava can redirect back after auth.
//
// The access token is stored in Keychain (never in SwiftData or UserDefaults).

import Foundation
import AuthenticationServices
import Security
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Strava API Constants

private enum StravaAPI {
    static let baseURL          = "https://www.strava.com/api/v3"
    static let authURL          = "https://www.strava.com/oauth/mobile/authorize"
    static let tokenURL         = "https://www.strava.com/oauth/token"
    static let redirectURI      = "mccoy-fitness://strava-auth"
    static let scope            = "activity:read_all,profile:read_all"

    // Read these from Secrets.plist at runtime (see SecretsLoader below)
    static var clientId: String     { SecretsLoader.value(for: "StravaClientId") }
    static var clientSecret: String { SecretsLoader.value(for: "StravaClientSecret") }
}

// MARK: - StravaService

final class StravaService {

    // Prevent ARC from deallocating the auth session and its (weak) context provider mid-flow.
    private var authSession: ASWebAuthenticationSession?
    private var authAnchorProvider: AnchorProvider?

    // MARK: - Authentication

    /// Launches Strava's OAuth web flow and exchanges the code for tokens.
    func authenticate(anchor: ASPresentationAnchor) async throws -> StravaAthlete {
        let code = try await requestAuthorizationCode(anchor: anchor)
        let tokenResponse = try await exchangeCodeForToken(code: code)

        // Persist tokens in Keychain
        if let token = tokenResponse.accessToken as String? {
            try saveToKeychain(key: "strava_access_token", value: token)
        }
        try saveToKeychain(key: "strava_refresh_token", value: tokenResponse.refreshToken)
        saveExpiresAt(tokenResponse.expiresAt)

        guard let athlete = tokenResponse.athlete else {
            // If athlete wasn't returned in token exchange, fetch it directly
            return try await fetchAthlete()
        }
        return athlete
    }

    /// Clears all stored Strava credentials.
    func clearTokens() {
        deleteFromKeychain(key: "strava_access_token")
        deleteFromKeychain(key: "strava_refresh_token")
        UserDefaults.standard.removeObject(forKey: "strava_expires_at")
    }

    // MARK: - Athlete

    func fetchAthlete() async throws -> StravaAthlete {
        let token = try validAccessToken()
        let url = URL(string: "\(StravaAPI.baseURL)/athlete")!
        return try await get(url: url, token: token)
    }

    // MARK: - Activities

    /// Fetches the most recent 50 activities from Strava.
    func fetchRecentActivities(page: Int = 1, perPage: Int = 50) async throws -> [StravaActivity] {
        let token = try validAccessToken()
        var components = URLComponents(string: "\(StravaAPI.baseURL)/athlete/activities")!
        components.queryItems = [
            URLQueryItem(name: "page",     value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
        ]
        return try await get(url: components.url!, token: token)
    }

    // MARK: - Token Management

    private func validAccessToken() throws -> String {
        // Check expiry
        let expiresAt = UserDefaults.standard.double(forKey: "strava_expires_at")
        if Date().timeIntervalSince1970 < expiresAt - 60 {
            // Token still valid
            if let token = readFromKeychain(key: "strava_access_token") {
                return token
            }
        }
        // Need to refresh — run on current task
        return try runSync { try await self.refreshAccessToken() }
    }

    private func refreshAccessToken() async throws -> String {
        guard let refreshToken = readFromKeychain(key: "strava_refresh_token") else {
            throw StravaError.notAuthenticated
        }

        var request = URLRequest(url: URL(string: StravaAPI.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_id":     StravaAPI.clientId,
            "client_secret": StravaAPI.clientSecret,
            "grant_type":    "refresh_token",
            "refresh_token": refreshToken,
        ])

        let (data, _) = try await URLSession.shared.data(for: request)
        let response  = try decoded(StravaTokenResponse.self, from: data)

        try saveToKeychain(key: "strava_access_token", value: response.accessToken)
        try saveToKeychain(key: "strava_refresh_token", value: response.refreshToken)
        saveExpiresAt(response.expiresAt)

        return response.accessToken
    }

    // MARK: - OAuth Code Flow

    @MainActor
    private func requestAuthorizationCode(anchor: ASPresentationAnchor) async throws -> String {
        var components = URLComponents(string: StravaAPI.authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id",     value: StravaAPI.clientId),
            URLQueryItem(name: "redirect_uri",  value: StravaAPI.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope",         value: StravaAPI.scope),
        ]

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: "mccoy-fitness"
            ) { [weak self] callbackURL, error in
                self?.authSession = nil
                self?.authAnchorProvider = nil

                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard
                    let url = callbackURL,
                    let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: StravaError.invalidCallback)
                    return
                }
                continuation.resume(returning: code)
            }

            // Retain both session and provider — presentationContextProvider is weak,
            // so without strong references here they'd be deallocated before the flow starts.
            self.authAnchorProvider = AnchorProvider(anchor: anchor)
            session.presentationContextProvider = self.authAnchorProvider
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            session.start()
        }
    }

    private func exchangeCodeForToken(code: String) async throws -> StravaTokenResponse {
        var request = URLRequest(url: URL(string: StravaAPI.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_id":     StravaAPI.clientId,
            "client_secret": StravaAPI.clientSecret,
            "code":          code,
            "grant_type":    "authorization_code",
        ])
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoded(StravaTokenResponse.self, from: data)
    }

    // MARK: - Generic GET

    private func get<T: Decodable>(url: URL, token: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw StravaError.httpError(http.statusCode)
        }
        return try decoded(T.self, from: data)
    }

    // MARK: - JSON

    private func decoded<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    // MARK: - Keychain Helpers

    @discardableResult
    private func saveToKeychain(key: String, value: String) throws -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      key,
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw StravaError.keychainError(status) }
        return true
    }

    private func readFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func saveExpiresAt(_ expiresAt: Int) {
        UserDefaults.standard.set(Double(expiresAt), forKey: "strava_expires_at")
    }

    /// Bridges an async function to synchronous context (only safe to call from a non-async context).
    private func runSync<T>(_ block: @escaping () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<T, Error>?
        Task {
            do    { result = .success(try await block()) }
            catch { result = .failure(error) }
            semaphore.signal()
        }
        semaphore.wait()
        return try result!.get()
    }
}

// MARK: - Errors

enum StravaError: LocalizedError {
    case notAuthenticated
    case invalidCallback
    case httpError(Int)
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:    return "Not connected to Strava. Please reconnect."
        case .invalidCallback:     return "Invalid Strava callback URL."
        case .httpError(let code): return "Strava API error: HTTP \(code)"
        case .keychainError(let s): return "Keychain error: \(s)"
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

class AnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor }
}

// MARK: - ASPresentationAnchor Convenience

extension ASPresentationAnchor {
    /// Returns the app's current key window, suitable as a presentation anchor.
    static var current: ASPresentationAnchor? {
#if os(macOS)
        NSApplication.shared.keyWindow
#else
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: { $0.isKeyWindow })
#endif
    }
}

// MARK: - Secrets Loader

/// Reads non-sensitive app configuration from Secrets.plist.
/// Add Secrets.plist to .gitignore to avoid committing credentials.
private enum SecretsLoader {
    static func value(for key: String) -> String {
        guard
            let url    = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let dict   = NSDictionary(contentsOf: url),
            let value  = dict[key] as? String
        else {
            assertionFailure("Missing \(key) in Secrets.plist")
            return ""
        }
        return value
    }
}
