// Services/ClaudeService.swift
// Google Gemini API integration — experimental feature.
// Uses Gemini 2.0 Flash (free tier) with Google Search grounding.
// Users provide their own API key; it is stored securely in the Keychain.

import Foundation
import Security

// MARK: - Keychain helpers

enum AIKeychain {
    private static let keychainKey = "gemini_api_key"

    static func save(_ apiKey: String) {
        let data = Data(apiKey.utf8)
        let query: [String: Any] = [
            kSecClass as String:          kSecClassGenericPassword,
            kSecAttrAccount as String:    keychainKey,
            kSecValueData as String:      data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static var isConfigured: Bool { load() != nil }
}

// MARK: - AI Assistant Service

enum AIAssistantError: LocalizedError {
    case missingAPIKey
    case networkError(Error)
    case httpError(Int, String)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key configured. Add one in Settings → Experimental."
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .httpError(let code, let msg):
            return "API error \(code): \(msg)"
        case .decodingError:
            return "Could not parse the response."
        }
    }
}

struct AIAssistantService {

    // MARK: - Web search for running gear & races
    //
    // Sends a message to Gemini 2.0 Flash with Google Search grounding.
    // The model searches the web automatically and returns a synthesized answer.

    static func searchRunningGearAndRaces(query: String) async throws -> String {
        guard let apiKey = AIKeychain.load(), !apiKey.isEmpty else {
            throw AIAssistantError.missingAPIKey
        }

        let systemPrompt = """
            You are a helpful running assistant. You ONLY help with:
            - Finding running apparel and gear (shoes, clothing, accessories, watches, etc.)
            - Finding running races and events (marathons, half marathons, 5Ks, trail races, etc.)

            Do not answer questions outside these two topics. If asked about something unrelated,
            politely explain you can only assist with running gear and races.
            Always use Google Search to find current, accurate information.
            """

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                ["role": "user", "parts": [["text": query]]]
            ],
            "tools": [
                ["google_search": [:]]
            ],
            "generation_config": [
                "max_output_tokens": 1024
            ]
        ]

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw AIAssistantError.decodingError }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIAssistantError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIAssistantError.httpError(httpResponse.statusCode, body)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            throw AIAssistantError.decodingError
        }

        let text = parts
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")

        return text.isEmpty ? "No results found." : text
    }
}
